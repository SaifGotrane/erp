-- =====================================================================
-- 0025_sub_clients.sql
-- Real sub-clients (real persons with CIN) + sub-invoice article lines.
-- Replaces the old "random name" approach with a managed registry of
-- real persons.  Sub-invoices now carry whole article lines (not just
-- a flat amount), enforce 5000 TND max, and limit usage per trimester.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. sub_clients table — registry of real persons managed by the user
-- ---------------------------------------------------------------------
create table if not exists public.sub_clients (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  cin         text not null,           -- carte d'identité nationale
  phone       text,
  address     text,
  active      boolean not null default true,
  created_by  uuid references public.employees(id),
  created_at  timestamptz not null default now()
);

create index if not exists idx_sub_clients_name on public.sub_clients(name);
create unique index if not exists uniq_sub_clients_cin on public.sub_clients(lower(trim(cin)));

alter table public.sub_clients enable row level security;

drop policy if exists sub_clients_read   on public.sub_clients;
drop policy if exists sub_clients_insert on public.sub_clients;
drop policy if exists sub_clients_update on public.sub_clients;
drop policy if exists sub_clients_delete on public.sub_clients;

create policy sub_clients_read   on public.sub_clients for select using (public.is_admin() or public.has_permission('sub_clients', 'view'));
create policy sub_clients_insert on public.sub_clients for insert with check (public.is_admin() or public.has_permission('sub_clients', 'create'));
create policy sub_clients_update on public.sub_clients for update using (public.is_admin() or public.has_permission('sub_clients', 'edit'));
create policy sub_clients_delete on public.sub_clients for delete using (public.is_admin() or public.has_permission('sub_clients', 'delete'));

-- ---------------------------------------------------------------------
-- 2. sale_sub_invoice_lines — article lines belonging to a sub-invoice
-- ---------------------------------------------------------------------
create table if not exists public.sale_sub_invoice_lines (
  id                  uuid primary key default gen_random_uuid(),
  sub_invoice_id      uuid not null references public.sale_sub_invoices(id) on delete cascade,
  sale_line_id        uuid not null references public.sale_lines(id) on delete cascade,
  article_id          uuid not null references public.articles(id),
  quantity            integer not null check (quantity > 0),
  unit_price_ht       numeric(14,3) not null,
  tax_rate_percent    numeric(5,2) not null default 0,
  line_total_ht       numeric(14,3) not null default 0,
  line_total_tva      numeric(14,3) not null default 0,
  line_total_ttc      numeric(14,3) not null default 0
);

create index if not exists idx_sub_invoice_lines_sub on public.sale_sub_invoice_lines(sub_invoice_id);

alter table public.sale_sub_invoice_lines enable row level security;

drop policy if exists sub_invoice_lines_read on public.sale_sub_invoice_lines;

create policy sub_invoice_lines_read on public.sale_sub_invoice_lines
  for select using (public.is_active_employee());

-- ---------------------------------------------------------------------
-- 3. Add sub_client_id column to sale_sub_invoices
-- ---------------------------------------------------------------------
alter table public.sale_sub_invoices
  add column if not exists sub_client_id uuid references public.sub_clients(id);

