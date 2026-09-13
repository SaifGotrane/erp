-- =====================================================================
-- Jabnoun ERP — Phase 4-8 : RPC functions
-- validate_sale, cancel_sale, validate_delivery, cancel_delivery,
-- validate_supplier_return, cancel_supplier_return,
-- validate_customer_return, cancel_customer_return,
-- open_pos_session, close_pos_session,
-- record_payment, validate_adjustment, cancel_adjustment,
-- report_sales_summary, report_purchases_summary, report_stock_valuation,
-- report_tva_summary, report_partner_statement.
-- =====================================================================

-- ---------------------------------------------------------------------
-- VALIDATE SALE
-- ---------------------------------------------------------------------

create or replace function public.validate_sale(p_sale_id uuid)
returns public.sales
language plpgsql
security definer
as $$
declare
  v_sale public.sales;
  v_line public.sale_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('sales', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les ventes.';
  end if;

  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then
    raise exception 'Vente introuvable.';
  end if;
  if v_sale.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_sale.status;
  end if;

  -- Recalculate totals server-side.
  select
    coalesce(sum(line_total_ht), 0),
    coalesce(sum(line_total_tva), 0),
    coalesce(sum(line_total_ttc), 0)
  into v_sale.total_ht, v_sale.total_tva, v_sale.total_ttc
  from public.sale_lines where sale_id = p_sale_id;

  if v_sale.discount_percent > 0 then
    v_sale.discount_amount := round(v_sale.total_ht * v_sale.discount_percent / 100, 3);
    v_sale.total_ht := v_sale.total_ht - v_sale.discount_amount;
    v_sale.total_tva := round(v_sale.total_ht * (
      case when v_sale.total_ht > 0
           then v_sale.total_tva / (v_sale.total_ht + v_sale.discount_amount)
           else 0 end), 3);
    v_sale.total_ttc := v_sale.total_ht + v_sale.total_tva;
  end if;

  update public.sales set
    status = 'valide',
    total_ht = v_sale.total_ht,
    total_tva = v_sale.total_tva,
    total_ttc = v_sale.total_ttc,
    discount_amount = v_sale.discount_amount,
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_sale_id;

  -- Decrease stock for each line.
  for v_line in select * from public.sale_lines where sale_id = p_sale_id loop
    perform public.upsert_stock_level(
      v_line.article_id, v_sale.depot_id, v_sale.showroom_id, -v_line.quantity
    );

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      source_depot_id, source_showroom_id, source_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'vente', v_line.quantity,
      v_sale.depot_id, v_sale.showroom_id, 'Vente ' || v_sale.document_number,
      'vente', p_sale_id, v_sale.document_number, auth.uid()
    );
  end loop;

  perform public.write_audit_log(
    'validate', 'sales', 'sale', p_sale_id,
    v_sale.document_number, null, null,
    'Vente validée: ' || v_sale.document_number
  );

  select * into v_sale from public.sales where id = p_sale_id;
  return v_sale;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL SALE
-- ---------------------------------------------------------------------

create or replace function public.cancel_sale(p_sale_id uuid)
returns public.sales
language plpgsql
security definer
as $$
declare
  v_sale public.sales;
  v_line public.sale_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('sales', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les ventes.';
  end if;

  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then
    raise exception 'Vente introuvable.';
  end if;
  if v_sale.status = 'annule' then
    raise exception 'Cette vente est déjà annulée.';
  end if;
  if v_sale.status = 'paye' then
    raise exception 'Impossible d''annuler une vente entièrement payée.';
  end if;

  if v_sale.status in ('valide', 'partiellement_paye') then
    for v_line in select * from public.sale_lines where sale_id = p_sale_id loop
      perform public.upsert_stock_level(
        v_line.article_id, v_sale.depot_id, v_sale.showroom_id, v_line.quantity
      );

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        destination_depot_id, destination_showroom_id, destination_label,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'retour_client', v_line.quantity,
        v_sale.depot_id, v_sale.showroom_id, 'Annulation vente ' || v_sale.document_number,
        'vente', p_sale_id, v_sale.document_number, auth.uid()
      );
    end loop;
  end if;

  update public.sales set status = 'annule' where id = p_sale_id;

  perform public.write_audit_log(
    'cancel', 'sales', 'sale', p_sale_id,
    v_sale.document_number, null, null,
    'Vente annulée: ' || v_sale.document_number
  );

  select * into v_sale from public.sales where id = p_sale_id;
  return v_sale;
