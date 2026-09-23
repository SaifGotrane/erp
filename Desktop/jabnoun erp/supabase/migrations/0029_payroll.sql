-- =====================================================================
-- 0029_payroll.sql
-- Nouveau module "Fiche de paie" : informations salariales sur
-- l'employé + table des bulletins de paie mensuels (calcul CNSS/IRPP
-- tunisien effectué côté application, stocké ici pour historique et
-- génération PDF).
-- =====================================================================

alter table public.employees
  add column if not exists base_salary numeric(12,3) not null default 0,
  add column if not exists children_count integer not null default 0,
  add column if not exists is_household_head boolean not null default false,
  add column if not exists cnss_number text;

create table if not exists public.payslips (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  period_month date not null, -- toujours le 1er jour du mois concerné
  base_salary numeric(12,3) not null default 0,
  bonuses numeric(12,3) not null default 0,
  transport_allowance numeric(12,3) not null default 0,
  other_allowances numeric(12,3) not null default 0,
  gross_salary numeric(12,3) not null default 0,
  cnss_employee numeric(12,3) not null default 0,
  taxable_base numeric(12,3) not null default 0,
  irpp numeric(12,3) not null default 0,
  css numeric(12,3) not null default 0,
  other_deductions numeric(12,3) not null default 0,
  net_salary numeric(12,3) not null default 0,
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  unique (employee_id, period_month)
);

create index if not exists idx_payslips_employee on public.payslips(employee_id, period_month desc);
create index if not exists idx_payslips_period on public.payslips(period_month desc);

alter table public.payslips enable row level security;

create policy payslips_select on public.payslips
  for select using (public.is_admin() or public.has_permission('payroll', 'view'));
create policy payslips_insert on public.payslips
  for insert with check (public.is_admin() or public.has_permission('payroll', 'create'));
create policy payslips_update on public.payslips
  for update using (public.is_admin() or public.has_permission('payroll', 'edit'))
  with check (public.is_admin() or public.has_permission('payroll', 'edit'));
create policy payslips_delete on public.payslips
  for delete using (public.is_admin() or public.has_permission('payroll', 'delete'));
