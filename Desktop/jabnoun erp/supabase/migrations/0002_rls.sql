-- =====================================================================
-- Jabnoun ERP — Row Level Security
-- Principe : un employé actif peut lire les données de son périmètre ;
-- les écritures nécessitent une permission explicite (module:action) ou
-- le rôle admin. Les fonctions helper sont SECURITY DEFINER pour éviter
-- la récursion RLS sur `employees`/`employee_permissions`.
-- =====================================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees
    where id = auth.uid() and role = 'admin' and active = true
  );
$$;

create or replace function public.is_active_employee()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees where id = auth.uid() and active = true
  );
$$;

create or replace function public.has_permission(p_module text, p_action text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select
    public.is_admin()
    or exists (
      select 1 from public.employee_permissions
      where employee_id = auth.uid()
        and module = p_module
        and action = p_action
        and allowed = true
    );
$$;

-- ---------------------------------------------------------------------
-- Activation RLS
-- ---------------------------------------------------------------------

alter table public.employees enable row level security;
alter table public.employee_permissions enable row level security;
alter table public.depots enable row level security;
alter table public.showrooms enable row level security;
alter table public.article_categories enable row level security;
alter table public.units enable row level security;
alter table public.tax_rates enable row level security;
alter table public.articles enable row level security;
alter table public.suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.stock_levels enable row level security;
alter table public.stock_movements enable row level security;

-- ---------------------------------------------------------------------
-- EMPLOYEES
-- ---------------------------------------------------------------------

create policy employees_select on public.employees
  for select using (public.is_active_employee());

create policy employees_insert on public.employees
  for insert with check (public.is_admin());

-- Un administrateur peut modifier n'importe quel employé.
-- Un employé peut modifier sa propre ligne UNIQUEMENT pour les champs de
-- profil non sensibles : le trigger `employees_guard_privileged_columns`
-- (défini plus bas) empêche toute élévation de privilèges (role, active,
-- affectations, remise) par un non-administrateur.
create policy employees_update on public.employees
  for update using (public.is_admin() or id = auth.uid())
  with check (public.is_admin() or id = auth.uid());

-- Défense en profondeur : bloque la modification des colonnes sensibles
-- par un non-administrateur, même si la policy RLS autorise la ligne.
create or replace function public.employees_guard_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.role is distinct from old.role
     or new.active is distinct from old.active
     or new.depot_id is distinct from old.depot_id
     or new.showroom_id is distinct from old.showroom_id
     or new.max_discount_percent is distinct from old.max_discount_percent
     or new.can_apply_discount is distinct from old.can_apply_discount
     or new.email is distinct from old.email then
    raise exception 'Modification non autorisée : seul un administrateur peut changer le rôle, le statut, les affectations ou les droits de remise.';
  end if;

  return new;
end;
$$;

drop trigger if exists employees_guard_privileged_columns on public.employees;
create trigger employees_guard_privileged_columns
  before update on public.employees
  for each row execute function public.employees_guard_privileged_columns();

-- ---------------------------------------------------------------------
-- EMPLOYEE_PERMISSIONS
-- ---------------------------------------------------------------------

create policy employee_permissions_select on public.employee_permissions
  for select using (public.is_admin() or employee_id = auth.uid());

create policy employee_permissions_write on public.employee_permissions
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- DÉPÔTS / SHOWROOMS (référentiel — lecture large, écriture protégée)
-- ---------------------------------------------------------------------

create policy depots_select on public.depots for select using (public.is_active_employee());
create policy depots_insert on public.depots for insert with check (public.has_permission('depots', 'create'));
create policy depots_update on public.depots for update using (public.has_permission('depots', 'edit')) with check (public.has_permission('depots', 'edit'));

create policy showrooms_select on public.showrooms for select using (public.is_active_employee());
create policy showrooms_insert on public.showrooms for insert with check (public.has_permission('showrooms', 'create'));
create policy showrooms_update on public.showrooms for update using (public.has_permission('showrooms', 'edit')) with check (public.has_permission('showrooms', 'edit'));

-- ---------------------------------------------------------------------
-- CATALOGUE (catégories, unités, TVA, articles)
-- ---------------------------------------------------------------------

create policy article_categories_select on public.article_categories for select using (public.is_active_employee());
create policy article_categories_insert on public.article_categories for insert with check (public.has_permission('categories', 'create'));
create policy article_categories_update on public.article_categories for update using (public.has_permission('categories', 'edit')) with check (public.has_permission('categories', 'edit'));
create policy article_categories_delete on public.article_categories for delete using (public.has_permission('categories', 'delete'));

create policy units_select on public.units for select using (public.is_active_employee());
create policy units_write on public.units for all using (public.is_admin()) with check (public.is_admin());

create policy tax_rates_select on public.tax_rates for select using (public.is_active_employee());
create policy tax_rates_write on public.tax_rates for all using (public.is_admin()) with check (public.is_admin());

create policy articles_select on public.articles for select using (public.is_active_employee());
create policy articles_insert on public.articles for insert with check (public.has_permission('articles', 'create'));
create policy articles_update on public.articles for update using (public.has_permission('articles', 'edit')) with check (public.has_permission('articles', 'edit'));

-- ---------------------------------------------------------------------
-- PARTENAIRES
-- ---------------------------------------------------------------------

create policy suppliers_select on public.suppliers for select using (public.is_active_employee());
create policy suppliers_insert on public.suppliers for insert with check (public.has_permission('suppliers', 'create'));
create policy suppliers_update on public.suppliers for update using (public.has_permission('suppliers', 'edit')) with check (public.has_permission('suppliers', 'edit'));

create policy customers_select on public.customers for select using (public.is_active_employee());
create policy customers_insert on public.customers for insert with check (public.has_permission('customers', 'create'));
create policy customers_update on public.customers for update using (public.has_permission('customers', 'edit')) with check (public.has_permission('customers', 'edit'));

-- ---------------------------------------------------------------------
-- VÉHICULES / CHAUFFEURS
-- ---------------------------------------------------------------------

create policy vehicles_select on public.vehicles for select using (public.is_active_employee());
create policy vehicles_insert on public.vehicles for insert with check (public.has_permission('vehicles', 'create'));
create policy vehicles_update on public.vehicles for update using (public.has_permission('vehicles', 'edit')) with check (public.has_permission('vehicles', 'edit'));

create policy drivers_select on public.drivers for select using (public.is_active_employee());
create policy drivers_insert on public.drivers for insert with check (public.has_permission('drivers', 'create'));
create policy drivers_update on public.drivers for update using (public.has_permission('drivers', 'edit')) with check (public.has_permission('drivers', 'edit'));

-- ---------------------------------------------------------------------
-- STOCK (lecture large ; écriture réservée aux fonctions serveur/RPC
-- des futurs modules achats/ventes/transferts/inventaires/ajustements)
-- ---------------------------------------------------------------------

create policy stock_levels_select on public.stock_levels for select using (public.is_active_employee());
create policy stock_levels_write on public.stock_levels for all using (public.is_admin()) with check (public.is_admin());

create policy stock_movements_select on public.stock_movements for select using (public.is_active_employee());
create policy stock_movements_write on public.stock_movements for all using (public.is_admin()) with check (public.is_admin());
