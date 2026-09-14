-- =====================================================================
-- Fix B1: cancel_sale does not reverse amount_paid or mark linked
-- payments as cancelled, causing financial data corruption.
--
-- This migration:
-- 1. Adds a `status` column to the `payments` table (default 'actif')
--    following the same pattern used on sales, purchases, returns, etc.
-- 2. Updates `cancel_sale` to mark linked payments as 'annule' and
--    reset `amount_paid` to 0 when cancelling a partially paid sale.
--
-- Payment history is preserved — records are marked, not deleted.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Add status column to payments table
-- ---------------------------------------------------------------------

alter table public.payments
  add column if not exists status text not null default 'actif'
  check (status in ('actif', 'annule'));

create index if not exists idx_payments_status
  on public.payments (status) where status = 'annule';

-- ---------------------------------------------------------------------
-- 2. Update cancel_sale to reverse payments and reset amount_paid
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
    -- Restore stock for each sale line.
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

    -- Mark linked payments as cancelled (preserves payment history).
    update public.payments
      set status = 'annule'
      where sale_id = p_sale_id and status = 'actif';
  end if;

  -- Reset amount_paid and set status to cancelled.
  update public.sales
    set status = 'annule', amount_paid = 0
    where id = p_sale_id;

  perform public.write_audit_log(
    'cancel', 'sales', 'sale', p_sale_id,
    v_sale.document_number, null, null,
    'Vente annulée: ' || v_sale.document_number
  );

  select * into v_sale from public.sales where id = p_sale_id;
  return v_sale;
end;
$$;
