# JABNOUN ERP — PRE-PRODUCTION READINESS AUDIT REPORT

**Date:** 2025-01-20  
**Auditor:** Cascade (AI Senior Architect + QA + Security + Performance + PostgreSQL Engineer)  
**Scope:** Full static audit of Flutter frontend, Supabase backend, PostgreSQL schema, migrations, edge functions, and infrastructure.  
**Methodology:** Read-only inspection of all source files. No code or data was modified.

---

## 1. SYSTEM MAP

### 1.1 Technology Stack

| Layer | Technology | Version/Status |
|-------|-----------|----------------|
| Frontend | Flutter (Dart) | Desktop (Windows) + Web |
| State Management | Riverpod (flutter_riverpod) | Latest |
| Routing | go_router | Latest |
| Backend | Supabase (PostgreSQL + Auth + Edge Functions) | Cloud |
| Database | PostgreSQL (via Supabase) | 15+ |
| PDF Generation | pdf + printing + file_saver | Latest |
| Environment | flutter_dotenv | Latest |

### 1.2 Architecture Overview

```
┌─────────────────────────────────────────────┐
│  Flutter App (Desktop/Web)                   │
│  ├── lib/main.dart (entry point)             │
│  ├── lib/core/ (config, constants, errors)   │
│  ├── lib/routes/ (GoRouter + nav)             │
│  ├── lib/providers/ (Riverpod providers)      │
│  ├── lib/repositories/ (Supabase data access) │
│  ├── lib/models/ (data models)               │
│  ├── lib/services/ (PDF generation)          │
│  ├── lib/screens/ (UI screens)               │
│  └── lib/widgets/ (reusable widgets)         │
├─────────────────────────────────────────────┤
│  Supabase Backend                             │
│  ├── Auth (email/password)                   │
│  ├── PostgreSQL (21 migrations)              │
│  ├── RLS policies (all tables)               │
│  ├── SECURITY DEFINER RPC functions           │
│  ├── Edge Functions (create-employee,        │
│  │                  reset-employee-password)  │
│  └── Storage (not used)                       │
└─────────────────────────────────────────────┘
```

### 1.3 Database Schema Summary

**Core tables (migration 0001):** `employees`, `employee_permissions`, `company_settings`, `depots`, `showrooms`, `article_categories`, `article_units`, `tax_rates`, `articles`, `suppliers`, `customers`, `vehicles`, `drivers`, `stock_levels`, `stock_movements`, `document_sequences`, `audit_logs`

**Phase 4-8 tables (migration 0007):** `purchases`, `purchase_lines`, `sales`, `sale_lines`, `delivery_notes`, `delivery_note_lines`, `supplier_returns`, `supplier_return_lines`, `customer_returns`, `customer_return_lines`, `pos_sessions`, `payments`, `payment_methods`, `expenses`, `stock_adjustments`, `stock_adjustment_lines`, `stock_transfers`, `stock_transfer_lines`, `inventory_counts`, `inventory_lines`

**Extended tables (migrations 0015-0019):** `sale_sub_invoices`, `sav_tickets`, `sav_ticket_notes`, `supplier_settlements`, `bills_of_exchange`

### 1.4 Migration Inventory (21 migrations)

| # | File | Purpose |
|---|------|---------|
| 0001 | `0001_schema.sql` | Core schema |
| 0002 | `0002_rls.sql` | RLS + security definer helpers |
| 0003 | `0003_functions.sql` | Dashboard + partner statement (placeholders) |
| 0004 | `0004_phase3_schema.sql` | Purchases, transfers, inventories, payment methods |
| 0005 | `0005_phase3_rls.sql` | RLS for phase 3 tables |
| 0006 | `0006_phase3_functions.sql` | validate_purchase, validate_transfer, validate_inventory, document numbering, audit log |
| 0007 | `0007_phase4_8_schema.sql` | Sales, delivery, returns, POS, payments, expenses, adjustments |
| 0008 | `0008_phase4_8_rls.sql` | RLS for phase 4-8 tables |
| 0009 | `0009_phase4_8_functions.sql` | All phase 4-8 RPC functions |
| 0010 | `0010_document_immutability_rls.sql` | Draft-only mutability for documents |
| 0011 | `0011_fix_report_summary_ambiguity.sql` | Fix report ambiguity |
| 0012 | `0012_historical_sales_costing.sql` | CMUP costing, validate_sale with cost, validate_purchase with cost, validate_transfer with cost, report_sales_margin |
| 0013 | `0013_fix_stock_valuation_cmup.sql` | Fix stock valuation report |
| 0014 | `0014_fix_margin_report_and_category_delete.sql` | Fix margin report, category delete policy |
| 0015 | `0015_governorates_and_invoice_extras.sql` | Governorates, stamp duty, customer_display_name, validate_sale override |
| 0016 | `0016_sub_invoices.sql` | Sub-invoices table + functions |
| 0017 | `0017_sav.sql` | SAV tickets |
| 0018 | `0018_bills_of_exchange.sql` | Bills of exchange |
| 0019 | `0019_bills_of_exchange_fixes.sql` | Bills fixes (snapshots, double-settlement prevention, payment sync) |
| 0020 | `0020_app_wide_integrity_fixes.sql` | Remove direct write on pos_sessions, payments, sav_tickets |
| 0021 | `0021_fix_cmup_fallback.sql` | CMUP fallback to purchase_price_ht |

