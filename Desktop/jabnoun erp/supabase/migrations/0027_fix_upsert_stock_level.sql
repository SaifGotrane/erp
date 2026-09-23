-- =====================================================================
-- 0027_fix_upsert_stock_level_ambiguity.sql
-- Drop the old 4-param version of upsert_stock_level so only the
-- 5-param version (with optional p_incoming_unit_cost_ht) remains.
-- =====================================================================

drop function if exists public.upsert_stock_level(uuid, uuid, uuid, numeric);