end;
$$;

-- ---------------------------------------------------------------------
-- VALIDATE DELIVERY NOTE
-- ---------------------------------------------------------------------

create or replace function public.validate_delivery(p_delivery_id uuid)
returns public.delivery_notes
language plpgsql
security definer
as $$
declare
  v_delivery public.delivery_notes;
  v_line public.delivery_note_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('delivery_notes', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les bons de livraison.';
  end if;

  select * into v_delivery from public.delivery_notes where id = p_delivery_id for update;
  if not found then
    raise exception 'Bon de livraison introuvable.';
  end if;
  if v_delivery.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé.';
  end if;

  for v_line in select * from public.delivery_note_lines where delivery_note_id = p_delivery_id loop
    perform public.upsert_stock_level(
      v_line.article_id, v_delivery.depot_id, v_delivery.showroom_id, -v_line.quantity
    );

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      source_depot_id, source_showroom_id, source_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'sortie', v_line.quantity,
      v_delivery.depot_id, v_delivery.showroom_id, 'Livraison ' || v_delivery.document_number,
      'livraison', p_delivery_id, v_delivery.document_number, auth.uid()
    );
  end loop;

  update public.delivery_notes set
    status = 'livre',
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_delivery_id;

  perform public.write_audit_log(
    'validate', 'delivery_notes', 'delivery_note', p_delivery_id,
    v_delivery.document_number, null, null,
    'Bon de livraison validé: ' || v_delivery.document_number
  );

  select * into v_delivery from public.delivery_notes where id = p_delivery_id;
  return v_delivery;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL DELIVERY NOTE
-- ---------------------------------------------------------------------

