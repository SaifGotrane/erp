-- =====================================================================
-- Jabnoun ERP — Fonctions RPC
-- Ces fonctions centralisent les calculs côté serveur (jamais de données
-- fictives côté client). Certains indicateurs dépendent de modules non
-- encore implémentés (achats, ventes, paiements, caisse) : ils renvoient
-- 0 en attendant et devront être complétés lors de ces phases.
-- =====================================================================

create or replace function public.dashboard_summary(
  p_from timestamptz,
  p_to timestamptz,
  p_depot_id uuid default null,
  p_showroom_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_valeur_stock numeric := 0;
  v_low_stock_count integer := 0;
  v_out_of_stock_count integer := 0;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  -- Valeur du stock au prix d'achat, filtrée par emplacement si fourni.
  select coalesce(sum(sl.quantity * a.purchase_price_ht), 0)
    into v_valeur_stock
  from public.stock_levels sl
  join public.articles a on a.id = sl.article_id
  where (p_depot_id is null or sl.depot_id = p_depot_id)
    and (p_showroom_id is null or sl.showroom_id = p_showroom_id);

  -- Articles dont le stock total est en dessous du seuil minimum.
  select count(*) into v_low_stock_count
  from (
    select a.id, a.min_stock, coalesce(sum(sl.quantity), 0) as total_qty
    from public.articles a
    left join public.stock_levels sl on sl.article_id = a.id
    where a.active = true
    group by a.id, a.min_stock
    having coalesce(sum(sl.quantity), 0) < a.min_stock and coalesce(sum(sl.quantity), 0) > 0
  ) t;

  select count(*) into v_out_of_stock_count
  from (
    select a.id, coalesce(sum(sl.quantity), 0) as total_qty
    from public.articles a
    left join public.stock_levels sl on sl.article_id = a.id
    where a.active = true
    group by a.id
    having coalesce(sum(sl.quantity), 0) <= 0
  ) t;

  return jsonb_build_object(
    'ca_ht', 0,
    'ca_ttc', 0,
    'tva_collectee', 0,
    'tva_deductible', 0,
    'tva_a_payer', 0,
    'marge_brute', 0,
    'creances_clients', 0,
    'dettes_fournisseurs', 0,
    'valeur_stock', v_valeur_stock,
    'low_stock_count', v_low_stock_count,
    'out_of_stock_count', v_out_of_stock_count,
    'unpaid_invoices_count', 0,
    'open_pos_sessions_count', 0,
    'draft_documents_count', 0
  );
end;
$$;

-- Relevé fournisseur/client (solde, mouvements) — sera complété lors de
-- l'implémentation des modules achats/ventes/paiements.
create or replace function public.partner_statement(
  p_partner_id uuid,
  p_partner_table text,
  p_from timestamptz,
  p_to timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return jsonb_build_object(
    'total_ht', 0,
    'total_ttc', 0,
    'total_paye', 0,
    'solde', 0,
    'lignes', '[]'::jsonb
  );
end;
$$;
