-- =====================================================================
-- 0031_brands_purchase_adjustments.sql
-- 1) Ajoute les marques (brands) au catalogue articles, en complément de
--    l'unité existante (non supprimée : les articles déjà saisis gardent
--    leur unit_id intact, seul le formulaire affiche désormais "Marque").
-- 2) Permet d'ajuster manuellement le total d'un achat avant validation
--    (arrondi) et d'ajouter un droit de timbre fiscal de 1 TND optionnel.
-- =====================================================================

-- ---------------------------------------------------------------------
-- MARQUES
-- ---------------------------------------------------------------------

create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.articles add column if not exists brand_id uuid references public.brands(id);

alter table public.brands enable row level security;

drop policy if exists brands_select on public.brands;
create policy brands_select on public.brands for select using (public.is_active_employee());

drop policy if exists brands_insert on public.brands;
create policy brands_insert on public.brands for insert with check (public.is_admin() or public.has_permission('categories', 'create'));

drop policy if exists brands_update on public.brands;
create policy brands_update on public.brands for update using (public.is_admin() or public.has_permission('categories', 'edit')) with check (public.is_admin() or public.has_permission('categories', 'edit'));

drop policy if exists brands_delete on public.brands;
create policy brands_delete on public.brands for delete using (public.is_admin() or public.has_permission('categories', 'delete'));

-- ---------------------------------------------------------------------
-- ACHATS : ajustement d'arrondi + droit de timbre
-- ---------------------------------------------------------------------

alter table public.purchases
  add column if not exists rounding_adjustment numeric(10,3) not null default 0,
  add column if not exists stamp_duty_amount numeric(10,3) not null default 0;

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
  -- Ajoute le droit de timbre fiscal et l'ajustement d'arrondi saisis par
  -- l'utilisateur sur le brouillon (non soumis à la TVA, non remisés).
  v_purchase.total_ttc := v_purchase.total_ttc + coalesce(v_purchase.stamp_duty_amount, 0) + coalesce(v_purchase.rounding_adjustment, 0);
  for v_line in select * from public.purchase_lines where purchase_id=p_purchase_id loop
    v_unit_cost := round((v_line.line_total_ht / nullif(v_line.quantity,0)) * (1 - v_purchase.discount_percent / 100), 3);
    perform public.upsert_stock_level(v_line.article_id,v_purchase.depot_id,null,v_line.quantity,v_unit_cost);
    insert into public.stock_movements (article_id,movement_type,quantity,destination_depot_id,destination_label,document_type,document_id,document_number,created_by)
    values (v_line.article_id,'entree',v_line.quantity,v_purchase.depot_id,'Achat '||v_purchase.document_number,'achat',p_purchase_id,v_purchase.document_number,auth.uid());
  end loop;
  update public.purchases set status='valide',total_ht=v_purchase.total_ht,total_tva=v_purchase.total_tva,total_ttc=v_purchase.total_ttc,discount_amount=v_purchase.discount_amount,rounding_adjustment=v_purchase.rounding_adjustment,stamp_duty_amount=v_purchase.stamp_duty_amount,validated_by=auth.uid(),validated_at=now() where id=p_purchase_id;
  perform public.write_audit_log('validate','purchases','purchase',p_purchase_id,v_purchase.document_number,null,null,'Achat validé: '||v_purchase.document_number);
  select * into v_purchase from public.purchases where id=p_purchase_id; return v_purchase;
end;
$$;