create or replace function public.cancel_delivery(p_delivery_id uuid)
returns public.delivery_notes
language plpgsql
security definer
as $$
declare
  v_delivery public.delivery_notes;
  v_line public.delivery_note_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('delivery_notes', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les bons de livraison.';
  end if;

  select * into v_delivery from public.delivery_notes where id = p_delivery_id for update;
  if not found then
    raise exception 'Bon de livraison introuvable.';
  end if;
  if v_delivery.status = 'annule' then
    raise exception 'Ce bon de livraison est déjà annulé.';
  end if;

  if v_delivery.status = 'livre' then
    for v_line in select * from public.delivery_note_lines where delivery_note_id = p_delivery_id loop
      perform public.upsert_stock_level(
        v_line.article_id, v_delivery.depot_id, v_delivery.showroom_id, v_line.quantity
      );
    end loop;
  end if;

  update public.delivery_notes set status = 'annule' where id = p_delivery_id;

  perform public.write_audit_log(
    'cancel', 'delivery_notes', 'delivery_note', p_delivery_id,
    v_delivery.document_number, null, null,
    'Bon de livraison annulé: ' || v_delivery.document_number
  );

  select * into v_delivery from public.delivery_notes where id = p_delivery_id;
  return v_delivery;
end;
$$;

-- ---------------------------------------------------------------------
-- VALIDATE SUPPLIER RETURN
-- ---------------------------------------------------------------------

create or replace function public.validate_supplier_return(p_return_id uuid)
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
  if not (public.is_admin() or public.has_permission('supplier_returns', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les retours fournisseurs.';
  end if;

  select * into v_ret from public.supplier_returns where id = p_return_id for update;
  if not found then
    raise exception 'Retour fournisseur introuvable.';
  end if;
  if v_ret.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé.';
  end if;

  select
    coalesce(sum(line_total_ht), 0),
    coalesce(sum(line_total_tva), 0),
    coalesce(sum(line_total_ttc), 0)
  into v_ret.total_ht, v_ret.total_tva, v_ret.total_ttc
  from public.supplier_return_lines where supplier_return_id = p_return_id;

  update public.supplier_returns set
    status = 'valide',
    total_ht = v_ret.total_ht,
    total_tva = v_ret.total_tva,
    total_ttc = v_ret.total_ttc,
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_return_id;

  for v_line in select * from public.supplier_return_lines where supplier_return_id = p_return_id loop
    perform public.upsert_stock_level(v_line.article_id, v_ret.depot_id, null, -v_line.quantity);

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      source_depot_id, source_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'retour_fournisseur', v_line.quantity,
      v_ret.depot_id, 'Retour fournisseur ' || v_ret.document_number,
      'retour_fournisseur', p_return_id, v_ret.document_number, auth.uid()
    );
  end loop;

  perform public.write_audit_log(
    'validate', 'supplier_returns', 'supplier_return', p_return_id,
    v_ret.document_number, null, null,
    'Retour fournisseur validé: ' || v_ret.document_number
  );

  select * into v_ret from public.supplier_returns where id = p_return_id;
  return v_ret;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL SUPPLIER RETURN
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
-- VALIDATE CUSTOMER RETURN
-- ---------------------------------------------------------------------

create or replace function public.validate_customer_return(p_return_id uuid)
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
  if not (public.is_admin() or public.has_permission('customer_returns', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les retours clients.';
  end if;

  select * into v_ret from public.customer_returns where id = p_return_id for update;
  if not found then
    raise exception 'Retour client introuvable.';
  end if;
  if v_ret.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé.';
  end if;

  select
    coalesce(sum(line_total_ht), 0),
    coalesce(sum(line_total_tva), 0),
    coalesce(sum(line_total_ttc), 0)
  into v_ret.total_ht, v_ret.total_tva, v_ret.total_ttc
  from public.customer_return_lines where customer_return_id = p_return_id;

  update public.customer_returns set
    status = 'valide',
    total_ht = v_ret.total_ht,
    total_tva = v_ret.total_tva,
    total_ttc = v_ret.total_ttc,
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_return_id;

  for v_line in select * from public.customer_return_lines where customer_return_id = p_return_id loop
    perform public.upsert_stock_level(
      v_line.article_id, v_ret.depot_id, v_ret.showroom_id, v_line.quantity
    );

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      destination_depot_id, destination_showroom_id, destination_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'retour_client', v_line.quantity,
      v_ret.depot_id, v_ret.showroom_id, 'Retour client ' || v_ret.document_number,
      'retour_client', p_return_id, v_ret.document_number, auth.uid()
    );
  end loop;

  perform public.write_audit_log(
    'validate', 'customer_returns', 'customer_return', p_return_id,
    v_ret.document_number, null, null,
    'Retour client validé: ' || v_ret.document_number
  );

  select * into v_ret from public.customer_returns where id = p_return_id;
  return v_ret;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL CUSTOMER RETURN
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
-- OPEN POS SESSION
-- ---------------------------------------------------------------------

create or replace function public.open_pos_session(
  p_showroom_id uuid default null,
  p_opening_cash numeric default 0
) returns public.pos_sessions
language plpgsql
security definer
as $$
declare
  v_session public.pos_sessions;
  v_doc_number text;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('pos', 'create')) then
    raise exception 'Vous n''avez pas le droit d''ouvrir une session de caisse.';
  end if;

  -- Check no open session for this employee.
  if exists (
    select 1 from public.pos_sessions
    where employee_id = auth.uid() and status = 'ouverte'
  ) then
    raise exception 'Vous avez déjà une session de caisse ouverte.';
  end if;

  v_doc_number := public.next_document_number('CAISSE');

  insert into public.pos_sessions (
    session_number, showroom_id, employee_id,
    opening_date, status, opening_cash
  ) values (
    v_doc_number, p_showroom_id, auth.uid(),
    now(), 'ouverte', p_opening_cash
  ) returning * into v_session;

  perform public.write_audit_log(
    'open', 'pos', 'pos_session', v_session.id,
    v_session.session_number, null, null,
    'Session de caisse ouverte: ' || v_session.session_number
  );

  return v_session;
end;
$$;

-- ---------------------------------------------------------------------
-- CLOSE POS SESSION
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

  select * into v_session from public.pos_sessions where id = p_session_id for update;
  if not found then
    raise exception 'Session de caisse introuvable.';
  end if;
  if v_session.status != 'ouverte' then
    raise exception 'Cette session n''est pas ouverte.';
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

-- ---------------------------------------------------------------------
-- RECORD PAYMENT
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
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('payments', 'create')) then
    raise exception 'Vous n''avez pas le droit d''enregistrer des paiements.';
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
    select * into v_sale from public.sales where id = p_sale_id for update;
    if v_sale.status in ('valide', 'partiellement_paye') then
      v_new_amount_paid := v_sale.amount_paid + p_amount;
      v_new_status := case
        when v_new_amount_paid >= v_sale.total_ttc then 'paye'
        else 'partiellement_paye'
      end;
      update public.sales set amount_paid = v_new_amount_paid, status = v_new_status
      where id = p_sale_id;
    end if;
  end if;

  -- Update purchase status if linked.
  if p_purchase_id is not null then
    select * into v_purchase from public.purchases where id = p_purchase_id for update;
    if v_purchase.status in ('valide', 'partiellement_paye') then
      v_new_amount_paid := v_purchase.amount_paid + p_amount;
      v_new_status := case
        when v_new_amount_paid >= v_purchase.total_ttc then 'paye'
        else 'partiellement_paye'
      end;
      update public.purchases set amount_paid = v_new_amount_paid, status = v_new_status
      where id = p_purchase_id;
    end if;
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
-- VALIDATE STOCK ADJUSTMENT
-- ---------------------------------------------------------------------

create or replace function public.validate_adjustment(p_adjustment_id uuid)
returns public.stock_adjustments
language plpgsql
security definer
as $$
declare
  v_adj public.stock_adjustments;
  v_line public.stock_adjustment_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('adjustments', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les ajustements.';
  end if;

  select * into v_adj from public.stock_adjustments where id = p_adjustment_id for update;
  if not found then
    raise exception 'Ajustement introuvable.';
  end if;
  if v_adj.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé.';
  end if;

  for v_line in select * from public.stock_adjustment_lines where adjustment_id = p_adjustment_id loop
    v_line.delta := v_line.new_quantity - v_line.current_quantity;

    update public.stock_adjustment_lines set delta = v_line.delta where id = v_line.id;

    if v_line.delta != 0 then
      perform public.upsert_stock_level(
        v_line.article_id, v_adj.depot_id, v_adj.showroom_id, v_line.delta
      );

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        source_depot_id, source_showroom_id,
        destination_depot_id, destination_showroom_id,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'ajustement', v_line.delta,
        case when v_line.delta < 0 then v_adj.depot_id end,
        case when v_line.delta < 0 then v_adj.showroom_id end,
        case when v_line.delta > 0 then v_adj.depot_id end,
        case when v_line.delta > 0 then v_adj.showroom_id end,
        'ajustement', p_adjustment_id, v_adj.document_number, auth.uid()
      );
    end if;
  end loop;

  update public.stock_adjustments set
    status = 'valide',
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_adjustment_id;

  perform public.write_audit_log(
    'validate', 'adjustments', 'adjustment', p_adjustment_id,
    v_adj.document_number, null, null,
    'Ajustement validé: ' || v_adj.document_number
  );

  select * into v_adj from public.stock_adjustments where id = p_adjustment_id;
  return v_adj;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL STOCK ADJUSTMENT
-- ---------------------------------------------------------------------

create or replace function public.cancel_adjustment(p_adjustment_id uuid)
returns public.stock_adjustments
language plpgsql
security definer
as $$
declare
  v_adj public.stock_adjustments;
  v_line public.stock_adjustment_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  select * into v_adj from public.stock_adjustments where id = p_adjustment_id for update;
  if not found then
    raise exception 'Ajustement introuvable.';
  end if;
  if v_adj.status = 'annule' then
    raise exception 'Cet ajustement est déjà annulé.';
  end if;
  if v_adj.status = 'valide' then
    for v_line in select * from public.stock_adjustment_lines where adjustment_id = p_adjustment_id loop
      if v_line.delta != 0 then
        perform public.upsert_stock_level(
          v_line.article_id, v_adj.depot_id, v_adj.showroom_id, -v_line.delta
        );
      end if;
    end loop;
  end if;

  update public.stock_adjustments set status = 'annule' where id = p_adjustment_id;

  perform public.write_audit_log(
    'cancel', 'adjustments', 'adjustment', p_adjustment_id,
    v_adj.document_number, null, null,
    'Ajustement annulé: ' || v_adj.document_number
  );

  select * into v_adj from public.stock_adjustments where id = p_adjustment_id;
  return v_adj;
end;
$$;

-- ---------------------------------------------------------------------
-- REPORT: SALES SUMMARY
-- ---------------------------------------------------------------------

create or replace function public.report_sales_summary(
  p_from date default null,
  p_to date default null
) returns table (
  total_sales numeric,
  total_ht numeric,
  total_tva numeric,
  total_ttc numeric,
  total_paid numeric,
  total_unpaid numeric,
  sales_count bigint
)
language plpgsql
security definer
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return query
  select
    coalesce(sum(total_ttc), 0),
    coalesce(sum(total_ht), 0),
    coalesce(sum(total_tva), 0),
    coalesce(sum(total_ttc), 0),
    coalesce(sum(amount_paid), 0),
    coalesce(sum(total_ttc - amount_paid), 0),
    count(*)
  from public.sales
  where status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or sale_date >= p_from)
    and (p_to is null or sale_date <= p_to);
