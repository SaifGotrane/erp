-- =====================================================================
-- Jabnoun ERP — Phase 4-8 : RLS policies
-- =====================================================================

-- VENTES
alter table public.sales enable row level security;
alter table public.sale_lines enable row level security;

create policy sales_read on public.sales
  for select using (public.is_admin() or public.has_permission('sales', 'view'));
create policy sales_write on public.sales
  for all using (public.is_admin() or public.has_permission('sales', 'create') or public.has_permission('sales', 'edit'))
  with check (public.is_admin() or public.has_permission('sales', 'create') or public.has_permission('sales', 'edit'));

create policy sale_lines_read on public.sale_lines
  for select using (public.is_admin() or public.has_permission('sales', 'view'));
create policy sale_lines_write on public.sale_lines
  for all using (public.is_admin() or public.has_permission('sales', 'create') or public.has_permission('sales', 'edit'))
  with check (public.is_admin() or public.has_permission('sales', 'create') or public.has_permission('sales', 'edit'));

-- BONS DE LIVRAISON
alter table public.delivery_notes enable row level security;
alter table public.delivery_note_lines enable row level security;

create policy delivery_read on public.delivery_notes
  for select using (public.is_admin() or public.has_permission('delivery_notes', 'view'));
create policy delivery_write on public.delivery_notes
  for all using (public.is_admin() or public.has_permission('delivery_notes', 'create') or public.has_permission('delivery_notes', 'edit'))
  with check (public.is_admin() or public.has_permission('delivery_notes', 'create') or public.has_permission('delivery_notes', 'edit'));

create policy delivery_lines_read on public.delivery_note_lines
  for select using (public.is_admin() or public.has_permission('delivery_notes', 'view'));
create policy delivery_lines_write on public.delivery_note_lines
  for all using (public.is_admin() or public.has_permission('delivery_notes', 'create') or public.has_permission('delivery_notes', 'edit'))
  with check (public.is_admin() or public.has_permission('delivery_notes', 'create') or public.has_permission('delivery_notes', 'edit'));

-- RETOURS FOURNISSEURS
alter table public.supplier_returns enable row level security;
alter table public.supplier_return_lines enable row level security;

create policy supplier_returns_read on public.supplier_returns
  for select using (public.is_admin() or public.has_permission('supplier_returns', 'view'));
create policy supplier_returns_write on public.supplier_returns
  for all using (public.is_admin() or public.has_permission('supplier_returns', 'create') or public.has_permission('supplier_returns', 'edit'))
  with check (public.is_admin() or public.has_permission('supplier_returns', 'create') or public.has_permission('supplier_returns', 'edit'));

create policy supplier_return_lines_read on public.supplier_return_lines
  for select using (public.is_admin() or public.has_permission('supplier_returns', 'view'));
create policy supplier_return_lines_write on public.supplier_return_lines
  for all using (public.is_admin() or public.has_permission('supplier_returns', 'create') or public.has_permission('supplier_returns', 'edit'))
  with check (public.is_admin() or public.has_permission('supplier_returns', 'create') or public.has_permission('supplier_returns', 'edit'));

-- RETOURS CLIENTS
alter table public.customer_returns enable row level security;
alter table public.customer_return_lines enable row level security;

create policy customer_returns_read on public.customer_returns
  for select using (public.is_admin() or public.has_permission('customer_returns', 'view'));
create policy customer_returns_write on public.customer_returns
  for all using (public.is_admin() or public.has_permission('customer_returns', 'create') or public.has_permission('customer_returns', 'edit'))
  with check (public.is_admin() or public.has_permission('customer_returns', 'create') or public.has_permission('customer_returns', 'edit'));

create policy customer_return_lines_read on public.customer_return_lines
  for select using (public.is_admin() or public.has_permission('customer_returns', 'view'));
create policy customer_return_lines_write on public.customer_return_lines
  for all using (public.is_admin() or public.has_permission('customer_returns', 'create') or public.has_permission('customer_returns', 'edit'))
  with check (public.is_admin() or public.has_permission('customer_returns', 'create') or public.has_permission('customer_returns', 'edit'));

-- POS SESSIONS
alter table public.pos_sessions enable row level security;

create policy pos_sessions_read on public.pos_sessions
  for select using (public.is_admin() or public.has_permission('pos', 'view'));
create policy pos_sessions_write on public.pos_sessions
  for all using (public.is_admin() or public.has_permission('pos', 'create') or public.has_permission('pos', 'edit'))
  with check (public.is_admin() or public.has_permission('pos', 'create') or public.has_permission('pos', 'edit'));

-- PAIEMENTS
alter table public.payments enable row level security;

create policy payments_read on public.payments
  for select using (public.is_admin() or public.has_permission('payments', 'view'));
create policy payments_write on public.payments
  for all using (public.is_admin() or public.has_permission('payments', 'create') or public.has_permission('payments', 'edit'))
  with check (public.is_admin() or public.has_permission('payments', 'create') or public.has_permission('payments', 'edit'));

-- CHARGES
alter table public.expenses enable row level security;

create policy expenses_read on public.expenses
  for select using (public.is_admin() or public.has_permission('expenses', 'view'));
create policy expenses_write on public.expenses
  for all using (public.is_admin() or public.has_permission('expenses', 'create') or public.has_permission('expenses', 'edit'))
  with check (public.is_admin() or public.has_permission('expenses', 'create') or public.has_permission('expenses', 'edit'));

-- AJUSTEMENTS
alter table public.stock_adjustments enable row level security;
alter table public.stock_adjustment_lines enable row level security;

create policy adjustments_read on public.stock_adjustments
  for select using (public.is_admin() or public.has_permission('adjustments', 'view'));
create policy adjustments_write on public.stock_adjustments
  for all using (public.is_admin() or public.has_permission('adjustments', 'create') or public.has_permission('adjustments', 'edit'))
  with check (public.is_admin() or public.has_permission('adjustments', 'create') or public.has_permission('adjustments', 'edit'));

create policy adjustment_lines_read on public.stock_adjustment_lines
  for select using (public.is_admin() or public.has_permission('adjustments', 'view'));
create policy adjustment_lines_write on public.stock_adjustment_lines
  for all using (public.is_admin() or public.has_permission('adjustments', 'create') or public.has_permission('adjustments', 'edit'))
  with check (public.is_admin() or public.has_permission('adjustments', 'create') or public.has_permission('adjustments', 'edit'));
