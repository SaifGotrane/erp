create or replace function public.report_sales_summary(p_from date default null, p_to date default null)
returns table (total_sales numeric, total_ht numeric, total_tva numeric, total_ttc numeric, total_paid numeric, total_unpaid numeric, sales_count bigint)
language plpgsql security definer as $$
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  return query select
    coalesce(sum(s.total_ttc), 0), coalesce(sum(s.total_ht), 0),
    coalesce(sum(s.total_tva), 0), coalesce(sum(s.total_ttc), 0),
    coalesce(sum(s.amount_paid), 0), coalesce(sum(s.total_ttc - s.amount_paid), 0), count(*)
  from public.sales s
  where s.status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or s.sale_date >= p_from)
    and (p_to is null or s.sale_date <= p_to);
end;
$$;

create or replace function public.report_purchases_summary(p_from date default null, p_to date default null)
returns table (total_purchases numeric, total_ht numeric, total_tva numeric, total_ttc numeric, total_paid numeric, total_unpaid numeric, purchases_count bigint)
language plpgsql security definer as $$
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  return query select
    coalesce(sum(p.total_ttc), 0), coalesce(sum(p.total_ht), 0),
    coalesce(sum(p.total_tva), 0), coalesce(sum(p.total_ttc), 0),
    coalesce(sum(p.amount_paid), 0), coalesce(sum(p.total_ttc - p.amount_paid), 0), count(*)
  from public.purchases p
  where p.status in ('valide', 'partiellement_paye', 'paye')
    and (p_from is null or p.purchase_date >= p_from)
    and (p_to is null or p.purchase_date <= p_to);
end;
$$;
