-- Lettres de change (bills of exchange) used to settle a supplier invoice
-- over several due dates, grouped under a "règlement fournisseur" batch.

-- ---------------------------------------------------------------------
-- Default bank/domiciliation info for OUR company (the "Tiré"/drawee).
-- Filled once by the user, then reused automatically for every future
-- batch (see §10 "smart data collection": ERP data first, then saved
-- values, then ask, never invent).
-- ---------------------------------------------------------------------

alter table public.company_settings add column if not exists bank_name text;
alter table public.company_settings add column if not exists bank_agency text;
alter table public.company_settings add column if not exists rib_code_banque text;
alter table public.company_settings add column if not exists rib_code_agence text;
alter table public.company_settings add column if not exists rib_compte text;
alter table public.company_settings add column if not exists rib_cle text;
alter table public.company_settings add column if not exists default_bill_place text;

-- ---------------------------------------------------------------------
-- RÈGLEMENT FOURNISSEUR (payment batch / settlement)
-- ---------------------------------------------------------------------

create table if not exists public.supplier_settlements (
  id uuid primary key default gen_random_uuid(),
  settlement_number text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  purchase_id uuid not null references public.purchases(id),
  total_amount numeric(14,3) not null check (total_amount > 0),
  bills_count int not null check (bills_count > 0),
  bank_name text,
  bank_agency text,
  rib_code_banque text,
  rib_code_agence text,
  rib_compte text,
  rib_cle text,
  bill_place text,
  aval_info text,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_supplier_settlements_supplier on public.supplier_settlements (supplier_id);
create index if not exists idx_supplier_settlements_purchase on public.supplier_settlements (purchase_id);

-- ---------------------------------------------------------------------
-- LETTRE DE CHANGE (individual bill)
-- ---------------------------------------------------------------------

do $$ begin
  create type public.bill_status as enum ('non_payee', 'payee', 'annulee');
exception when duplicate_object then null; end $$;

create table if not exists public.bills_of_exchange (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.supplier_settlements(id) on delete cascade,
  bill_number text not null unique,
  sequence_no int not null,
  supplier_id uuid not null references public.suppliers(id),
  purchase_id uuid not null references public.purchases(id),
  amount numeric(14,3) not null check (amount > 0),
  creation_date date not null default current_date,
  due_date date not null,
  status public.bill_status not null default 'non_payee',
  payment_date date,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_bills_settlement on public.bills_of_exchange (settlement_id);
create index if not exists idx_bills_supplier on public.bills_of_exchange (supplier_id);
create index if not exists idx_bills_status on public.bills_of_exchange (status);
create index if not exists idx_bills_due_date on public.bills_of_exchange (due_date);

alter table public.supplier_settlements enable row level security;
alter table public.bills_of_exchange enable row level security;

create policy supplier_settlements_select on public.supplier_settlements
  for select using (public.is_admin() or public.has_permission('supplier_settlements', 'view'));

create policy bills_of_exchange_select on public.bills_of_exchange
  for select using (public.is_admin() or public.has_permission('bills_of_exchange', 'view'));

-- No direct insert/update policies: all writes go through the
-- SECURITY DEFINER functions below, which enforce that the sum of the
-- bills always equals the settlement total (data integrity, §11).

-- ---------------------------------------------------------------------
-- create_supplier_settlement: creates the settlement and all of its bills
-- atomically. p_bills is a JSON array of {"amount": n, "due_date": "YYYY-MM-DD"}.
-- ---------------------------------------------------------------------

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
      amount, due_date, created_by
    ) values (
      v_settlement.id, v_settlement_number || '-' || v_seq::text, v_seq, p_supplier_id, p_purchase_id,
      (v_bill->>'amount')::numeric, (v_bill->>'due_date')::date, auth.uid()
    );
  end loop;

  perform public.write_audit_log('create', 'supplier_settlements', 'supplier_settlement', v_settlement.id, v_settlement_number, null, null,
    'Règlement fournisseur créé : ' || v_settlement_number || ' (' || v_count || ' lettres, ' || v_sum || ' TND)');

  select * into v_settlement from public.supplier_settlements where id = v_settlement.id;
  return v_settlement;
end;
$$;

-- ---------------------------------------------------------------------
-- mark_bill_paid / cancel_bill: explicit, user-triggered status changes.
-- Due dates elapsing never change the status automatically (§1.4).
-- ---------------------------------------------------------------------

create or replace function public.mark_bill_paid(p_bill_id uuid, p_payment_date date default current_date)
returns public.bills_of_exchange language plpgsql security definer as $$
declare v_bill public.bills_of_exchange;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('bills_of_exchange', 'mark_paid')) then
    raise exception 'Vous n''avez pas le droit de marquer une lettre de change comme payée.';
  end if;
  select * into v_bill from public.bills_of_exchange where id = p_bill_id for update;
  if not found then raise exception 'Lettre de change introuvable.'; end if;
  if v_bill.status = 'annulee' then raise exception 'Cette lettre de change est annulée.'; end if;

  update public.bills_of_exchange set status = 'payee', payment_date = p_payment_date where id = p_bill_id;

  perform public.write_audit_log('mark_paid', 'bills_of_exchange', 'bill_of_exchange', p_bill_id, v_bill.bill_number, null, null,
    'Lettre de change payée : ' || v_bill.bill_number);

  select * into v_bill from public.bills_of_exchange where id = p_bill_id;
  return v_bill;
end;
$$;

create or replace function public.cancel_bill(p_bill_id uuid)
returns public.bills_of_exchange language plpgsql security definer as $$
declare v_bill public.bills_of_exchange;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('bills_of_exchange', 'edit')) then
    raise exception 'Vous n''avez pas le droit d''annuler une lettre de change.';
  end if;
  select * into v_bill from public.bills_of_exchange where id = p_bill_id for update;
  if not found then raise exception 'Lettre de change introuvable.'; end if;
  if v_bill.status = 'payee' then raise exception 'Une lettre de change payée ne peut pas être annulée.'; end if;

  update public.bills_of_exchange set status = 'annulee' where id = p_bill_id;

  perform public.write_audit_log('cancel', 'bills_of_exchange', 'bill_of_exchange', p_bill_id, v_bill.bill_number, null, null,
    'Lettre de change annulée : ' || v_bill.bill_number);

  select * into v_bill from public.bills_of_exchange where id = p_bill_id;
  return v_bill;
end;
$$;