---

## 2. BUSINESS PROCESS MAP

### 2.1 Sales Workflow
1. **Actor:** Employee with `sales:create` permission
2. **Create draft:** `SaleRepository.createDraft()` → inserts `sales` (status='brouillon') + `sale_lines` via client-side Supabase calls
3. **Edit draft:** `SaleRepository.updateDraft()` / `replaceLines()` → direct table updates (RLS allows only brouillon)
4. **Validate:** `SaleRepository.validate()` → RPC `validate_sale()` → recalculates totals server-side, applies discount, adds stamp duty (1 DT), checks CMUP cost, decrements stock via `upsert_stock_level()`, records stock movements, sets status='valide'
5. **Payment:** `PaymentRepository.recordPayment()` → RPC `record_payment()` → inserts payment, updates sale `amount_paid` and status ('partiellement_paye' or 'paye')
6. **Cancel:** `SaleRepository.cancel()` → RPC `cancel_sale()` → restores stock if status was 'valide' or 'partiellement_paye', sets status='annule'
7. **Delete:** `SaleRepository.delete()` → direct delete (RLS allows only brouillon)
8. **Sub-invoices:** `add_sale_sub_invoice()` / `delete_sale_sub_invoice()` → split invoice across sub-clients, sum cannot exceed total_ttc

### 2.2 Purchase Workflow
1. **Create draft:** `PurchaseRepository.createDraft()` → inserts purchase + lines
2. **Validate:** RPC `validate_purchase()` → recalculates totals, applies discount, increments stock via `upsert_stock_level()` with effective HT cost (line discount + document discount), records stock movements
3. **Payment:** `record_payment()` → updates purchase `amount_paid` and status
4. **Cancel:** RPC `cancel_purchase()` → restores stock, sets status='annule'

### 2.3 Delivery Note Workflow
1. **Create draft:** `DeliveryNoteRepository.createDraft()` → inserts delivery note + lines
2. **Validate:** RPC `validate_delivery()` → decrements stock, records movements, sets status='livre'
3. **Cancel:** RPC `cancel_delivery()` → restores stock, sets status='annule'

### 2.4 Stock Transfer Workflow
1. **Create draft:** Transfer repository → inserts transfer + lines
2. **Validate:** RPC `validate_transfer()` → checks source CMUP, decrements source stock, increments destination stock with source CMUP cost, records movement
3. **Cancel:** Restores stock in reverse

### 2.5 Supplier Return Workflow
1. **Create draft:** `SupplierReturnRepository.createDraft()` → inserts return + lines
2. **Validate:** RPC `validate_supplier_return()` → recalculates totals, decrements stock, records movements
3. **Cancel:** RPC `cancel_supplier_return()` → restores stock

### 2.6 Customer Return Workflow
1. **Create draft:** `CustomerReturnRepository.createDraft()` → inserts return + lines
2. **Validate:** RPC `validate_customer_return()` → recalculates totals, increments stock, records movements
3. **Cancel:** RPC `cancel_customer_return()` → decrements stock

### 2.7 POS Session Workflow
1. **Open:** RPC `open_pos_session()` → checks no existing open session, creates session with opening cash
2. **Close:** RPC `close_pos_session()` → calculates expected cash (opening + cash sales), computes difference, sets status='cloturee'

### 2.8 Stock Adjustment Workflow
1. **Create draft:** `AdjustmentRepository.createDraft()` → inserts adjustment + lines with current/new quantities
2. **Validate:** RPC `validate_adjustment()` → applies delta via `upsert_stock_level()`, records movements
3. **Cancel:** RPC `cancel_adjustment()` → reverses delta

### 2.9 Bills of Exchange Workflow
1. **Create settlement:** RPC `create_supplier_settlement()` → validates purchase not already settled, validates sum equals purchase total_ttc, creates settlement + bills with supplier snapshot
2. **Mark paid:** RPC `mark_bill_paid()` → updates bill status, syncs purchase amount_paid/status
3. **Cancel bill:** RPC `cancel_bill()` → sets status='annulee' (cannot cancel paid bills)

### 2.10 SAV Ticket Workflow
1. **Create:** Direct insert (RLS: `sav:create`)
2. **Edit:** Direct update (RLS: `sav:edit`, blocked if status is 'resolu' or 'termine')
3. **Resolve:** RPC `resolve_sav_ticket()` (requires `sav:resolve` permission)
4. **Close:** RPC `close_sav_ticket()`

---

## 3. TOP RISKS (Ordered by Severity)

### 🔴 CRITICAL