end;
$$;

-- ---------------------------------------------------------------------
-- REPORT: PURCHASES SUMMARY
-- ---------------------------------------------------------------------

create or replace function public.report_purchases_summary(
  p_from date default null,
  p_to date default null
) returns table (
  total_purchases numeric,
  total_ht numeric,
  total_tva numeric,
  total_ttc numeric,
  total_paid numeric,
  total_unpaid numeric,
  purchases_count bigint
)
language plpgsql
security definer
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return query
  select
    coalesce(sum(total_ttc), 0),
    coalesce(sum(total_ht), 0),
    coalesce(sum(total_tva), 0),
    coalesce(sum(total_ttc), 0),
    coalesce(sum(amount_paid), 0),
    coalesce(sum(total_ttc - amount_paid), 0),
    count(*)
  from public.purchases
  where status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or purchase_date >= p_from)
    and (p_to is null or purchase_date <= p_to);
end;
$$;

-- ---------------------------------------------------------------------
-- REPORT: STOCK VALUATION
-- ---------------------------------------------------------------------

create or replace function public.report_stock_valuation(
  p_depot_id uuid default null,
  p_showroom_id uuid default null
) returns table (
  article_id uuid,
  reference text,
  designation text,
  quantity numeric,
  purchase_price_ht numeric,
  stock_value numeric
)
language plpgsql
security definer
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return query
  select
    a.id,
    a.reference,
    a.designation,
    coalesce(sl.quantity, 0),
    a.purchase_price_ht,
    coalesce(sl.quantity, 0) * a.purchase_price_ht
  from public.articles a
  left join public.stock_levels sl on sl.article_id = a.id
    and ((p_depot_id is not null and sl.depot_id = p_depot_id) or
         (p_showroom_id is not null and sl.showroom_id = p_showroom_id))
  where a.active = true
  order by a.designation;
