-- Historical sales costing. Existing validated sales are deliberately not backfilled:
-- their historical cost cannot be reconstructed reliably from the current schema.

alter table public.stock_levels add column if not exists unit_cost_ht numeric(14,3);
alter table public.sale_lines add column if not exists unit_cost_ht numeric(14,3);
alter table public.sale_lines add column if not exists total_cost_ht numeric(14,3);

-- This initializes current on-hand stock only; it does not assert a cost for old sales.
update public.stock_levels sl
set unit_cost_ht = a.purchase_price_ht
from public.articles a
where a.id = sl.article_id and sl.unit_cost_ht is null;

-- Quantity updates keep the existing cost. Positive movements with an explicit
-- cost are merged using CMUP at the affected depot/showroom.
create or replace function public.upsert_stock_level(
  p_article_id uuid, p_depot_id uuid, p_showroom_id uuid, p_delta numeric,
  p_incoming_unit_cost_ht numeric default null
) returns void language plpgsql security definer as $$
declare v_quantity numeric; v_cost numeric; v_allow_neg boolean; v_new_cost numeric; v_exists boolean;
begin
  if (p_depot_id is null and p_showroom_id is null) or (p_depot_id is not null and p_showroom_id is not null) then
    raise exception 'Emplacement invalide : un seul de depot_id / showroom_id doit être renseigné.';
  end if;
  select quantity, unit_cost_ht into v_quantity, v_cost from public.stock_levels
  where article_id = p_article_id and ((p_depot_id is not null and depot_id = p_depot_id) or (p_showroom_id is not null and showroom_id = p_showroom_id)) for update;
  v_exists := found;
  v_quantity := coalesce(v_quantity, 0);
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
    values (p_article_id, p_depot_id, p_showroom_id, greatest(p_delta, 0), p_incoming_unit_cost_ht);
  end if;
end;
$$;

create or replace function public.validate_sale(p_sale_id uuid)
returns public.sales language plpgsql security definer as $$
declare v_sale public.sales; v_line public.sale_lines; v_cost numeric;
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
  for v_line in select * from public.sale_lines where sale_id = p_sale_id loop
    select unit_cost_ht into v_cost from public.stock_levels where article_id = v_line.article_id
      and ((v_sale.depot_id is not null and depot_id = v_sale.depot_id) or (v_sale.showroom_id is not null and showroom_id = v_sale.showroom_id)) for update;
    if v_cost is null then raise exception 'Coût CMUP indisponible pour l''article % à cet emplacement.', v_line.article_id; end if;
    update public.sale_lines set unit_cost_ht = v_cost, total_cost_ht = round(v_line.quantity * v_cost, 3) where id = v_line.id;
    perform public.upsert_stock_level(v_line.article_id, v_sale.depot_id, v_sale.showroom_id, -v_line.quantity);
    insert into public.stock_movements (article_id, movement_type, quantity, source_depot_id, source_showroom_id, source_label, document_type, document_id, document_number, created_by)
    values (v_line.article_id, 'vente', v_line.quantity, v_sale.depot_id, v_sale.showroom_id, 'Vente ' || v_sale.document_number, 'vente', p_sale_id, v_sale.document_number, auth.uid());
  end loop;
  update public.sales set status='valide', total_ht=v_sale.total_ht, total_tva=v_sale.total_tva, total_ttc=v_sale.total_ttc, discount_amount=v_sale.discount_amount, validated_by=auth.uid(), validated_at=now() where id=p_sale_id;
  perform public.write_audit_log('validate','sales','sale',p_sale_id,v_sale.document_number,null,null,'Vente validée: ' || v_sale.document_number);
  select * into v_sale from public.sales where id=p_sale_id; return v_sale;
end;
$$;

-- Purchases inject their effective HT cost (line discount plus document discount)
-- into the location CMUP before stock is made available for sales.
create or replace function public.validate_purchase(p_purchase_id uuid)
returns public.purchases language plpgsql security definer as $$
declare v_purchase public.purchases; v_line public.purchase_lines; v_unit_cost numeric;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('purchases', 'validate')) then raise exception 'Vous n''avez pas le droit de valider les achats.'; end if;
  select * into v_purchase from public.purchases where id=p_purchase_id for update;
  if not found then raise exception 'Achat introuvable.'; end if;
  if v_purchase.status != 'brouillon' then raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_purchase.status; end if;
  select coalesce(sum(line_total_ht),0),coalesce(sum(line_total_tva),0),coalesce(sum(line_total_ttc),0) into v_purchase.total_ht,v_purchase.total_tva,v_purchase.total_ttc from public.purchase_lines where purchase_id=p_purchase_id;
  if v_purchase.discount_percent > 0 then
    v_purchase.discount_amount:=round(v_purchase.total_ht*v_purchase.discount_percent/100,3); v_purchase.total_ht:=v_purchase.total_ht-v_purchase.discount_amount;
    v_purchase.total_tva:=round(v_purchase.total_ht*(case when v_purchase.total_ht>0 then v_purchase.total_tva/(v_purchase.total_ht+v_purchase.discount_amount) else 0 end),3); v_purchase.total_ttc:=v_purchase.total_ht+v_purchase.total_tva;
  end if;
  for v_line in select * from public.purchase_lines where purchase_id=p_purchase_id loop
    v_unit_cost := round((v_line.line_total_ht / nullif(v_line.quantity,0)) * (1 - v_purchase.discount_percent / 100), 3);
    perform public.upsert_stock_level(v_line.article_id,v_purchase.depot_id,null,v_line.quantity,v_unit_cost);
    insert into public.stock_movements (article_id,movement_type,quantity,destination_depot_id,destination_label,document_type,document_id,document_number,created_by)
    values (v_line.article_id,'entree',v_line.quantity,v_purchase.depot_id,'Achat '||v_purchase.document_number,'achat',p_purchase_id,v_purchase.document_number,auth.uid());
  end loop;
  update public.purchases set status='valide',total_ht=v_purchase.total_ht,total_tva=v_purchase.total_tva,total_ttc=v_purchase.total_ttc,discount_amount=v_purchase.discount_amount,validated_by=auth.uid(),validated_at=now() where id=p_purchase_id;
  perform public.write_audit_log('validate','purchases','purchase',p_purchase_id,v_purchase.document_number,null,null,'Achat validé: '||v_purchase.document_number);
  select * into v_purchase from public.purchases where id=p_purchase_id; return v_purchase;