#### R1. `cancel_sale` does not reverse `amount_paid` for partially paid sales
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:100-156`

The `cancel_sale` function allows cancellation of `partiellement_paye` sales (line 127) and restores stock (lines 128-142), but it does NOT reset `amount_paid` to 0. After cancellation, the sale has `status='annule'` but `amount_paid` still holds the partial payment amount. The linked `payments` records remain in place.

**Impact:** Financial inconsistency — a customer's payment is recorded but the sale is cancelled. The partner statement report (`report_partner_statement`) filters by `status in ('valide', 'partiellement_paye', 'paye')`, so the cancelled sale won't appear, but the payment remains in the `payments` table, creating an orphaned payment.

**Severity:** CRITICAL — financial data corruption.

#### R2. `record_payment` does not validate amount > 0 or amount ≤ remaining balance
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:617-693`

The `record_payment` RPC accepts any `p_amount` value. There is no server-side check that:
- `p_amount > 0` (negative payments would reduce `amount_paid`)
- `p_amount <= total_ttc - amount_paid` (overpayment is possible)

The client-side dialog (`@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\screens\finance\payment_dialog.dart:71-78`) validates these constraints, but a direct API call (e.g., via curl or Postman with the anon key) bypasses this check.

**Impact:** An attacker or misconfigured client could record negative payments, reducing the `amount_paid` on a sale, or overpay beyond `total_ttc`.

**Severity:** CRITICAL — financial integrity bypass.

#### R3. No test coverage beyond a single smoke test
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\test\widget_test.dart:1-16`

The only test verifies that `AppTheme.light` builds. There are:
- 0 unit tests for repositories (data access layer)
- 0 unit tests for models (serialization/deserialization)
- 0 unit tests for RPC function logic
- 0 widget tests for screens
- 0 integration tests
- 0 tests for financial calculations (CMUP, discounts, stamp duty, tax)

**Impact:** Any regression in financial logic, permissions, or data handling would go undetected. The CMUP calculation, discount proration, and payment status transitions are complex and error-prone.

**Severity:** CRITICAL — no safety net for production deployments.

### 🟠 HIGH

#### R4. `validate_sale` function overridden 4 times across migrations
**Evidence:** 
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:16-93` (original)
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0012_historical_sales_costing.sql:48-78` (CMUP costing)
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0015_governorates_and_invoice_extras.sql:35-67` (stamp duty)
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0021_fix_cmup_fallback.sql:50-87` (CMUP fallback)

Each migration uses `CREATE OR REPLACE FUNCTION`, meaning the last applied migration wins. If any migration in the sequence fails to apply, the function definition could be inconsistent. The 0009 version lacks stamp duty and CMUP costing. The 0012 version lacks stamp duty. Only the 0021 version has all features.

**Impact:** Migration ordering is critical. A failed migration could leave the database with a stale function version that lacks essential business logic.

**Severity:** HIGH — deployment risk.

#### R5. `upsert_stock_level` function overridden 3 times
**Evidence:**
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0006_phase3_functions.sql:40-63` (original, no cost tracking)
- `@/c:\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0012_historical_sales_costing.sql:16-46` (CMUP costing)
- `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0021_fix_cmup_fallback.sql:12-47` (CMUP fallback to purchase_price_ht)

Same risk as R4. The 0006 version has no cost tracking at all. If migration 0012 or 0021 fails, stock operations would work but costing would be broken.

**Severity:** HIGH — deployment risk.

#### R6. N+1 query in `PaymentRepository.fetchAll`
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\repositories\phase4_8_repositories.dart:728-744`

For each payment in the list, the code makes a separate query to `customers` or `suppliers` to fetch the partner name:
```dart
for (final row in list) {
  if (row['partner_type'] == 'customer') {
    final c = await client.from('customers').select('name').eq('id', row['partner_id'] as String).maybeSingle();
    row['partner_name'] = c?['name'];
  } else {
    final s = await client.from('suppliers').select('name').eq('id', row['partner_id'] as String).maybeSingle();
    row['partner_name'] = s?['name'];
  }
  result.add(Payment.fromMap(row));
}
```

With 50 payments per page, this generates up to 50 additional Supabase API calls.

**Impact:** Slow payment list loading, especially on high-latency connections. Each API call adds ~100-300ms.

**Severity:** HIGH — performance degradation under load.

#### R7. `cancel_supplier_return` and `cancel_customer_return` lack permission checks
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:341-378` and `455-493`

`cancel_supplier_return` checks `is_active_employee()` but does NOT check `has_permission('supplier_returns', 'cancel')`. Any active employee can cancel any supplier return by calling the RPC directly.

`cancel_customer_return` has the same issue — no `has_permission('customer_returns', 'cancel')` check.

**Impact:** Privilege escalation — any employee can cancel returns via direct RPC call.

**Severity:** HIGH — security/authorization bypass.

#### R8. PDF fonts fetched from network on every generation
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\services\transaction_pdf_service.dart:39-42`

```dart
Future<pw.ThemeData> _loadTheme() async {
  final regular = await PdfGoogleFonts.openSansRegular();
  final bold = await PdfGoogleFonts.openSansBold();
  return pw.ThemeData.withFont(base: regular, bold: bold);
}
```

Every PDF generation fetches fonts from `https://fonts.gstatic.com`. This is called for each document type (2 per sale/purchase, 1 per delivery note). If the network is slow or the font service is unavailable, PDF generation fails.

