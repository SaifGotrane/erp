-- Stock valuation must use the location CMUP introduced in 0012. The previous
-- function also excluded every stock level when no location filter was given.
drop function if exists public.upsert_stock_level(uuid, uuid, uuid, numeric);

drop function if exists public.report_stock_valuation(uuid, uuid);

create or replace function public.report_stock_valuation(
  p_depot_id uuid default null,
  p_showroom_id uuid default null
) returns table (
  article_id uuid,
  reference text,
  designation text,
  quantity numeric,
  purchase_price_ht numeric,
  stock_value numeric
)
language plpgsql security definer as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return query
  select
    a.id,
    a.reference,
    a.designation,
    coalesce(sum(sl.quantity), 0),
    case
      when count(*) filter (where sl.quantity <> 0 and sl.unit_cost_ht is null) > 0 then null
      else coalesce(sum(sl.quantity * sl.unit_cost_ht) / nullif(sum(sl.quantity), 0), 0)
    end,
    case
      when count(*) filter (where sl.quantity <> 0 and sl.unit_cost_ht is null) > 0 then null
      else coalesce(sum(sl.quantity * sl.unit_cost_ht), 0)
    end
  from public.articles a
  left join public.stock_levels sl
    on sl.article_id = a.id
    and (
      (p_depot_id is null and p_showroom_id is null)
      or (p_depot_id is not null and sl.depot_id = p_depot_id)
      or (p_showroom_id is not null and sl.showroom_id = p_showroom_id)
    )
  where a.active = true
  group by a.id, a.reference, a.designation, a.purchase_price_ht
  order by a.designation;
end;
$$;
