-- Corrections suite à la revue de conformité du module "Lettres de change" :
--
-- 1) Historique : une lettre de change déjà émise doit conserver le nom et
--    l'adresse du fournisseur tels qu'ils étaient au moment de la création,
--    même si la fiche fournisseur est modifiée par la suite (document
--    négociable physique déjà en circulation).
-- 2) Intégrité : une facture fournisseur ne peut pas être réglée deux fois
--    par lettres de change, et ne doit pas déjà comporter un paiement
--    partiel en espèces/virement au moment du règlement par traites.
-- 3) Synchronisation : le paiement d'une lettre de change doit mettre à
--    jour le montant payé et le statut de la facture fournisseur sous-
--    jacente (comme le fait déjà `record_payment` pour les paiements
--    classiques), et ne doit pas pouvoir être appliqué deux fois à la
--    même lettre.

-- ---------------------------------------------------------------------
-- 1) Snapshot du nom/adresse fournisseur au moment de la création.
-- ---------------------------------------------------------------------

alter table public.bills_of_exchange add column if not exists supplier_name_snapshot text;
alter table public.bills_of_exchange add column if not exists supplier_address_snapshot text;
alter table public.bills_of_exchange add column if not exists purchase_document_number_snapshot text;

create or replace function public.create_supplier_settlement(
  p_supplier_id uuid,
  p_purchase_id uuid,
  p_bills jsonb,
  p_bank_name text default null,
  p_bank_agency text default null,
  p_rib_code_banque text default null,
  p_rib_code_agence text default null,
  p_rib_compte text default null,
  p_rib_cle text default null,
  p_bill_place text default null,
  p_aval_info text default null,
  p_notes text default null
) returns public.supplier_settlements
language plpgsql security definer as $$
declare
  v_purchase public.purchases;
  v_supplier public.suppliers;
  v_settlement public.supplier_settlements;
  v_settlement_number text;
  v_bill jsonb;
  v_sum numeric := 0;
  v_count int;
  v_seq int := 0;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('supplier_settlements', 'create')) then
    raise exception 'Vous n''avez pas le droit de créer un règlement fournisseur.';
  end if;

  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if not found then raise exception 'Facture fournisseur introuvable.'; end if;
  if v_purchase.supplier_id != p_supplier_id then
    raise exception 'Cette facture n''appartient pas au fournisseur sélectionné.';
  end if;

  select * into v_supplier from public.suppliers where id = p_supplier_id;
  if not found then raise exception 'Fournisseur introuvable.'; end if;

  -- Intégrité : pas de double règlement par lettres de change sur la même facture.
  if exists (
    select 1 from public.bills_of_exchange b
    where b.purchase_id = p_purchase_id and b.status <> 'annulee'
  ) then
    raise exception 'Cette facture possède déjà des lettres de change actives. Annulez-les avant de créer un nouveau règlement.';
  end if;

  -- Intégrité : pas de mélange paiement classique partiel + lettres de change
  -- (le total des lettres doit correspondre exactement au solde de la facture).
  if v_purchase.amount_paid > 0 then
    raise exception 'Cette facture comporte déjà un paiement partiel classique (%). Le règlement par lettres de change doit porter sur une facture non réglée.', v_purchase.amount_paid;
  end if;

  v_count := jsonb_array_length(p_bills);
  if v_count is null or v_count = 0 then
    raise exception 'Veuillez fournir au moins une lettre de change.';
  end if;

  for v_bill in select * from jsonb_array_elements(p_bills) loop
    v_sum := v_sum + (v_bill->>'amount')::numeric;
  end loop;

  if abs(v_sum - v_purchase.total_ttc) > 0.001 then
    raise exception 'La somme des lettres de change (%) doit être égale au total de la facture (%).', v_sum, v_purchase.total_ttc;
  end if;

  v_settlement_number := 'REG-' || to_char(now(), 'YYYY') || '-' || lpad((
    select count(*) + 1 from public.supplier_settlements where extract(year from created_at) = extract(year from now())
  )::text, 4, '0');

  insert into public.supplier_settlements (
    settlement_number, supplier_id, purchase_id, total_amount, bills_count,
    bank_name, bank_agency, rib_code_banque, rib_code_agence, rib_compte, rib_cle,
    bill_place, aval_info, notes, created_by
  ) values (
    v_settlement_number, p_supplier_id, p_purchase_id, v_sum, v_count,
    p_bank_name, p_bank_agency, p_rib_code_banque, p_rib_code_agence, p_rib_compte, p_rib_cle,
    p_bill_place, nullif(trim(p_aval_info), ''), nullif(trim(p_notes), ''), auth.uid()
  ) returning * into v_settlement;

  for v_bill in select * from jsonb_array_elements(p_bills) loop
    v_seq := v_seq + 1;
    insert into public.bills_of_exchange (
      settlement_id, bill_number, sequence_no, supplier_id, purchase_id,
      amount, due_date, created_by,
      supplier_name_snapshot, supplier_address_snapshot, purchase_document_number_snapshot
    ) values (
      v_settlement.id, v_settlement_number || '-' || v_seq::text, v_seq, p_supplier_id, p_purchase_id,
      (v_bill->>'amount')::numeric, (v_bill->>'due_date')::date, auth.uid(),
      v_supplier.name, v_supplier.address, v_purchase.document_number
    );
  end loop;

  perform public.write_audit_log('create', 'supplier_settlements', 'supplier_settlement', v_settlement.id, v_settlement_number, null, null,
    'Règlement fournisseur créé : ' || v_settlement_number || ' (' || v_count || ' lettres, ' || v_sum || ' TND)');

  select * into v_settlement from public.supplier_settlements where id = v_settlement.id;
  return v_settlement;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) mark_bill_paid : synchronise la facture fournisseur et empêche le
--    double encaissement de la même lettre.
-- ---------------------------------------------------------------------

create or replace function public.mark_bill_paid(p_bill_id uuid, p_payment_date date default current_date)
returns public.bills_of_exchange language plpgsql security definer as $$
declare
  v_bill public.bills_of_exchange;
  v_purchase public.purchases;
  v_new_amount_paid numeric;
  v_new_status text;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('bills_of_exchange', 'mark_paid')) then
    raise exception 'Vous n''avez pas le droit de marquer une lettre de change comme payée.';
  end if;
  select * into v_bill from public.bills_of_exchange where id = p_bill_id for update;
  if not found then raise exception 'Lettre de change introuvable.'; end if;
  if v_bill.status = 'annulee' then raise exception 'Cette lettre de change est annulée.'; end if;
  if v_bill.status = 'payee' then raise exception 'Cette lettre de change est déjà marquée comme payée.'; end if;

  update public.bills_of_exchange set status = 'payee', payment_date = p_payment_date where id = p_bill_id;

  -- Synchronise le solde de la facture fournisseur (comme record_payment).
  select * into v_purchase from public.purchases where id = v_bill.purchase_id for update;
  if v_purchase.status in ('valide', 'partiellement_paye') then
    v_new_amount_paid := v_purchase.amount_paid + v_bill.amount;
    v_new_status := case
      when v_new_amount_paid >= v_purchase.total_ttc then 'paye'
      else 'partiellement_paye'
    end;
    update public.purchases set amount_paid = v_new_amount_paid, status = v_new_status
    where id = v_purchase.id;
  end if;

  perform public.write_audit_log('mark_paid', 'bills_of_exchange', 'bill_of_exchange', p_bill_id, v_bill.bill_number, null, null,
    'Lettre de change payée : ' || v_bill.bill_number);

  select * into v_bill from public.bills_of_exchange where id = p_bill_id;
  return v_bill;
end;
$$;
