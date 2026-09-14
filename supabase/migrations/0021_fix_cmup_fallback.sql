-- Fix: Coût CMUP indisponible — when stock_levels.unit_cost_ht is null,
-- fall back to the article's purchase_price_ht instead of raising an error.

-- 1. Backfill any null unit_cost_ht in stock_levels from articles.purchase_price_ht
update public.stock_levels sl
set unit_cost_ht = a.purchase_price_ht
from public.articles a
where a.id = sl.article_id and sl.unit_cost_ht is null and a.purchase_price_ht is not null;

-- 2. Update upsert_stock_level: when inserting a new stock level with null cost,
-- use the article's purchase_price_ht as default.
create or replace function public.upsert_stock_level(
  p_article_id uuid, p_depot_id uuid, p_showroom_id uuid, p_delta numeric,
  p_incoming_unit_cost_ht numeric default null
) returns void language plpgsql security definer as $$
declare v_quantity numeric; v_cost numeric; v_allow_neg boolean; v_new_cost numeric; v_exists boolean; v_fallback numeric;
begin
  if (p_depot_id is null and p_showroom_id is null) or (p_depot_id is not null and p_showroom_id is not null) then
    raise exception 'Emplacement invalide : un seul de depot_id / showroom_id doit être renseigné.';
  end if;
  select quantity, unit_cost_ht into v_quantity, v_cost from public.stock_levels
  where article_id = p_article_id and ((p_depot_id is not null and depot_id = p_depot_id) or (p_showroom_id is not null and showroom_id = p_showroom_id)) for update;
  v_exists := found;
  v_quantity := coalesce(v_quantity, 0);
  -- Fallback to article purchase_price_ht if cost is null
  if v_cost is null then
    select purchase_price_ht into v_fallback from public.articles where id = p_article_id;
    v_cost := v_fallback;
  end if;
  select coalesce(allow_negative_stock, false) into v_allow_neg from public.company_settings limit 1;
  if v_quantity + p_delta < 0 and not v_allow_neg then
    raise exception 'Stock insuffisant pour cet article (disponible: %, demandé: %).', v_quantity, abs(p_delta);
  end if;
  if p_delta > 0 and p_incoming_unit_cost_ht is not null then
    v_new_cost := round(((v_quantity * coalesce(v_cost, p_incoming_unit_cost_ht)) + (p_delta * p_incoming_unit_cost_ht)) / (v_quantity + p_delta), 3);
  else
    v_new_cost := v_cost;
  end if;
  if v_exists then
    update public.stock_levels set quantity = quantity + p_delta, unit_cost_ht = v_new_cost, updated_at = now()
    where article_id = p_article_id and ((p_depot_id is not null and depot_id = p_depot_id) or (p_showroom_id is not null and showroom_id = p_showroom_id));
  else
    insert into public.stock_levels (article_id, depot_id, showroom_id, quantity, unit_cost_ht)
    values (p_article_id, p_depot_id, p_showroom_id, greatest(p_delta, 0), coalesce(p_incoming_unit_cost_ht, v_cost));
  end if;
end;
$$;

-- 3. Update validate_sale: fall back to article purchase_price_ht when unit_cost_ht is null
create or replace function public.validate_sale(p_sale_id uuid)
returns public.sales language plpgsql security definer as $$
declare v_sale public.sales; v_line public.sale_lines; v_cost numeric; v_fallback numeric;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sales', 'validate')) then raise exception 'Vous n''avez pas le droit de valider les ventes.'; end if;
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then raise exception 'Vente introuvable.'; end if;
  if v_sale.status != 'brouillon' then raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_sale.status; end if;
  select coalesce(sum(line_total_ht),0), coalesce(sum(line_total_tva),0), coalesce(sum(line_total_ttc),0)
    into v_sale.total_ht, v_sale.total_tva, v_sale.total_ttc from public.sale_lines where sale_id = p_sale_id;
  if v_sale.discount_percent > 0 then
    v_sale.discount_amount := round(v_sale.total_ht * v_sale.discount_percent / 100, 3);
    v_sale.total_ht := v_sale.total_ht - v_sale.discount_amount;
    v_sale.total_tva := round(v_sale.total_ht * (case when v_sale.total_ht > 0 then v_sale.total_tva / (v_sale.total_ht + v_sale.discount_amount) else 0 end), 3);
    v_sale.total_ttc := v_sale.total_ht + v_sale.total_tva;
  end if;
  v_sale.stamp_duty_amount := coalesce(v_sale.stamp_duty_amount, 1.000);
  v_sale.total_ttc := v_sale.total_ttc + v_sale.stamp_duty_amount;
  for v_line in select * from public.sale_lines where sale_id = p_sale_id loop
    select unit_cost_ht into v_cost from public.stock_levels where article_id = v_line.article_id
      and ((v_sale.depot_id is not null and depot_id = v_sale.depot_id) or (v_sale.showroom_id is not null and showroom_id = v_sale.showroom_id)) for update;
    -- Fallback to article purchase_price_ht if CMUP cost is null
    if v_cost is null then
      select purchase_price_ht into v_fallback from public.articles where id = v_line.article_id;
      v_cost := v_fallback;
    end if;
    if v_cost is null then raise exception 'Coût indisponible pour l''article % — aucun prix d''achat défini.', v_line.article_id; end if;
    update public.sale_lines set unit_cost_ht = v_cost, total_cost_ht = round(v_line.quantity * v_cost, 3) where id = v_line.id;
    perform public.upsert_stock_level(v_line.article_id, v_sale.depot_id, v_sale.showroom_id, -v_line.quantity);
    insert into public.stock_movements (article_id, movement_type, quantity, source_depot_id, source_showroom_id, source_label, document_type, document_id, document_number, created_by)
    values (v_line.article_id, 'vente', v_line.quantity, v_sale.depot_id, v_sale.showroom_id, 'Vente ' || v_sale.document_number, 'vente', p_sale_id, v_sale.document_number, auth.uid());
  end loop;
  update public.sales set status='valide', total_ht=v_sale.total_ht, total_tva=v_sale.total_tva, total_ttc=v_sale.total_ttc, stamp_duty_amount=v_sale.stamp_duty_amount, discount_amount=v_sale.discount_amount, validated_by=auth.uid(), validated_at=now() where id=p_sale_id;
  perform public.write_audit_log('validate','sales','sale',p_sale_id,v_sale.document_number,null,null,'Vente validée: ' || v_sale.document_number);
  select * into v_sale from public.sales where id=p_sale_id; return v_sale;
end;
$$;