**Impact:** PDF generation depends on external network availability. No offline capability.

**Severity:** HIGH — reliability risk for a core feature.

#### R9. No password strength validation in `create-employee` edge function
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\functions\create-employee\index.ts:44-54`

The edge function checks for `full_name`, `email`, `password` presence but does not validate:
- Password minimum length
- Password complexity
- Email format

Supabase Auth has its own password policy, but the error message returned to the user would be the raw Supabase error, not a user-friendly French message.

**Impact:** Weak passwords could be set. Inconsistent error messaging.

**Severity:** HIGH — security risk.

### 🟡 MEDIUM

#### R10. `dashboard_summary` RPC has hardcoded zero values
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0003_functions.sql:1-104`

The `dashboard_summary` function calculates `valeur_stock` and low/out-of-stock counts, but returns `0` for `ca_ht`, `marge_brute`, `creances_clients`, `creances_fournisseurs`, and `depenses`. These are placeholders.

**Impact:** Dashboard displays may show 0 for revenue, margin, receivables, payables, and expenses. Misleading for users.

**Severity:** MEDIUM — functional gap.

#### R11. `partner_statement` in `0003_functions.sql` is a placeholder
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0003_functions.sql:85-104`

The original `partner_statement` returns 0 for all financial metrics. However, this was superseded by `report_partner_statement` in `0009_phase4_8_functions.sql:977-1031` which is properly implemented.

**Impact:** Low — the old function may still be callable but is not used by the frontend.

**Severity:** MEDIUM — dead code.

#### R12. Silent error swallowing in admin settings load
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\screens\admin\admin_screens.dart:186-187`

```dart
} catch (_) {
} finally {
```

An empty catch block when loading company settings. If the settings fail to load, the user sees no error message and the form fields remain empty with no indication of failure.

**Impact:** User confusion when settings fail to load.

**Severity:** MEDIUM — UX issue.

#### R13. No offline support or retry logic
**Evidence:** Throughout the codebase, all operations use direct Supabase client calls with no:
- Local caching
- Retry mechanisms
- Offline queue
- Conflict resolution
- Idempotency keys

If the network connection drops during an operation (e.g., validating a sale), the user gets an error with no automatic retry.

**Impact:** Poor UX on unreliable connections. Potential for partial operations if the network drops mid-operation (though PostgreSQL functions are atomic, the client may not know the result).

**Severity:** MEDIUM — reliability risk.

#### R14. `validate_sale` does not check for empty sale lines
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0021_fix_cmup_fallback.sql:50-87`

The function recalculates totals from `sale_lines` and loops over them, but does not check if any lines exist. A sale with 0 lines would validate with `total_ht=0, total_tva=0, total_ttc=0 + stamp_duty=1.000`, decrementing no stock but creating a validated sale with a 1 DT total.

**Impact:** Users could accidentally validate empty sales. The 1 DT stamp duty makes this a minor financial anomaly.

**Severity:** MEDIUM — data quality.

#### R15. Settlement number generation uses `COUNT(*) + 1` (race condition)
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0019_bills_of_exchange_fixes.sql:90-92`

```sql
v_settlement_number := 'REG-' || to_char(now(), 'YYYY') || '-' || lpad((
  select count(*) + 1 from public.supplier_settlements where extract(year from created_at) = extract(year from now())
)::text, 4, '0');
```

Two concurrent settlement creations could generate the same number, causing a unique constraint violation. The `settlement_number` column has a UNIQUE constraint, so one transaction would fail, but the error would be a raw PostgreSQL error, not a user-friendly message.

The same pattern is used for SAV ticket numbers (`@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0017_sav.sql:68-76`).

Note: `next_document_number` (used for sales, purchases, etc.) uses `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` which is atomic and does NOT have this issue.

**Impact:** Rare race condition causing settlement creation failure with unfriendly error message.

**Severity:** MEDIUM — race condition + UX.

#### R16. `close_pos_session` does not check ownership or permission
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:550-611`

The function checks `is_active_employee()` but does NOT check:
- That the session belongs to the current user (`v_session.employee_id = auth.uid()`)
- That the user has `pos:close` or `pos:edit` permission

Any active employee could close any POS session by calling the RPC with the session ID.

**Impact:** Privilege escalation — any employee can close another employee's POS session.

**Severity:** MEDIUM — authorization bypass.

#### R17. `validate_adjustment` recalculates `delta` from `current_quantity` which may be stale
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0009_phase4_8_functions.sql:724-725`

```sql
v_line.delta := v_line.new_quantity - v_line.current_quantity;
```

The `current_quantity` was set when the adjustment draft was created. If stock has changed since then (e.g., a sale was validated), the delta would be incorrect — it would adjust based on the old current quantity, not the actual current stock.

**Impact:** Stock adjustment could produce incorrect stock levels if stock changed between draft creation and validation.

**Severity:** MEDIUM — data integrity.

### 🟢 LOW

