-- =====================================================================
-- Fix B2, B3, B4: Release blockers from pre-production audit.
--
-- B2: record_payment has no server-side amount validation.
--     An attacker could record negative payments or overpay beyond
--     the remaining balance via direct API call.
--
-- B3: cancel_supplier_return and cancel_customer_return lack permission
--     checks. Any active employee can cancel any return via direct RPC.
--
-- B4: close_pos_session lacks ownership and permission checks.
--     Any active employee can close any POS session via direct RPC.
-- =====================================================================

-- ---------------------------------------------------------------------
-- B2: Add server-side amount validation to record_payment
-- ---------------------------------------------------------------------

create or replace function public.record_payment(
  p_payment_type text,
  p_partner_type text,
  p_partner_id uuid,
  p_amount numeric,
  p_payment_method_id uuid default null,
  p_sale_id uuid default null,
  p_purchase_id uuid default null,
  p_payment_date date default null,
  p_notes text default null
) returns public.payments
language plpgsql
security definer
as $$
declare
  v_payment public.payments;
  v_doc_number text;
  v_sale public.sales;
  v_purchase public.purchases;
  v_new_amount_paid numeric;
  v_new_status text;
  v_remaining numeric;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('payments', 'create')) then
    raise exception 'Vous n''avez pas le droit d''enregistrer des paiements.';
  end if;

  -- B2: Validate amount is positive.
  if p_amount is null or p_amount <= 0 then
    raise exception 'Le montant du paiement doit être strictement positif.';
  end if;

  -- B2: Validate amount does not exceed remaining balance for sales.
  if p_sale_id is not null then
    select * into v_sale from public.sales where id = p_sale_id for update;
    if not found then
      raise exception 'Vente introuvable.';
    end if;
    if v_sale.status not in ('valide', 'partiellement_paye') then
      raise exception 'Cette vente n''est pas dans un état permettant un paiement (statut: %).', v_sale.status;
    end if;
    v_remaining := v_sale.total_ttc - v_sale.amount_paid;
    if p_amount > v_remaining + 0.001 then
      raise exception 'Le montant du paiement (%) dépasse le solde restant (%).', p_amount, v_remaining;
    end if;
  end if;

  -- B2: Validate amount does not exceed remaining balance for purchases.
  if p_purchase_id is not null then
    select * into v_purchase from public.purchases where id = p_purchase_id for update;
    if not found then
      raise exception 'Achat introuvable.';
    end if;
    if v_purchase.status not in ('valide', 'partiellement_paye') then
      raise exception 'Cet achat n''est pas dans un état permettant un paiement (statut: %).', v_purchase.status;
    end if;
    v_remaining := v_purchase.total_ttc - v_purchase.amount_paid;
    if p_amount > v_remaining + 0.001 then
      raise exception 'Le montant du paiement (%) dépasse le solde restant (%).', p_amount, v_remaining;
    end if;
  end if;

  v_doc_number := public.next_document_number('PAY');

  insert into public.payments (
    document_number, payment_type, partner_type, partner_id,
    sale_id, purchase_id, payment_method_id, amount,
    payment_date, notes, created_by
  ) values (
    v_doc_number, p_payment_type, p_partner_type, p_partner_id,
    p_sale_id, p_purchase_id, p_payment_method_id, p_amount,
    coalesce(p_payment_date, current_date), p_notes, auth.uid()
  ) returning * into v_payment;

  -- Update sale status if linked.
  if p_sale_id is not null then
    -- v_sale already locked and validated above.
    v_new_amount_paid := v_sale.amount_paid + p_amount;
    v_new_status := case
      when v_new_amount_paid >= v_sale.total_ttc then 'paye'
      else 'partiellement_paye'
    end;
    update public.sales set amount_paid = v_new_amount_paid, status = v_new_status
    where id = p_sale_id;
  end if;

  -- Update purchase status if linked.
  if p_purchase_id is not null then
    -- v_purchase already locked and validated above.
    v_new_amount_paid := v_purchase.amount_paid + p_amount;
    v_new_status := case
      when v_new_amount_paid >= v_purchase.total_ttc then 'paye'
      else 'partiellement_paye'
    end;
    update public.purchases set amount_paid = v_new_amount_paid, status = v_new_status
    where id = p_purchase_id;
  end if;

  perform public.write_audit_log(
    'create', 'payments', 'payment', v_payment.id,
    v_doc_number, null, null,
    'Paiement enregistré: ' || v_doc_number || ' (' || p_amount::text || ')'
  );

  return v_payment;
end;
$$;

-- ---------------------------------------------------------------------
-- B3: Add permission checks to cancel_supplier_return
-- ---------------------------------------------------------------------

