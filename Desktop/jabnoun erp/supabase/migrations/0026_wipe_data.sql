-- =====================================================================
-- WIPE ALL DATA — keep only the admin employee (admin@jabnoun.com)
-- Run this in Supabase SQL Editor. Irreversible!
-- =====================================================================

BEGIN;

-- 1. Truncate all transactional / business tables (CASCADE handles FKs)
TRUNCATE TABLE
  public.sale_sub_invoice_lines,
  public.sale_sub_invoices,
  public.sale_lines,
  public.sales,
  public.delivery_note_lines,
  public.delivery_notes,
  public.supplier_return_lines,
  public.supplier_returns,
  public.customer_return_lines,
  public.customer_returns,
  public.purchase_lines,
  public.purchases,
  public.stock_adjustment_lines,
  public.stock_adjustments,
  public.stock_transfer_lines,
  public.stock_transfers,
  public.stock_movements,
  public.stock_levels,
  public.inventory_lines,
  public.inventories,
  public.payments,
  public.expenses,
  public.pos_sessions,
  public.bills_of_exchange,
  public.supplier_settlements,
  public.sav_ticket_notes,
  public.sav_tickets,
  public.sub_clients,
  public.audit_logs,
  public.articles,
  public.article_categories,
  public.units,
  public.tax_rates,
  public.customers,
  public.suppliers,
  public.vehicles,
  public.drivers,
  public.depots,
  public.showrooms,
  public.payment_methods,
  public.company_settings
CASCADE;

-- 2. Keep only the admin employee's permissions
DELETE FROM public.employee_permissions
WHERE employee_id NOT IN (
  SELECT id FROM public.employees WHERE email = 'admin@jabnoun.com'
);

-- 3. Delete all non-admin employees
DELETE FROM public.employees
WHERE email <> 'admin@jabnoun.com';

-- 4. Ensure the admin has the correct credentials
UPDATE public.employees
SET role = 'admin', active = true
WHERE email = 'admin@jabnoun.com';

-- 5. Reset the admin password in auth.users
UPDATE auth.users
SET encrypted_password = crypt('admin123', gen_salt('bf')),
    email = 'admin@jabnoun.com',
    raw_user_meta_data = jsonb_set(
      coalesce(raw_user_meta_data, '{}'::jsonb),
      '{role}', '"admin"'
    )
WHERE id = (SELECT id FROM public.employees WHERE email = 'admin@jabnoun.com');

COMMIT;