end;
$$;

-- A transfer carries the source location's CMUP into the destination CMUP.
create or replace function public.validate_transfer(p_transfer_id uuid)
returns public.stock_transfers language plpgsql security definer as $$
declare v_transfer public.stock_transfers; v_line public.stock_transfer_lines; v_cost numeric;
  v_src_label text; v_dst_label text;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('transfers','validate')) then raise exception 'Vous n''avez pas le droit de valider les transferts.'; end if;
  select * into v_transfer from public.stock_transfers where id=p_transfer_id for update;
  if not found then raise exception 'Transfert introuvable.'; end if;
  if v_transfer.status!='brouillon' then raise exception 'Seul un brouillon peut être validé (statut actuel: %).',v_transfer.status; end if;
  select name into v_src_label from public.depots where id=v_transfer.source_depot_id; if v_src_label is null then select name into v_src_label from public.showrooms where id=v_transfer.source_showroom_id; end if;
  select name into v_dst_label from public.depots where id=v_transfer.destination_depot_id; if v_dst_label is null then select name into v_dst_label from public.showrooms where id=v_transfer.destination_showroom_id; end if;
  for v_line in select * from public.stock_transfer_lines where transfer_id=p_transfer_id loop
    select unit_cost_ht into v_cost from public.stock_levels where article_id=v_line.article_id and ((v_transfer.source_depot_id is not null and depot_id=v_transfer.source_depot_id) or (v_transfer.source_showroom_id is not null and showroom_id=v_transfer.source_showroom_id)) for update;
    if v_cost is null then raise exception 'Coût CMUP indisponible pour l''article % à l''emplacement source.',v_line.article_id; end if;
    perform public.upsert_stock_level(v_line.article_id,v_transfer.source_depot_id,v_transfer.source_showroom_id,-v_line.quantity);
    perform public.upsert_stock_level(v_line.article_id,v_transfer.destination_depot_id,v_transfer.destination_showroom_id,v_line.quantity,v_cost);
    insert into public.stock_movements (article_id,movement_type,quantity,source_depot_id,source_showroom_id,source_label,destination_depot_id,destination_showroom_id,destination_label,document_type,document_id,document_number,created_by)
    values(v_line.article_id,'transfert',v_line.quantity,v_transfer.source_depot_id,v_transfer.source_showroom_id,v_src_label,v_transfer.destination_depot_id,v_transfer.destination_showroom_id,v_dst_label,'transfert',p_transfer_id,v_transfer.document_number,auth.uid());
  end loop;
  update public.stock_transfers set status='valide',validated_by=auth.uid(),validated_at=now() where id=p_transfer_id;
  perform public.write_audit_log('validate','transfers','transfer',p_transfer_id,v_transfer.document_number,null,null,'Transfert validé: '||v_transfer.document_number);
  select * into v_transfer from public.stock_transfers where id=p_transfer_id; return v_transfer;
end;
$$;

create or replace function public.report_sales_margin(
  p_from date default null, p_to date default null, p_article_id uuid default null,
  p_customer_id uuid default null, p_depot_id uuid default null, p_showroom_id uuid default null
) returns table (total_sales_ht numeric, total_cost_ht numeric, margin_ht numeric, margin_percent numeric, sales_lines_count bigint, unknown_cost_lines bigint)
language plpgsql security definer as $$
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  return query with lines as (
    select sl.line_total_ht * (1 - coalesce(s.discount_amount,0) / nullif(sum(sl.line_total_ht) over (partition by s.id),0)) as net_sales_ht,
      sl.total_cost_ht, sl.unit_cost_ht
    from public.sales s join public.sale_lines sl on sl.sale_id=s.id
    where s.status in ('valide','partiellement_paye','paye')
      and (p_from is null or s.sale_date>=p_from) and (p_to is null or s.sale_date<=p_to)
      and (p_article_id is null or sl.article_id=p_article_id) and (p_customer_id is null or s.customer_id=p_customer_id)
      and (p_depot_id is null or s.depot_id=p_depot_id) and (p_showroom_id is null or s.showroom_id=p_showroom_id)
  ), totals as (select coalesce(sum(net_sales_ht),0) sales_ht, coalesce(sum(total_cost_ht),0) cost_ht, count(*) filter(where unit_cost_ht is null) unknowns, count(*) lines_count from lines)
  select sales_ht, cost_ht, case when unknowns>0 then null else sales_ht-cost_ht end,
    case when unknowns>0 or cost_ht=0 then null else (sales_ht-cost_ht)/cost_ht*100 end, lines_count, unknowns from totals;
end;
$$;
