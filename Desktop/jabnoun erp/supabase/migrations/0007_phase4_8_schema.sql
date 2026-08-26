-- =====================================================================
-- Jabnoun ERP — Phase 4-8 : Ventes, Livraisons, Retours, POS,
-- Paiements, Charges, Ajustements.
-- =====================================================================

-- ---------------------------------------------------------------------
-- VENTES (factures clients)
-- ---------------------------------------------------------------------

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  customer_id uuid not null references public.customers(id),
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  sale_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'partiellement_paye', 'paye', 'annule')),
  payment_method_id uuid references public.payment_methods(id),
  discount_percent numeric(6,2) not null default 0,
  discount_amount numeric(14,3) not null default 0,
  total_ht numeric(14,3) not null default 0,
  total_tva numeric(14,3) not null default 0,
  total_ttc numeric(14,3) not null default 0,
  amount_paid numeric(14,3) not null default 0,
  is_pos boolean not null default false,
  pos_session_id uuid,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint sales_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null) or
    (depot_id is null and showroom_id is null)
  )
);

create index if not exists idx_sales_customer on public.sales(customer_id, sale_date desc);
create index if not exists idx_sales_status on public.sales(status);
create index if not exists idx_sales_pos on public.sales(pos_session_id) where pos_session_id is not null;

create table if not exists public.sale_lines (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null,
  unit_price_ht numeric(14,3) not null,
  tax_rate_percent numeric(5,2) not null default 0,
  discount_percent numeric(6,2) not null default 0,
  line_total_ht numeric(14,3) not null default 0,
  line_total_tva numeric(14,3) not null default 0,
  line_total_ttc numeric(14,3) not null default 0
);

create index if not exists idx_sale_lines_sale on public.sale_lines(sale_id);

-- ---------------------------------------------------------------------
-- BONS DE LIVRAISON
-- ---------------------------------------------------------------------

create table if not exists public.delivery_notes (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  customer_id uuid not null references public.customers(id),
  sale_id uuid references public.sales(id),
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  delivery_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'livre', 'annule')),
  vehicle_id uuid references public.vehicles(id),
  driver_id uuid references public.drivers(id),
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint delivery_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null) or
    (depot_id is null and showroom_id is null)
  )
);

create index if not exists idx_delivery_notes_customer on public.delivery_notes(customer_id, delivery_date desc);

create table if not exists public.delivery_note_lines (
  id uuid primary key default gen_random_uuid(),
  delivery_note_id uuid not null references public.delivery_notes(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null check (quantity > 0)
);

create index if not exists idx_delivery_note_lines on public.delivery_note_lines(delivery_note_id);

-- ---------------------------------------------------------------------
-- RETOURS FOURNISSEURS
-- ---------------------------------------------------------------------

create table if not exists public.supplier_returns (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  purchase_id uuid references public.purchases(id),
  depot_id uuid not null references public.depots(id),
  return_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'annule')),
  total_ht numeric(14,3) not null default 0,
  total_tva numeric(14,3) not null default 0,
  total_ttc numeric(14,3) not null default 0,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz
);

create index if not exists idx_supplier_returns_supplier on public.supplier_returns(supplier_id, return_date desc);

create table if not exists public.supplier_return_lines (
  id uuid primary key default gen_random_uuid(),
  supplier_return_id uuid not null references public.supplier_returns(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price_ht numeric(14,3) not null,
  tax_rate_percent numeric(5,2) not null default 0,
  line_total_ht numeric(14,3) not null default 0,
  line_total_tva numeric(14,3) not null default 0,
  line_total_ttc numeric(14,3) not null default 0
);

create index if not exists idx_supplier_return_lines on public.supplier_return_lines(supplier_return_id);

-- ---------------------------------------------------------------------
-- RETOURS CLIENTS
-- ---------------------------------------------------------------------

create table if not exists public.customer_returns (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  customer_id uuid not null references public.customers(id),
  sale_id uuid references public.sales(id),
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  return_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'annule')),
  total_ht numeric(14,3) not null default 0,
  total_tva numeric(14,3) not null default 0,
  total_ttc numeric(14,3) not null default 0,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint customer_return_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null) or
    (depot_id is null and showroom_id is null)
  )
);

create index if not exists idx_customer_returns_customer on public.customer_returns(customer_id, return_date desc);

create table if not exists public.customer_return_lines (
  id uuid primary key default gen_random_uuid(),
  customer_return_id uuid not null references public.customer_returns(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price_ht numeric(14,3) not null,
  tax_rate_percent numeric(5,2) not null default 0,
  line_total_ht numeric(14,3) not null default 0,
  line_total_tva numeric(14,3) not null default 0,
  line_total_ttc numeric(14,3) not null default 0
);

create index if not exists idx_customer_return_lines on public.customer_return_lines(customer_return_id);

-- ---------------------------------------------------------------------
-- POS — SESSIONS DE CAISSE
-- ---------------------------------------------------------------------

create table if not exists public.pos_sessions (
  id uuid primary key default gen_random_uuid(),
  session_number text not null unique,
  showroom_id uuid references public.showrooms(id),
  employee_id uuid not null references public.employees(id),
  opening_date timestamptz not null default now(),
  closing_date timestamptz,
  status text not null default 'ouverte' check (status in ('ouverte', 'cloturee', 'annulee')),
  opening_cash numeric(14,3) not null default 0,
  closing_cash numeric(14,3),
  expected_cash numeric(14,3),
  cash_difference numeric(14,3),
  total_sales numeric(14,3) not null default 0,
  total_cash_sales numeric(14,3) not null default 0,
  total_card_sales numeric(14,3) not null default 0,
  notes text
);

create index if not exists idx_pos_sessions_employee on public.pos_sessions(employee_id, opening_date desc);
create index if not exists idx_pos_sessions_status on public.pos_sessions(status);

-- ---------------------------------------------------------------------
-- PAIEMENTS
-- ---------------------------------------------------------------------

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  payment_type text not null check (payment_type in ('encaissement', 'decaissement')),
  partner_type text not null check (partner_type in ('customer', 'supplier')),
  partner_id uuid not null,
  sale_id uuid references public.sales(id),
  purchase_id uuid references public.purchases(id),
  pos_session_id uuid references public.pos_sessions(id),
  payment_method_id uuid references public.payment_methods(id),
  amount numeric(14,3) not null,
  payment_date date not null default current_date,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_payments_partner on public.payments(partner_type, partner_id, payment_date desc);
create index if not exists idx_payments_sale on public.payments(sale_id) where sale_id is not null;
create index if not exists idx_payments_purchase on public.payments(purchase_id) where purchase_id is not null;

-- ---------------------------------------------------------------------
-- CHARGES / DÉPENSES
-- ---------------------------------------------------------------------

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  expense_date date not null default current_date,
  category text,
  label text not null,
  amount numeric(14,3) not null,
  payment_method_id uuid references public.payment_methods(id),
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_expenses_date on public.expenses(expense_date desc);

-- ---------------------------------------------------------------------
-- AJUSTEMENTS DE STOCK
-- ---------------------------------------------------------------------

create table if not exists public.stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  adjustment_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'annule')),
  reason text not null,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint adjustment_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null)
  )
);

create index if not exists idx_adjustments_date on public.stock_adjustments(adjustment_date desc);

create table if not exists public.stock_adjustment_lines (
  id uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null references public.stock_adjustments(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  current_quantity numeric(14,3) not null default 0,
  new_quantity numeric(14,3) not null default 0,
  delta numeric(14,3) not null default 0
);

create index if not exists idx_adjustment_lines on public.stock_adjustment_lines(adjustment_id);
