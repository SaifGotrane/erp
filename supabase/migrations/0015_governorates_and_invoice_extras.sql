-- Governorates (clients/fournisseurs), droit de timbre (1 DT) on sales,
-- and a display-name override for "Particulier" customers on invoices.

-- ---------------------------------------------------------------------
-- GOUVERNORATS TUNISIENS
-- ---------------------------------------------------------------------

do $$ begin
  create type public.tunisian_governorate as enum (
    'Tunis', 'Ariana', 'Ben Arous', 'Manouba', 'Nabeul', 'Zaghouan',
    'Bizerte', 'Béja', 'Jendouba', 'Le Kef', 'Siliana', 'Kairouan',
    'Kasserine', 'Sidi Bouzid', 'Sousse', 'Monastir', 'Mahdia', 'Sfax',
    'Gabès', 'Medenine', 'Tataouine', 'Gafsa', 'Tozeur', 'Kebili'
  );
exception
  when duplicate_object then null;
end $$;

alter table public.customers add column if not exists governorate public.tunisian_governorate;
alter table public.suppliers add column if not exists governorate public.tunisian_governorate;

create index if not exists idx_customers_governorate on public.customers (governorate);
create index if not exists idx_suppliers_governorate on public.suppliers (governorate);

-- ---------------------------------------------------------------------
-- DROIT DE TIMBRE (1 DT) + NOM D'AFFICHAGE POUR CLIENT "PARTICULIER"
-- ---------------------------------------------------------------------

alter table public.sales add column if not exists stamp_duty_amount numeric(10,3) not null default 1.000;
alter table public.sales add column if not exists customer_display_name text;

-- validate_sale: recompute totals from lines, apply document discount, then
-- add the fixed stamp duty (droit de timbre) to the final TTC total. The
-- stamp duty is not subject to TVA and not discounted.
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
  v_sale.stamp_duty_amount := coalesce(v_sale.stamp_duty_amount, 1.000);
  v_sale.total_ttc := v_sale.total_ttc + v_sale.stamp_duty_amount;
  for v_line in select * from public.sale_lines where sale_id = p_sale_id loop
    select unit_cost_ht into v_cost from public.stock_levels where article_id = v_line.article_id
      and ((v_sale.depot_id is not null and depot_id = v_sale.depot_id) or (v_sale.showroom_id is not null and showroom_id = v_sale.showroom_id)) for update;
    if v_cost is null then raise exception 'Coût CMUP indisponible pour l''article % à cet emplacement.', v_line.article_id; end if;
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
