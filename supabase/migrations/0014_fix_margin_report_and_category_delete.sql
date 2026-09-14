-- Avoid PL/pgSQL output-variable ambiguity in the historical margin RPC.
create or replace function public.report_sales_margin(
  p_from date default null, p_to date default null, p_article_id uuid default null,
  p_customer_id uuid default null, p_depot_id uuid default null, p_showroom_id uuid default null
) returns table (total_sales_ht numeric, total_cost_ht numeric, margin_ht numeric, margin_percent numeric, sales_lines_count bigint, unknown_cost_lines bigint)
language plpgsql security definer as $$
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  return query with report_lines as (
    select sl.line_total_ht * (1 - coalesce(s.discount_amount, 0) / nullif(sum(sl.line_total_ht) over (partition by s.id), 0)) as net_sales_ht,
      sl.total_cost_ht as historical_cost_ht, sl.unit_cost_ht as historical_unit_cost_ht
    from public.sales s join public.sale_lines sl on sl.sale_id = s.id
    where s.status in ('valide', 'partiellement_paye', 'paye')
      and (p_from is null or s.sale_date >= p_from) and (p_to is null or s.sale_date <= p_to)
      and (p_article_id is null or sl.article_id = p_article_id) and (p_customer_id is null or s.customer_id = p_customer_id)
      and (p_depot_id is null or s.depot_id = p_depot_id) and (p_showroom_id is null or s.showroom_id = p_showroom_id)
  ), aggregates as (
    select coalesce(sum(rl.net_sales_ht), 0) as sales_ht, coalesce(sum(rl.historical_cost_ht), 0) as costs_ht,
      count(*) filter (where rl.historical_unit_cost_ht is null) as unknown_lines, count(*) as line_count
    from report_lines rl
  )
  select a.sales_ht, a.costs_ht,
    case when a.unknown_lines > 0 then null else a.sales_ht - a.costs_ht end,
    case when a.unknown_lines > 0 or a.costs_ht = 0 then null else (a.sales_ht - a.costs_ht) / a.costs_ht * 100 end,
    a.line_count, a.unknown_lines
  from aggregates a;
end;
$$;

drop policy if exists article_categories_delete on public.article_categories;
create policy article_categories_delete on public.article_categories
  for delete using (public.is_admin() or public.has_permission('categories', 'delete'));
