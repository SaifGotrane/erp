-- =====================================================================
-- Jabnoun ERP — Phase 3 : RLS policies for new tables.
-- =====================================================================

-- ---------------------------------------------------------------------
-- ACTIVER RLS
-- ---------------------------------------------------------------------

alter table public.company_settings enable row level security;
alter table public.payment_methods enable row level security;
alter table public.document_sequences enable row level security;
alter table public.audit_logs enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_lines enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_lines enable row level security;
alter table public.inventory_counts enable row level security;
alter table public.inventory_lines enable row level security;

-- ---------------------------------------------------------------------
-- COMPANY SETTINGS
-- ---------------------------------------------------------------------

create policy company_settings_read on public.company_settings
  for select using (public.is_admin() or public.has_permission('settings', 'view'));

create policy company_settings_update on public.company_settings
  for update using (public.is_admin() or public.has_permission('settings', 'edit'))
  with check (public.is_admin() or public.has_permission('settings', 'edit'));

-- ---------------------------------------------------------------------
-- PAYMENT METHODS
-- ---------------------------------------------------------------------

create policy payment_methods_read on public.payment_methods
  for select using (public.is_active_employee());

create policy payment_methods_write on public.payment_methods
  for all using (public.is_admin() or public.has_permission('settings', 'edit'))
  with check (public.is_admin() or public.has_permission('settings', 'edit'));

-- ---------------------------------------------------------------------
-- DOCUMENT SEQUENCES — access only via SECURITY DEFINER functions.
-- No direct read/write for any client role.
-- ---------------------------------------------------------------------

-- Revoke all direct access; only SECURITY DEFINER functions can use it.
create policy document_sequences_noop on public.document_sequences
  for all using (false) with check (false);

-- ---------------------------------------------------------------------
-- AUDIT LOGS — insert only via SECURITY DEFINER function, read for admin
-- or journalisation:view.
-- ---------------------------------------------------------------------

create policy audit_logs_read on public.audit_logs
  for select using (public.is_admin() or public.has_permission('journalisation', 'view'));

-- No INSERT/UPDATE/DELETE policy → only SECURITY DEFINER functions can write.

-- ---------------------------------------------------------------------
-- PURCHASES
-- ---------------------------------------------------------------------

create policy purchases_read on public.purchases
  for select using (public.is_admin() or public.has_permission('purchases', 'view'));

create policy purchases_insert on public.purchases
  for insert with check (public.is_admin() or public.has_permission('purchases', 'create'));

create policy purchases_update on public.purchases
  for update using (public.is_admin() or public.has_permission('purchases', 'edit'))
  with check (public.is_admin() or public.has_permission('purchases', 'edit'));

create policy purchases_delete on public.purchases
  for delete using (public.is_admin() or public.has_permission('purchases', 'delete'));

-- Purchase lines: same access as parent purchase.
create policy purchase_lines_read on public.purchase_lines
  for select using (
    public.is_admin() or
    exists (
      select 1 from public.purchases p
      where p.id = purchase_lines.purchase_id
      and (public.is_admin() or public.has_permission('purchases', 'view'))
    )
  );

create policy purchase_lines_insert on public.purchase_lines
  for insert with check (
    public.is_admin() or
    exists (
      select 1 from public.purchases p
      where p.id = purchase_lines.purchase_id
      and (public.is_admin() or public.has_permission('purchases', 'create'))
    )
  );

create policy purchase_lines_update on public.purchase_lines
  for update using (
    public.is_admin() or
    exists (
      select 1 from public.purchases p
      where p.id = purchase_lines.purchase_id
      and (public.is_admin() or public.has_permission('purchases', 'edit'))
    )
  );

create policy purchase_lines_delete on public.purchase_lines
  for delete using (
    public.is_admin() or
    exists (
      select 1 from public.purchases p
      where p.id = purchase_lines.purchase_id
      and (public.is_admin() or public.has_permission('purchases', 'edit'))
    )
  );

-- ---------------------------------------------------------------------
-- STOCK TRANSFERS
-- ---------------------------------------------------------------------

create policy transfers_read on public.stock_transfers
  for select using (public.is_admin() or public.has_permission('transfers', 'view'));

create policy transfers_insert on public.stock_transfers
  for insert with check (public.is_admin() or public.has_permission('transfers', 'create'));

create policy transfers_update on public.stock_transfers
  for update using (public.is_admin() or public.has_permission('transfers', 'edit'))
  with check (public.is_admin() or public.has_permission('transfers', 'edit'));

create policy transfers_delete on public.stock_transfers
  for delete using (public.is_admin() or public.has_permission('transfers', 'delete'));

create policy transfer_lines_read on public.stock_transfer_lines
  for select using (
    public.is_admin() or
    exists (
      select 1 from public.stock_transfers t
      where t.id = stock_transfer_lines.transfer_id
      and (public.is_admin() or public.has_permission('transfers', 'view'))
    )
  );

create policy transfer_lines_insert on public.stock_transfer_lines
  for insert with check (
    public.is_admin() or
    exists (
      select 1 from public.stock_transfers t
      where t.id = stock_transfer_lines.transfer_id
      and (public.is_admin() or public.has_permission('transfers', 'create'))
    )
  );

create policy transfer_lines_delete on public.stock_transfer_lines
  for delete using (
    public.is_admin() or
    exists (
      select 1 from public.stock_transfers t
      where t.id = stock_transfer_lines.transfer_id
      and (public.is_admin() or public.has_permission('transfers', 'edit'))
    )
  );

-- ---------------------------------------------------------------------
-- INVENTORY COUNTS
-- ---------------------------------------------------------------------

create policy inventories_read on public.inventory_counts
  for select using (public.is_admin() or public.has_permission('inventories', 'view'));

create policy inventories_insert on public.inventory_counts
  for insert with check (public.is_admin() or public.has_permission('inventories', 'create'));

create policy inventories_update on public.inventory_counts
  for update using (public.is_admin() or public.has_permission('inventories', 'edit'))
  with check (public.is_admin() or public.has_permission('inventories', 'edit'));

create policy inventories_delete on public.inventory_counts
  for delete using (public.is_admin() or public.has_permission('inventories', 'delete'));

create policy inventory_lines_read on public.inventory_lines
  for select using (
    public.is_admin() or
    exists (
      select 1 from public.inventory_counts i
      where i.id = inventory_lines.inventory_id
      and (public.is_admin() or public.has_permission('inventories', 'view'))
    )
  );

create policy inventory_lines_insert on public.inventory_lines
  for insert with check (
    public.is_admin() or
    exists (
      select 1 from public.inventory_counts i
      where i.id = inventory_lines.inventory_id
      and (public.is_admin() or public.has_permission('inventories', 'create'))
    )
  );

create policy inventory_lines_update on public.inventory_lines
  for update using (
    public.is_admin() or
    exists (
      select 1 from public.inventory_counts i
      where i.id = inventory_lines.inventory_id
      and (public.is_admin() or public.has_permission('inventories', 'edit'))
    )
  );

create policy inventory_lines_delete on public.inventory_lines
  for delete using (
    public.is_admin() or
    exists (
      select 1 from public.inventory_counts i
      where i.id = inventory_lines.inventory_id
      and (public.is_admin() or public.has_permission('inventories', 'edit'))
    )
  );
