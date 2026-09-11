-- =====================================================================
-- Fix B5: cancel_purchase does not reverse amount_paid or mark linked
-- payments as cancelled, causing financial data corruption.
--
-- This is the symmetric fix to B1 (cancel_sale). The accounting model
-- for sales and purchases is symmetric: both have amount_paid, both
-- link to the payments table, both have the same status flow.
--
-- Additionally, purchases can be settled via bills of exchange. The
-- bills_of_exchange table has its own status enum (non_payee, payee,
-- annulee) and is separate from the payments table.
--
-- Bill handling rules during purchase cancellation:
--   - non_payee bills → mark as 'annulee' (future obligation voided)
--   - payee bills → leave untouched (completed financial transaction;
--     cancel_bill itself rejects cancelling paid bills)
--   - annulee bills → already cancelled, no action needed
--
-- Payment history is preserved — records are marked, not deleted.
-- =====================================================================

create or replace function public.cancel_purchase(p_purchase_id uuid)
returns public.purchases
language plpgsql
security definer
as $$
declare
  v_purchase public.purchases;
  v_line public.purchase_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('purchases', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les achats.';
  end if;

  select * into v_purchase from public.purchases where id = p_purchase_id for update;
  if not found then
    raise exception 'Achat introuvable.';
  end if;
  if v_purchase.status = 'annule' then
    raise exception 'Cet achat est déjà annulé.';
  end if;
  if v_purchase.status = 'paye' then
    raise exception 'Impossible d''annuler un achat entièrement payé.';
  end if;

  if v_purchase.status in ('valide', 'partiellement_paye') then
    -- Reverse stock if the purchase was validated.
    for v_line in select * from public.purchase_lines where purchase_id = p_purchase_id loop
      perform public.upsert_stock_level(v_line.article_id, v_purchase.depot_id, null, -v_line.quantity);

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        source_depot_id, source_label,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'retour_fournisseur', v_line.quantity,
        v_purchase.depot_id, 'Annulation achat ' || v_purchase.document_number,
        'achat', p_purchase_id, v_purchase.document_number, auth.uid()
      );
    end loop;

    -- Mark linked classic payments as cancelled (preserves payment history).
    update public.payments
      set status = 'annule'
      where purchase_id = p_purchase_id and status = 'actif';

    -- Cancel unpaid bills of exchange linked to this purchase.
    -- Paid bills (status = 'payee') are left untouched: they represent
    -- completed money transfers and cannot be cancelled (per cancel_bill
    -- business rule). A supplier refund would be handled as a separate
    -- transaction.
    update public.bills_of_exchange
      set status = 'annulee'
      where purchase_id = p_purchase_id and status = 'non_payee';
  end if;

  -- Reset amount_paid and set status to cancelled.
  update public.purchases
    set status = 'annule', amount_paid = 0
    where id = p_purchase_id;

  perform public.write_audit_log(
    'cancel', 'purchases', 'purchase', p_purchase_id,
    v_purchase.document_number, null, null,
    'Achat annulé: ' || v_purchase.document_number
  );

  select * into v_purchase from public.purchases where id = p_purchase_id;
  return v_purchase;
end;
$$;
