-- =====================================================================
-- Jabnoun ERP — Phase 3 : Achats, Transferts, Inventaires, Audit,
-- Numérotation, Paramètres, Méthodes de paiement.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PARAMÈTRES ENTREPRISE (singleton)
-- ---------------------------------------------------------------------

create table if not exists public.company_settings (
  id uuid primary key default gen_random_uuid(),
  company_name text not null default 'Jabnoun',
  logo_url text,
  address text,
  phone text,
  email text,
  tax_id text,
  currency text not null default 'TND',
  allow_negative_stock boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.company_settings (company_name)
select 'Jabnoun'
where not exists (select 1 from public.company_settings);

-- ---------------------------------------------------------------------
-- MÉTHODES DE PAIEMENT CONFIGURABLES
-- ---------------------------------------------------------------------

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  sort_order integer not null default 0
);

insert into public.payment_methods (name, sort_order) values
  ('Espèces', 1), ('Carte bancaire', 2), ('Virement', 3), ('Chèque', 4), ('Autre', 5)
on conflict (name) do nothing;

-- ---------------------------------------------------------------------
-- NUMÉROTATION AUTOMATIQUE DES DOCUMENTS
-- ---------------------------------------------------------------------

create table if not exists public.document_sequences (
  prefix text not null,
  year integer not null,
  last_number integer not null default 0,
  primary key (prefix, year)
);

-- ---------------------------------------------------------------------
-- JOURNAL D'AUDIT
-- ---------------------------------------------------------------------

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid references public.employees(id),
  action text not null,
  module text not null,
  object_type text,
  object_id uuid,
  object_label text,
  old_value jsonb,
  new_value jsonb,
  ip_address text,
  details text
);

create index if not exists idx_audit_logs_created on public.audit_logs(created_at desc);
create index if not exists idx_audit_logs_user on public.audit_logs(user_id, created_at desc);
create index if not exists idx_audit_logs_module on public.audit_logs(module, created_at desc);

-- ---------------------------------------------------------------------
-- ACHATS
-- ---------------------------------------------------------------------

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  depot_id uuid not null references public.depots(id),
  purchase_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'partiellement_paye', 'paye', 'annule')),
  payment_method_id uuid references public.payment_methods(id),
  supplier_document_ref text,
  discount_percent numeric(6,2) not null default 0,
  discount_amount numeric(14,3) not null default 0,
  total_ht numeric(14,3) not null default 0,
  total_tva numeric(14,3) not null default 0,
  total_ttc numeric(14,3) not null default 0,
  amount_paid numeric(14,3) not null default 0,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz
);

create index if not exists idx_purchases_supplier on public.purchases(supplier_id, purchase_date desc);
create index if not exists idx_purchases_depot on public.purchases(depot_id, purchase_date desc);
create index if not exists idx_purchases_status on public.purchases(status);

create table if not exists public.purchase_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null,
  unit_price_ht numeric(14,3) not null,
  tax_rate_percent numeric(5,2) not null default 0,
  discount_percent numeric(6,2) not null default 0,
  line_total_ht numeric(14,3) not null default 0,
  line_total_tva numeric(14,3) not null default 0,
  line_total_ttc numeric(14,3) not null default 0
);

create index if not exists idx_purchase_lines_purchase on public.purchase_lines(purchase_id);

-- ---------------------------------------------------------------------
-- TRANSFERTS / BONS DE SORTIE
-- ---------------------------------------------------------------------

create table if not exists public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  source_depot_id uuid references public.depots(id),
  source_showroom_id uuid references public.showrooms(id),
  destination_depot_id uuid references public.depots(id),
  destination_showroom_id uuid references public.showrooms(id),
  transfer_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'annule')),
  vehicle_id uuid references public.vehicles(id),
  driver_id uuid references public.drivers(id),
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint transfers_source_check check (
    (source_depot_id is not null and source_showroom_id is null) or
    (source_depot_id is null and source_showroom_id is not null)
  ),
  constraint transfers_destination_check check (
    (destination_depot_id is not null and destination_showroom_id is null) or
    (destination_depot_id is null and destination_showroom_id is not null)
  ),
  constraint transfers_not_same check (
    source_depot_id is distinct from destination_depot_id and
    source_showroom_id is distinct from destination_showroom_id
  )
);

create index if not exists idx_transfers_date on public.stock_transfers(transfer_date desc);

create table if not exists public.stock_transfer_lines (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.stock_transfers(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  quantity numeric(14,3) not null check (quantity > 0)
);

create index if not exists idx_transfer_lines_transfer on public.stock_transfer_lines(transfer_id);

-- ---------------------------------------------------------------------
-- INVENTAIRES
-- ---------------------------------------------------------------------

create table if not exists public.inventory_counts (
  id uuid primary key default gen_random_uuid(),
  document_number text not null unique,
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  inventory_date date not null default current_date,
  status text not null default 'brouillon' check (status in ('brouillon', 'valide', 'annule')),
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  validated_by uuid references public.employees(id),
  validated_at timestamptz,
  constraint inventory_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null)
  )
);

create index if not exists idx_inventories_date on public.inventory_counts(inventory_date desc);

create table if not exists public.inventory_lines (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.inventory_counts(id) on delete cascade,
  article_id uuid not null references public.articles(id),
  theoretical_quantity numeric(14,3) not null default 0,
  real_quantity numeric(14,3) not null default 0,
  gap numeric(14,3) not null default 0
);

create index if not exists idx_inventory_lines_inventory on public.inventory_lines(inventory_id);
