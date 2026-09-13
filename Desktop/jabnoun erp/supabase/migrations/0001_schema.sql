-- =====================================================================
-- Jabnoun ERP — Schéma initial (Phase 1 & 2)
-- Employés, permissions, dépôts, showrooms, catalogue articles,
-- fournisseurs, clients, véhicules, chauffeurs, stock.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- EMPLOYÉS & PERMISSIONS
-- ---------------------------------------------------------------------

create table if not exists public.employees (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  phone text,
  role text not null default 'employee' check (role in ('admin', 'employee')),
  active boolean not null default true,
  depot_id uuid,
  showroom_id uuid,
  max_discount_percent numeric(5,2),
  can_apply_discount boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.employee_permissions (
  employee_id uuid not null references public.employees(id) on delete cascade,
  module text not null,
  action text not null,
  allowed boolean not null default false,
  primary key (employee_id, module, action)
);

-- ---------------------------------------------------------------------
-- DÉPÔTS & SHOWROOMS
-- ---------------------------------------------------------------------

create table if not exists public.depots (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  address text,
  phone text,
  responsible_employee_id uuid references public.employees(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.showrooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  address text,
  phone text,
  responsible_employee_id uuid references public.employees(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.employees
  add constraint employees_depot_fk foreign key (depot_id) references public.depots(id),
  add constraint employees_showroom_fk foreign key (showroom_id) references public.showrooms(id);

-- ---------------------------------------------------------------------
-- CATALOGUE ARTICLES
-- ---------------------------------------------------------------------

create table if not exists public.article_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  symbol text not null
);

create table if not exists public.tax_rates (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  rate_percent numeric(5,2) not null,
  active boolean not null default true,
  is_default boolean not null default false
);

-- Garantit qu'un seul taux de TVA est marqué par défaut.
create unique index if not exists tax_rates_single_default
  on public.tax_rates ((is_default)) where is_default;

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  designation text not null,
  category_id uuid references public.article_categories(id),
  unit_id uuid references public.units(id),
  description text,
  barcode text,
  min_stock numeric(14,3) not null default 0,
  purchase_price_ht numeric(14,3) not null default 0,
  tax_rate_id uuid references public.tax_rates(id),
  tax_rate_percent numeric(5,2) not null default 0,
  margin_percent numeric(6,2) not null default 0,
  selling_price_ht numeric(14,3) not null default 0,
  selling_price_ttc numeric(14,3) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_articles_designation on public.articles using gin (to_tsvector('simple', designation));

-- ---------------------------------------------------------------------
-- FOURNISSEURS & CLIENTS
-- ---------------------------------------------------------------------

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  company_name text,
  contact_person text,
  phone text,
  email text,
  address text,
  tax_id text,
  payment_terms_days integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  company_name text,
  contact_person text,
  phone text,
  email text,
  address text,
  tax_id text,
  payment_terms_days integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- VÉHICULES & CHAUFFEURS
-- ---------------------------------------------------------------------

create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  license_number text,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

-- La relation véhicule <-> chauffeur est portée uniquement par
-- `vehicles.driver_id` (source de vérité unique). Le véhicule affecté à un
-- chauffeur se déduit via cette clé étrangère.
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  vehicle_type text,
  brand text,
  model text,
  capacity numeric(12,2),
  driver_id uuid references public.drivers(id),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- STOCK
-- ---------------------------------------------------------------------

-- Stock courant par article et par emplacement (dépôt OU showroom).
create table if not exists public.stock_levels (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  depot_id uuid references public.depots(id),
  showroom_id uuid references public.showrooms(id),
  quantity numeric(14,3) not null default 0,
  updated_at timestamptz not null default now(),
  constraint stock_levels_one_location check (
    (depot_id is not null and showroom_id is null) or
    (depot_id is null and showroom_id is not null)
  )
);

-- Unicité réelle par emplacement. Une contrainte UNIQUE classique sur
-- (article_id, depot_id, showroom_id) est inefficace car l'une des colonnes
-- est toujours NULL (NULLS DISTINCT par défaut). On utilise donc deux index
-- partiels, un par type d'emplacement.
create unique index if not exists stock_levels_depot_uq
  on public.stock_levels(article_id, depot_id) where depot_id is not null;
create unique index if not exists stock_levels_showroom_uq
  on public.stock_levels(article_id, showroom_id) where showroom_id is not null;

-- Historique complet des mouvements de stock (traçabilité §10).
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id),
  movement_type text not null check (movement_type in (
    'entree', 'sortie', 'transfert', 'vente',
    'retour_fournisseur', 'retour_client', 'ajustement', 'inventaire'
  )),
  quantity numeric(14,3) not null,
  source_depot_id uuid references public.depots(id),
  source_showroom_id uuid references public.showrooms(id),
  destination_depot_id uuid references public.depots(id),
  destination_showroom_id uuid references public.showrooms(id),
  source_label text,
  destination_label text,
  document_type text,
  document_id uuid,
  document_number text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_article on public.stock_movements(article_id, created_at desc);

-- ---------------------------------------------------------------------
-- DONNÉES DE RÉFÉRENCE PAR DÉFAUT
-- ---------------------------------------------------------------------

insert into public.units (name, symbol) values
  ('Pièce', 'pc'), ('Kilogramme', 'kg'), ('Litre', 'L'), ('Mètre', 'm')
on conflict (name) do nothing;

insert into public.tax_rates (label, rate_percent, is_default) values
  ('TVA 19%', 19, true),
  ('TVA 13%', 13, false),
  ('TVA 7%', 7, false),
  ('Exonéré', 0, false)
on conflict do nothing;