end;
$$;

-- ---------------------------------------------------------------------
-- REPORT: TVA SUMMARY
-- ---------------------------------------------------------------------

create or replace function public.report_tva_summary(
  p_from date default null,
  p_to date default null
) returns table (
  collected_tva numeric,
  paid_tva numeric,
  net_tva numeric
)
language plpgsql
security definer
as $$
declare
  v_collected numeric;
  v_paid numeric;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  select coalesce(sum(total_tva), 0) into v_collected
  from public.sales
  where status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or sale_date >= p_from)
    and (p_to is null or sale_date <= p_to);

  select coalesce(sum(total_tva), 0) into v_paid
  from public.purchases
  where status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or purchase_date >= p_from)
    and (p_to is null or purchase_date <= p_to);

  return query select v_collected, v_paid, v_collected - v_paid;
end;
$$;

-- ---------------------------------------------------------------------
-- REPORT: PARTNER STATEMENT (supplier or customer)
-- ---------------------------------------------------------------------

create or replace function public.report_partner_statement(
  p_partner_type text,
  p_partner_id uuid,
  p_from date default null,
  p_to date default null
) returns table (
  document_type text,
  document_number text,
  document_date date,
  total_ttc numeric,
  amount_paid numeric,
  balance numeric
)
language plpgsql
security definer
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  if p_partner_type = 'supplier' then
    return query
    select
      'achat'::text,
      p.document_number,
      p.purchase_date,
      p.total_ttc,
      p.amount_paid,
      p.total_ttc - p.amount_paid
    from public.purchases p
    where p.supplier_id = p_partner_id
      and p.status in ('valide', 'partiellement_paye', 'paye')
      and (p_from is null or p.purchase_date >= p_from)
      and (p_to is null or p.purchase_date <= p_to)
    order by p.purchase_date desc;
  elsif p_partner_type = 'customer' then
    return query
    select
      'vente'::text,
      s.document_number,
      s.sale_date,
      s.total_ttc,
      s.amount_paid,
      s.total_ttc - s.amount_paid
    from public.sales s
    where s.customer_id = p_partner_id
      and s.status in ('valide', 'partiellement_paye', 'paye')
      and (p_from is null or s.sale_date >= p_from)
      and (p_to is null or s.sale_date <= p_to)
    order by s.sale_date desc;
  end if;
end;
$$;
