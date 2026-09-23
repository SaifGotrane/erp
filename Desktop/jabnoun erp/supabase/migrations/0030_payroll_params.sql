-- =====================================================================
-- 0030_payroll_params.sql
-- Rend configurables les taux et plafonds utilisés pour le calcul de la
-- paie (CNSS, CSS, abattement frais professionnels, déductions
-- familiales), auparavant codés en dur dans PayrollCalculator. Stockés
-- dans company_settings pour être paramétrés une seule fois par
-- l'entreprise depuis l'écran Paramètres.
-- =====================================================================

alter table public.company_settings
  add column if not exists cnss_employee_rate numeric(6,4) not null default 0.0918,
  add column if not exists css_rate numeric(6,4) not null default 0.01,
  add column if not exists professional_expenses_rate numeric(6,4) not null default 0.10,
  add column if not exists professional_expenses_annual_cap numeric(12,3) not null default 2000,
  add column if not exists head_of_household_annual_deduction numeric(12,3) not null default 300,
  add column if not exists child_annual_deduction numeric(12,3) not null default 100,
  add column if not exists max_deductible_children integer not null default 4;