-- ---------------------------------------------------------------------
-- 4. RPC: add_sale_sub_invoice_with_lines
--    Creates a sub-invoice with whole article lines.
--    Enforces:
--      a) total ≤ remaining on main invoice
--      b) sub-invoice total ≤ 5000 TND
--      c) sub-client used max 2 times per trimester (globally)
--      d) quantities are whole integers and don't exceed sale line qty
--      e) sum of all sub-invoice line quantities for a given sale_line
--         doesn't exceed the original sale_line quantity
-- ---------------------------------------------------------------------
create or replace function public.add_sale_sub_invoice_with_lines(
  p_sale_id        uuid,
  p_sub_client_id  uuid,
  p_lines          jsonb,   -- [{sale_line_id, quantity}, ...]
  p_notes          text default null
) returns public.sale_sub_invoices
language plpgsql security definer as $$
declare
  v_sale          public.sales;
  v_sub_client    public.sub_clients;
  v_allocated     numeric;
  v_sub_total     numeric := 0;
  v_doc_number    text;
  v_seq           int;
  v_row           public.sale_sub_invoices;
  v_line          jsonb;
  v_sl            public.sale_lines;
  v_qty           int;
  v_already_used  int;
  v_already_alloc  int;
  v_trimester     text;
  v_year          int;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sub_invoices', 'create')) then
    raise exception 'Vous n''avez pas le droit de créer des sous-factures.';
  end if;

  -- Validate sub-client exists and is active
  select * into v_sub_client from public.sub_clients where id = p_sub_client_id;
  if not found then raise exception 'Sous-client introuvable.'; end if;
  if not v_sub_client.active then raise exception 'Ce sous-client est désactivé.'; end if;

  -- Lock the sale
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then raise exception 'Vente introuvable.'; end if;

  -- Validate lines array
  if p_lines is null or jsonb_array_length(p_lines) = 0 then
    raise exception 'Au moins une ligne d''article est requise.';
  end if;

  -- Calculate sub-invoice total and validate quantities
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := (v_line->>'quantity')::int;
    if v_qty is null or v_qty <= 0 then
      raise exception 'La quantité doit être un entier positif.';
    end if;

    select * into v_sl from public.sale_lines where id = (v_line->>'sale_line_id')::uuid;
    if not found then raise exception 'Ligne de vente introuvable.'; end if;
    if v_sl.sale_id <> p_sale_id then
      raise exception 'La ligne ne appartient pas à cette vente.';
    end if;

    -- Check that total allocated for this sale_line across all sub-invoices
    -- plus the new quantity doesn't exceed the original sale_line quantity
    select coalesce(sum(sl.quantity), 0) into v_already_alloc
    from public.sale_sub_invoice_lines sl
    join public.sale_sub_invoices si on si.id = sl.sub_invoice_id
    where si.sale_id = p_sale_id and sl.sale_line_id = v_sl.id;

    if v_already_alloc + v_qty > v_sl.quantity then
      raise exception 'Quantité totale pour cet article dépasse la quantité de la ligne de vente (%).',
        v_sl.quantity;
    end if;

    v_sub_total := v_sub_total + round(v_qty * v_sl.unit_price_ht * (1 + v_sl.tax_rate_percent / 100), 3);
  end loop;

  -- Enforce 5000 TND max per sub-invoice
  if v_sub_total > 5000 then
    raise exception 'Le total de la sous-facture (% TND) dépasse la limite de 5000 TND.', v_sub_total;
  end if;

  -- Check total allocation doesn't exceed main invoice
  select coalesce(sum(amount), 0) into v_allocated
  from public.sale_sub_invoices where sale_id = p_sale_id;

  if v_allocated + v_sub_total > v_sale.total_ttc + 0.001 then
    raise exception 'Montant refusé : le total des sous-factures (%) dépasserait le montant de la facture principale (%).',
      round(v_allocated + v_sub_total, 3), v_sale.total_ttc;
  end if;

  -- Trimester usage check (max 2 per trimester, globally across all sales)
  v_year  := extract(year from v_sale.sale_date)::int;
  v_trimester := case
    when extract(month from v_sale.sale_date) <= 3  then 'Q1'
    when extract(month from v_sale.sale_date) <= 6  then 'Q2'
    when extract(month from v_sale.sale_date) <= 9  then 'Q3'
    else 'Q4'
  end;

  select count(*) into v_already_used
  from public.sale_sub_invoices si
  join public.sales s on s.id = si.sale_id
  where si.sub_client_id = p_sub_client_id
    and extract(year from s.sale_date)::int = v_year
    and case
      when extract(month from s.sale_date) <= 3  then 'Q1'
      when extract(month from s.sale_date) <= 6  then 'Q2'
      when extract(month from s.sale_date) <= 9  then 'Q3'
      else 'Q4'
    end = v_trimester;

  if v_already_used >= 2 then
    raise exception 'Ce sous-client a déjà été utilisé % fois ce trimestre (maximum 2 autorisé).', v_already_used;
  end if;

  -- Generate document number
  select count(*) into v_seq from public.sale_sub_invoices where sale_id = p_sale_id;
  v_doc_number := v_sale.document_number || '-S' || (v_seq + 1)::text;

  -- Insert sub-invoice
  insert into public.sale_sub_invoices (sale_id, document_number, sub_client_name, sub_client_id, amount, notes, created_by)
  values (p_sale_id, v_doc_number, v_sub_client.name, p_sub_client_id, v_sub_total, nullif(trim(coalesce(p_notes, '')), ''), auth.uid())
  returning * into v_row;

  -- Insert sub-invoice lines
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_qty := (v_line->>'quantity')::int;
    select * into v_sl from public.sale_lines where id = (v_line->>'sale_line_id')::uuid;

    insert into public.sale_sub_invoice_lines
      (sub_invoice_id, sale_line_id, article_id, quantity, unit_price_ht, tax_rate_percent,
       line_total_ht, line_total_tva, line_total_ttc)
    values
      (v_row.id, v_sl.id, v_sl.article_id, v_qty, v_sl.unit_price_ht, v_sl.tax_rate_percent,
       round(v_qty * v_sl.unit_price_ht, 3),
       round(v_qty * v_sl.unit_price_ht * v_sl.tax_rate_percent / 100, 3),
       round(v_qty * v_sl.unit_price_ht * (1 + v_sl.tax_rate_percent / 100), 3));
  end loop;

  perform public.write_audit_log('create', 'sub_invoices', 'sale_sub_invoice', v_row.id, v_row.document_number, null, null,
    'Sous-facture créée pour ' || v_sale.document_number || ' : ' || v_row.sub_client_name || ' (' || v_row.amount || ')');

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. RPC: fetch sub-client trimester usage count
-- ---------------------------------------------------------------------
create or replace function public.get_sub_client_trimester_usage(
  p_sub_client_id uuid,
  p_year  int default null,
  p_trimester text default null
) returns table (year int, trimester text, usage_count int)
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
      extract(year from s.sale_date)::int as year,
      case
        when extract(month from s.sale_date) <= 3  then 'Q1'
        when extract(month from s.sale_date) <= 6  then 'Q2'
        when extract(month from s.sale_date) <= 9  then 'Q3'
        else 'Q4'
      end as trimester,
      count(*)::int as usage_count
    from public.sale_sub_invoices si
    join public.sales s on s.id = si.sale_id
    where si.sub_client_id = p_sub_client_id
      and extract(year from s.sale_date)::int = v_year
    group by 1, 2
    order by 1, 2;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. Grant permissions
-- ---------------------------------------------------------------------
grant select, insert, update, delete on public.sub_clients to authenticated;
grant select, insert on public.sale_sub_invoice_lines to authenticated;