#### R18. `report_stock_valuation` uses `purchase_price_ht` instead of CMUP
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0013_fix_stock_valuation_cmup.sql:7-50`

The stock valuation report returns `purchase_price_ht` from the `articles` table as the unit cost, not the `unit_cost_ht` (CMUP) from `stock_levels`. The actual stock value calculation at line 36 uses `sl.unit_cost_ht`, but the `purchase_price_ht` column returned to the client is the article's purchase price, not the CMUP.

**Impact:** The displayed "purchase_price_ht" in the report may not match the actual cost used for valuation. Could confuse users comparing the two columns.

**Severity:** LOW — reporting inconsistency.

#### R19. `expenses` table has no immutability RLS
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0008_phase4_8_rls.sql:87-94`

The `expenses` table has a `expenses_write` policy for `FOR ALL` (insert/update/delete). Unlike sales, purchases, and other documents, expenses can be directly updated or deleted even after creation. Migration 0010 does not include expenses in its immutability loop.

**Impact:** Expenses can be retroactively modified or deleted, potentially affecting financial reports.

**Severity:** LOW — financial audit trail gap.

#### R20. No rate limiting on authentication
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\screens\auth\login_screen.dart:29-42`

The login screen has no client-side rate limiting. Supabase Auth has built-in rate limiting, but the app provides no feedback on rate limit status.

**Impact:** Brute force attempts are throttled by Supabase but the user gets no friendly message about rate limiting.

**Severity:** LOW — UX + security.

---

## 4. RELEASE BLOCKERS

Issues that MUST be resolved before production deployment:

| # | Risk | Blocker Reason |
|---|------|----------------|
| B1 | R1 — `cancel_sale` doesn't reverse `amount_paid` | Financial data corruption — cancelled sales retain payment amounts |
| B2 | R2 — `record_payment` has no server-side amount validation | Financial integrity can be bypassed via direct API |
| B3 | R7 — Missing permission checks on cancel return functions | Authorization bypass — any employee can cancel returns |
| B4 | R16 — `close_pos_session` lacks ownership/permission check | Any employee can close any POS session |
| B5 | R3 — No test coverage | No regression safety net for a financial application |

---

## 5. SECURITY AUDIT

### 5.1 Authentication
- **Mechanism:** Supabase Auth (email/password) ✅
- **Session management:** Supabase JWT tokens ✅
- **Password reset:** Via edge function with admin-only access ✅
- **Password storage:** Supabase Auth handles bcrypt hashing ✅
- **Rate limiting:** Supabase Auth built-in (not configurable from app) ⚠️

### 5.2 Authorization
- **RLS:** Enabled on all tables ✅
- **Permission model:** `module:action` pairs in `employee_permissions` table ✅
- **SECURITY DEFINER functions:** All RPC functions check `is_active_employee()` and `has_permission()` ✅
- **Document immutability:** Non-draft documents cannot be modified via direct table access (migration 0010) ✅
- **Gaps:**
  - `cancel_supplier_return` and `cancel_customer_return` lack permission checks ❌ (R7)
  - `close_pos_session` lacks ownership/permission check ❌ (R16)
  - `expenses` table allows direct update/delete after creation ⚠️ (R19)

### 5.3 Injection Risks
- **SQL injection:** All queries use Supabase client query builder (parameterized) ✅
- **RPC functions:** Use PL/pgSQL variables, no dynamic SQL except migration 0010 which uses `format()` with `%I`/`%L` (safe) ✅
- **No raw SQL construction in Dart code** ✅

### 5.4 Secrets Management
- **Supabase URL and anon key:** Stored in `.env` file, loaded via dotenv ✅
- **Anon key:** Is a publishable key (not a secret) ✅
- **Service role key:** Only used in edge functions via `Deno.env.get()` ✅
- **No hardcoded secrets in Dart code** ✅
- **`.env` file:** Should be in `.gitignore` (verified pattern exists in `.env.example`) ✅

### 5.5 CORS
- Supabase handles CORS configuration at the project level. Not configurable from the app. The anon key is designed to be used from client-side applications.

### 5.6 Error Information Disclosure
- **AppException:** Maps PostgrestException and AuthException to user-friendly French messages ✅
- **Edge functions:** Return raw error messages from Supabase in some cases ⚠️ (e.g., `createError?.message` at `create-employee/index.ts:58`)
- **Empty catch blocks:** 1 instance silently swallows errors (R12)

### 5.7 Input Validation
- **Client-side:** Form validation in Flutter dialogs (required fields, numeric parsing) ✅
- **Server-side:**
  - `add_sale_sub_invoice`: Validates amount > 0, sub_client_name not empty, sum ≤ total_ttc ✅
  - `validate_sale`: Checks status is 'brouillon' ✅
  - `record_payment`: ❌ No amount validation (R2)
  - `create_supplier_settlement`: Validates sum equals total_ttc, checks no double settlement ✅
  - Edge functions: Check required fields presence but no format validation ⚠️ (R9)

---

## 6. DATABASE AUDIT

### 6.1 Integrity Constraints
- **Foreign keys:** All tables have proper FK constraints ✅
- **Unique constraints:** Document numbers are unique per table ✅
- **Check constraints:** Amount > 0 on sub-invoices, bills, settlements ✅
- **Location constraint:** `one_location` check on sales, delivery_notes, customer_returns, stock_adjustments (exactly one of depot_id/showroom_id) ✅
- **Partial unique indexes:** `stock_levels` has partial unique indexes for depot_id and showroom_id ✅

### 6.2 Indexing
- **Foreign key indexes:** Most FKs are indexed ✅
- **Status indexes:** `sav_tickets` has status index, `bills_of_exchange` has status index ✅
- **Date indexes:** No indexes on `sale_date`, `purchase_date`, `delivery_date`, `return_date`, `payment_date`, `expense_date` ⚠️
  - All list queries filter and order by these date columns
  - With growing data, these queries will become slow
- **Document number indexes:** Unique constraints serve as indexes ✅

### 6.3 Transaction Safety
- **RPC functions:** PostgreSQL functions are atomic (implicit transaction) ✅
- **Row locking:** `SELECT ... FOR UPDATE` used in validate/cancel functions for:
  - Document headers (sales, purchases, etc.) ✅
  - Stock levels ✅
- **Document numbering:** `next_document_number` uses `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` (atomic) ✅
- **Settlement numbering:** Uses `COUNT(*) + 1` (NOT atomic) ⚠️ (R15)

### 6.4 Race Conditions
- **Concurrent stock operations:** `upsert_stock_level` uses `FOR UPDATE` lock on `stock_levels` row, preventing concurrent modifications ✅
- **Concurrent payments on same sale:** `record_payment` uses `FOR UPDATE` on the sale row ✅
- **Concurrent settlement creation:** Race condition on settlement number (R15) ⚠️
- **Concurrent sub-invoice creation:** `add_sale_sub_invoice` uses `FOR UPDATE` on the sale row, preventing over-allocation ✅

### 6.5 Data Loss Risks
- **`replaceLines` pattern:** Delete all lines then insert new ones. If the insert fails after the delete, lines are lost. This is done in 2 separate Supabase calls without a transaction:
  - `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\repositories\phase4_8_repositories.dart:145-167` (sale lines)
  - `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\repositories\phase4_8_repositories.dart:938-965` (adjustment lines)
  - `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\repositories\purchase_repository.dart:114-130` (purchase lines)
  - `@/c:\Users\AmineBZ\Desktop\jabnoun erp\lib\repositories\inventory_repository.dart:96-113` (inventory lines)

  **Impact:** If the network drops between the delete and insert, the draft document loses all its lines. The user would need to re-enter them.

  **Severity:** MEDIUM — data loss on network failure.

### 6.6 CMUP (Weighted Average Cost) Calculation
**Evidence:** `@/c:\Users\AmineBZ\Desktop\jabnoun erp\supabase\migrations\0021_fix_cmup_fallback.sql:12-47`

The CMUP formula:
```sql
v_new_cost := round(((v_quantity * coalesce(v_cost, p_incoming_unit_cost_ht)) + (p_delta * p_incoming_unit_cost_ht)) / (v_quantity + p_delta), 3);
```

- Correctly calculates weighted average when incoming stock has a cost ✅
- Uses existing cost for negative deltas (sales, transfers out) ✅
- Falls back to `purchase_price_ht` when `unit_cost_ht` is null ✅ (0021 fix)
- Rounding to 3 decimal places ✅

**Concern:** The fallback to `purchase_price_ht` may not reflect the actual cost of goods sold if the article's purchase price has changed since the stock was acquired. This could distort margin calculations.

---

## 7. FINANCIAL INTEGRITY AUDIT

### 7.1 Monetary Calculations
- **Precision:** `numeric(14,3)` used for all monetary fields (3 decimal places) ✅
- **Rounding:** `round(..., 3)` used in all calculations ✅
- **Discount proration:** Discount is applied to HT, then TVA is prorated:
  ```sql
  v_sale.total_tva := round(v_sale.total_ht * (v_sale.total_tva / (v_sale.total_ht + v_sale.discount_amount)), 3);
  ```
  This correctly prorates TVA after discount ✅

### 7.2 Stamp Duty (Droit de Timbre)
- **Amount:** Fixed at 1.000 DT, added to TTC after all other calculations ✅
- **Not subject to TVA:** Correct — added after TVA calculation ✅
- **Not discounted:** Correct — added after discount calculation ✅
- **Default:** `numeric(10,3) not null default 1.000` ✅

### 7.3 Payment Status Transitions
```
brouillon → valide → partiellement_paye → paye
                → annule (from valide or partiellement_paye)
