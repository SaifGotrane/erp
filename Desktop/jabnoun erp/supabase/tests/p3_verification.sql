-- P3 verification aid. Run in Supabase SQL Editor after replacing the UUID.
-- Every session that changes role/data is rolled back: it cannot persist data.

-- Inspect the exact policies installed by migrations 0010/0011.
select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'sales', 'sale_lines', 'purchases', 'purchase_lines',
    'stock_transfers', 'stock_transfer_lines', 'inventory_counts',
    'inventory_lines', 'stock_adjustments', 'stock_adjustment_lines',
    'delivery_notes', 'delivery_note_lines', 'supplier_returns',
    'supplier_return_lines', 'customer_returns', 'customer_return_lines'
  )
order by tablename, policyname;

-- Replace with the UUID of an active, non-admin integration-test employee.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '<TEST_USER_UUID>', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Confirms the authenticated test identity and assigned permissions.
select auth.uid() as test_user_id, public.is_active_employee() as active_employee;
select module, action, allowed
from public.employee_permissions
where employee_id = auth.uid()
order by module, action;

-- Report RPCs: execute both an empty date range and the full range. These
-- calls are read-only and must not return the old ambiguous total_ttc error.
select * from public.report_sales_summary(current_date + 1, current_date + 1);
select * from public.report_purchases_summary(current_date + 1, current_date + 1);
select * from public.report_sales_summary(null, null);
select * from public.report_purchases_summary(null, null);
select * from public.report_sales_margin(current_date + 1, current_date + 1);

-- Historical-cost inspection: old validated lines must remain NULL rather than
-- being assigned a fabricated margin; newly validated sales must have both
-- fields populated from their location CMUP.
select s.document_number, sl.id, sl.quantity, sl.unit_cost_ht, sl.total_cost_ht
from public.sales s join public.sale_lines sl on sl.sale_id = s.id
where s.status in ('valide', 'partiellement_paye', 'paye')
order by s.sale_date desc, s.document_number desc
limit 50;

-- Inspect validation/cancellation function definitions before workflow runs.
select p.proname, pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('validate_sale', 'cancel_sale', 'validate_purchase',
                    'cancel_purchase', 'validate_transfer', 'cancel_transfer');

rollback;

-- RLS workflow procedure (run from the authenticated Flutter test client):
-- 1. Create a draft + line using isolated fixture customer/supplier/depot/article.
-- 2. Update and delete draft records with granted permissions (must succeed).
-- 3. Validate through the relevant RPC.
-- 4. Attempt direct UPDATE/DELETE on the validated header and line (must fail).
-- 5. Cancel through its SECURITY DEFINER RPC and compare stock_levels before/after.
-- 6. Validate a purchase at cost A, then a sale: the sale line must snapshot A.
-- 7. Validate a later purchase at cost B: the earlier sale snapshot must stay A.
-- 8. Validate a transfer and confirm its source CMUP is merged at destination.
-- Use a transaction and ROLLBACK for ad hoc SQL mutations; do not use production documents.