create or replace function public.cancel_supplier_return(p_return_id uuid)
returns public.supplier_returns
language plpgsql
security definer
as $$
declare
  v_ret public.supplier_returns;
  v_line public.supplier_return_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('supplier_returns', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les retours fournisseurs.';
  end if;

  select * into v_ret from public.supplier_returns where id = p_return_id for update;
  if not found then
    raise exception 'Retour fournisseur introuvable.';
  end if;
  if v_ret.status = 'annule' then
    raise exception 'Ce retour est déjà annulé.';
  end if;
  if v_ret.status = 'valide' then
    for v_line in select * from public.supplier_return_lines where supplier_return_id = p_return_id loop
      perform public.upsert_stock_level(v_line.article_id, v_ret.depot_id, null, v_line.quantity);
    end loop;
  end if;

  update public.supplier_returns set status = 'annule' where id = p_return_id;

  perform public.write_audit_log(
    'cancel', 'supplier_returns', 'supplier_return', p_return_id,
    v_ret.document_number, null, null,
    'Retour fournisseur annulé: ' || v_ret.document_number
  );

  select * into v_ret from public.supplier_returns where id = p_return_id;
  return v_ret;
end;
$$;

-- ---------------------------------------------------------------------
-- B3: Add permission checks to cancel_customer_return
-- ---------------------------------------------------------------------

create or replace function public.cancel_customer_return(p_return_id uuid)
returns public.customer_returns
language plpgsql
security definer
as $$
declare
  v_ret public.customer_returns;
  v_line public.customer_return_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('customer_returns', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les retours clients.';
  end if;

  select * into v_ret from public.customer_returns where id = p_return_id for update;
  if not found then
    raise exception 'Retour client introuvable.';
  end if;
  if v_ret.status = 'annule' then
    raise exception 'Ce retour est déjà annulé.';
  end if;
  if v_ret.status = 'valide' then
    for v_line in select * from public.customer_return_lines where customer_return_id = p_return_id loop
      perform public.upsert_stock_level(
        v_line.article_id, v_ret.depot_id, v_ret.showroom_id, -v_line.quantity
      );
    end loop;
  end if;

  update public.customer_returns set status = 'annule' where id = p_return_id;

  perform public.write_audit_log(
    'cancel', 'customer_returns', 'customer_return', p_return_id,
    v_ret.document_number, null, null,
    'Retour client annulé: ' || v_ret.document_number
  );

  select * into v_ret from public.customer_returns where id = p_return_id;
  return v_ret;
end;
$$;

-- ---------------------------------------------------------------------
-- B4: Add ownership and permission check to close_pos_session
-- ---------------------------------------------------------------------

create or replace function public.close_pos_session(
  p_session_id uuid,
  p_closing_cash numeric,
  p_notes text default null
) returns public.pos_sessions
language plpgsql
security definer
as $$
declare
  v_session public.pos_sessions;
  v_total_sales numeric := 0;
  v_cash_sales numeric := 0;
  v_card_sales numeric := 0;
  v_expected numeric;
  v_diff numeric;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('pos', 'close_pos')) then
    raise exception 'Vous n''avez pas le droit de clôturer une session de caisse.';
  end if;

  select * into v_session from public.pos_sessions where id = p_session_id for update;
  if not found then
    raise exception 'Session de caisse introuvable.';
  end if;
  if v_session.status != 'ouverte' then
    raise exception 'Cette session n''est pas ouverte.';
  end if;

  -- B4: Only the session owner or an admin can close the session.
  if v_session.employee_id != auth.uid() and not public.is_admin() then
    raise exception 'Vous ne pouvez clôturer que votre propre session de caisse.';
  end if;

  select
    coalesce(sum(total_ttc), 0),
    coalesce(sum(case when payment_method_id is null then total_ttc else 0 end), 0)
  into v_total_sales, v_cash_sales
  from public.sales
  where pos_session_id = p_session_id and status in ('valide', 'partiellement_paye', 'paye');

  v_card_sales := v_total_sales - v_cash_sales;
  v_expected := v_session.opening_cash + v_cash_sales;
  v_diff := p_closing_cash - v_expected;

  update public.pos_sessions set
    status = 'cloturee',
    closing_date = now(),
    closing_cash = p_closing_cash,
    expected_cash = v_expected,
    cash_difference = v_diff,
    total_sales = v_total_sales,
    total_cash_sales = v_cash_sales,
    total_card_sales = v_card_sales,
    notes = p_notes
  where id = p_session_id;

  perform public.write_audit_log(
    'close', 'pos', 'pos_session', p_session_id,
    v_session.session_number, null, null,
    'Session de caisse clôturée: ' || v_session.session_number ||
    ' | Écart: ' || v_diff::text
  );

  select * into v_session from public.pos_sessions where id = p_session_id;
  return v_session;
end;
$$;