```

**Issue:** `cancel_sale` allows cancellation from `partiellement_paye` but does not reverse `amount_paid` (R1). The `paye` status correctly blocks cancellation.

### 7.4 Refunds/Cancellations
- **Sale cancellation:** Restores stock ✅, but does NOT reverse payments ❌ (R1)
- **Purchase cancellation:** Restores stock ✅, payment reversal not handled in `cancel_purchase` (not found in code — likely same issue)
- **Delivery cancellation:** Restores stock ✅, no payment involved ✅
- **Return cancellation:** Reverses stock movement ✅

### 7.5 Bill of Exchange Payment Sync
- **`mark_bill_paid`:** Updates purchase `amount_paid` and status ✅ (0019 fix)
- **Double payment prevention:** Checks `v_bill.status = 'payee'` ✅
- **Double settlement prevention:** Checks existing active bills on purchase ✅

---

## 8. SYNCHRONIZATION AUDIT

### 8.1 Offline Behavior
- **No offline support:** All operations require active network connection ❌
- **No local caching:** Data is fetched from Supabase on every screen load ❌
- **No offline queue:** Operations cannot be queued for later submission ❌

### 8.2 Retry Logic
- **No retry mechanism:** Failed operations show an error snackbar with no automatic retry ❌
- **User must manually retry:** By navigating away and back, or re-submitting ❌

### 8.3 Idempotency
- **No idempotency keys:** Operations could be duplicated if the user double-clicks or the network retries ❌
- **Mitigation:** The UI disables buttons during operations (`_loading` / `_saving` flags) ✅
- **Risk:** If the network response is delayed, the user might close and re-open the dialog, then submit again

### 8.4 Conflict Resolution
- **Optimistic concurrency:** Not implemented ❌
- **Pessimistic concurrency:** `FOR UPDATE` locks in RPC functions handle server-side conflicts ✅
- **Client-side conflicts:** If two users edit the same draft, last write wins (no version checking) ⚠️

---

## 9. AI-GENERATED CODE RISK AUDIT

### 9.1 Function Override Pattern
The `validate_sale` function has been overridden 4 times (R4). This is a common AI-generated code pattern where each "fix" creates a new migration instead of modifying the existing one. The risk is that the final function definition depends on migration order, and any failed migration leaves the database in an inconsistent state.

**Recommendation:** Consolidate all `validate_sale` logic into a single authoritative migration.

### 9.2 Copy-Paste Patterns
The RLS policies in `0008_phase4_8_rls.sql` follow a repetitive pattern (`for all using (is_admin or has_permission(...))`). This was later corrected in `0010_document_immutability_rls.sql` and `0020_app_wide_integrity_fixes.sql`. The evolution shows:
1. Initial: `FOR ALL` policies (too permissive)
2. Correction: Draft-only mutability
3. Further correction: Remove direct write on pos_sessions, payments

This iterative pattern is typical of AI-generated code that gets refined over multiple passes.

### 9.3 Inconsistent Permission Checks
Some RPC functions check permissions (e.g., `validate_sale` checks `has_permission('sales', 'validate')`) while others don't (e.g., `cancel_supplier_return` has no permission check — R7). This inconsistency suggests the functions were generated at different times without a consistent checklist.

### 9.4 Missing Validation Patterns
- `record_payment` lacks amount validation (R2) — the AI likely assumed the client would always validate
- `validate_sale` doesn't check for empty lines (R14) — the AI likely assumed lines would always exist
- `close_pos_session` lacks ownership check (R16) — the AI likely didn't consider multi-user scenarios

### 9.5 N+1 Query Pattern
The `PaymentRepository.fetchAll` N+1 query (R6) is a common AI-generated pattern where the developer thinks procedurally (loop + fetch) rather than in SQL (join).

---

## 10. TESTING GAPS

### 10.1 Current Coverage
| Area | Coverage | Details |
|------|----------|---------|
| Theme | 1 test | `AppTheme.light` builds without error |
| Repositories | 0 tests | No tests for any repository |
| Models | 0 tests | No serialization/deserialization tests |
| RPC functions | 0 tests | No tests for validate/cancel/payment logic |
| Screens | 0 tests | No widget tests |
| Integration | 0 tests | No end-to-end tests |
| Financial calc | 0 tests | No CMUP, discount, stamp duty, TVA tests |
| Permissions | 0 tests | No authorization tests |
| Edge cases | 0 tests | No empty/edge case tests |

### 10.2 Critical Test Scenarios Needed

**Financial logic:**
- CMUP calculation with multiple incoming stock movements
- Discount proration with TVA
- Stamp duty addition to TTC
- Payment status transitions (brouillon → valide → partiellement_paye → paye)
- Sale cancellation with partial payment (should fail or reverse payment)
- Overpayment prevention
- Negative payment prevention
- Empty sale validation

**Permissions:**
- Non-admin cannot validate/cancel documents
- Non-admin cannot access other users' POS sessions
- Permission matrix enforcement per module:action

**Data integrity:**
- Stock cannot go negative (unless allowed by company_settings)
- Document immutability after validation
- Sub-invoice sum cannot exceed sale total
- Bill of exchange sum must equal purchase total
- Double settlement prevention

**Concurrency:**
- Concurrent payment recording on same sale
- Concurrent stock operations on same article/location
- Concurrent document number generation

---

## 11. PERFORMANCE ANALYSIS

### 11.1 Query Performance
- **List queries:** Use pagination (limit=50, offset) ✅
- **Embedded relations:** Use Supabase select embedding (e.g., `*, customer:customers(name), sale_lines(*, article:articles(...))`) ✅
- **N+1 queries:** `PaymentRepository.fetchAll` (R6) ❌
- **Missing date indexes:** All date columns used for filtering/ordering lack indexes ⚠️

### 11.2 PDF Generation Performance
- Fonts fetched from network on every generation (R8) ❌
- 2 PDFs generated per sale/purchase validation (bon + facture) — doubles network dependency
- No PDF caching — re-generated every time

### 11.3 Client-Side Performance
- **No local caching:** Every screen fetches data from Supabase on load
- **No prefetching:** Data is loaded only when the screen is displayed
- **Riverpod providers:** Use `FutureProvider` and `AsyncNotifierProvider` — standard patterns ✅

### 11.4 Load Test Plan

| Scenario | Concurrent Users | Expected Response Time | Test Method |
|----------|-----------------|----------------------|-------------|
| Login | 10 | < 2s | Supabase Auth handles rate limiting |
| Sales list (50 items) | 5 | < 1s | Paginated query with embedded relations |
| Sale validation | 3 concurrent | < 2s | RPC with FOR UPDATE locks |
| Payment recording | 5 concurrent on same sale | < 3s | RPC with FOR UPDATE on sale row |
| Payment list (50 items) | 5 | < 5s | N+1 query (R6) — will be slow |
| PDF generation | 1 | < 5s | Network-dependent (font fetch) |
| Dashboard summary | 5 | < 2s | RPC with aggregate queries |
| Stock valuation report | 3 | < 3s | RPC with join + aggregation |
| Document numbering | 10 concurrent | < 1s | Atomic INSERT ON CONFLICT |

**Bottleneck:** `PaymentRepository.fetchAll` with 50 items will take 5-15 seconds due to N+1 queries.

---

## 12. REMEDIATION ORDER

### Phase 1: Release Blockers (Must fix before production)
1. **B1 (R1):** Add `amount_paid` reset and payment reversal logic to `cancel_sale`
2. **B2 (R2):** Add server-side validation in `record_payment` (amount > 0, amount ≤ remaining)
3. **B3 (R7):** Add `has_permission` checks to `cancel_supplier_return` and `cancel_customer_return`
4. **B4 (R16):** Add ownership/permission check to `close_pos_session`
5. **B5 (R3):** Write minimum viable test suite (repository tests, financial logic tests, permission tests)

### Phase 2: High Priority (Fix within first sprint)
6. **R6:** Fix N+1 query in `PaymentRepository.fetchAll` (use embedded relation or batch query)
7. **R8:** Bundle PDF fonts as assets instead of fetching from network
8. **R9:** Add password strength validation in `create-employee` edge function
9. **R4/R5:** Consolidate function definitions into a single authoritative migration

### Phase 3: Medium Priority (Fix within first month)
10. **R10:** Implement real values in `dashboard_summary` RPC
11. **R13:** Add basic retry logic for failed operations
12. **R14:** Add empty sale lines check in `validate_sale`
13. **R15:** Use `next_document_number` pattern for settlement and SAV ticket numbers
14. **R17:** Recalculate delta from actual current stock in `validate_adjustment`
15. **Data loss (6.5):** Wrap `replaceLines` operations in a single RPC function

### Phase 4: Low Priority (Backlog)
16. **R18:** Fix stock valuation report to show CMUP instead of purchase_price_ht
17. **R19:** Add immutability RLS to `expenses` table
18. **R20:** Add rate limit feedback in login screen
19. Add missing date column indexes
20. Remove dead code (placeholder functions in 0003)

---

## 13. READINESS SCORES

| Category | Score | Justification |
|----------|-------|---------------|
| **Architecture** | 8/10 | Clean separation, good patterns, minor function override debt |
| **Security** | 6/10 | RLS solid, but 3 authorization bypass bugs (R7, R16, R2) |
| **Database Integrity** | 7/10 | Good constraints and locking, but cancel_sale payment bug (R1) and replaceLines data loss risk |
| **Financial Integrity** | 5/10 | CMUP correct, but payment validation missing (R2), cancel doesn't reverse payments (R1), no empty sale check (R14) |
| **Test Coverage** | 1/10 | Only 1 smoke test for a financial application |
| **Performance** | 6/10 | Paginated and embedded queries, but N+1 in payments and network-dependent PDF fonts |
| **Synchronization/Offline** | 2/10 | No offline support, no retry, no idempotency |
| **AI Code Quality** | 6/10 | Functional but inconsistent (permission checks, validation, function overrides) |
| **UX/Error Handling** | 7/10 | French error messages, proper loading states, but silent error swallowing and no retry |
| **Deployment Readiness** | 4/10 | 5 release blockers, no tests, migration ordering risk |

### **OVERALL PRODUCTION READINESS: 5/10 — NOT READY**

The application has a solid architectural foundation and good security patterns (RLS, SECURITY DEFINER, document immutability). However, 5 release blockers — including financial data corruption (R1), financial integrity bypass (R2), authorization bypasses (R7, R16), and zero test coverage (R3) — make it unsafe for production deployment. The issues are fixable with targeted SQL migrations and a focused testing sprint.

---

*End of Audit Report*
