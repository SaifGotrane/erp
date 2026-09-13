-- =====================================================================
-- 0028_sub_client_bulk_usage.sql
-- Bulk trimester usage lookup for all sub-clients at once, so the UI can
-- filter/show which sub-clients are still eligible (max 2 uses/trimester)
-- without issuing one RPC call per sub-client.
-- =====================================================================

create or replace function public.get_sub_clients_trimester_usage(
  p_year      int  default null,
  p_trimester text default null
) returns table (sub_client_id uuid, usage_count int)
language plpgsql security definer as $$
declare
  v_year int := coalesce(p_year, extract(year from current_date)::int);
  v_trim text := coalesce(p_trimester,
    case
      when extract(month from current_date) <= 3  then 'Q1'
      when extract(month from current_date) <= 6  then 'Q2'
      when extract(month from current_date) <= 9  then 'Q3'
      else 'Q4'
    end);
begin
  return query
    select
      si.sub_client_id,
      count(*)::int as usage_count
    from public.sale_sub_invoices si
    join public.sales s on s.id = si.sale_id
    where si.sub_client_id is not null
      and extract(year from s.sale_date)::int = v_year
      and (
        case
          when extract(month from s.sale_date) <= 3  then 'Q1'
          when extract(month from s.sale_date) <= 6  then 'Q2'
          when extract(month from s.sale_date) <= 9  then 'Q3'
          else 'Q4'
        end
      ) = v_trim
    group by si.sub_client_id;
end;
$$;

grant execute on function public.get_sub_clients_trimester_usage(int, text) to authenticated;
