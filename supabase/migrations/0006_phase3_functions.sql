-- =====================================================================
-- Jabnoun ERP — Phase 3 : RPC functions for document numbering,
-- audit logging, and transactional stock operations.
-- All functions are SECURITY DEFINER to bypass RLS for internal writes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- HELPERS
-- ---------------------------------------------------------------------

-- Upsert a stock level delta (can be negative for decreases).
-- Checks allow_negative_stock from company_settings.
create or replace function public.upsert_stock_level(
  p_article_id uuid,
  p_depot_id uuid,
  p_showroom_id uuid,
  p_delta numeric
) returns void
language plpgsql
security definer
as $$
declare
  v_current numeric;
  v_allow_neg boolean;
begin
  if (p_depot_id is null and p_showroom_id is null) or
     (p_depot_id is not null and p_showroom_id is not null) then
    raise exception 'Emplacement invalide : un seul de depot_id / showroom_id doit être renseigné.';
  end if;

  select coalesce(quantity, 0) into v_current
  from public.stock_levels
  where article_id = p_article_id
    and ((p_depot_id is not null and depot_id = p_depot_id) or
         (p_showroom_id is not null and showroom_id = p_showroom_id));

  v_current := coalesce(v_current, 0);

  select allow_negative_stock into v_allow_neg from public.company_settings limit 1;
  v_allow_neg := coalesce(v_allow_neg, false);

  if v_current + p_delta < 0 and not v_allow_neg then
    raise exception 'Stock insuffisant pour cet article (disponible: %, demandé: %).',
      v_current, abs(p_delta);
  end if;

  if exists (
    select 1 from public.stock_levels
    where article_id = p_article_id
      and ((p_depot_id is not null and depot_id = p_depot_id) or
           (p_showroom_id is not null and showroom_id = p_showroom_id))
  ) then
    update public.stock_levels
      set quantity = quantity + p_delta, updated_at = now()
      where article_id = p_article_id
        and ((p_depot_id is not null and depot_id = p_depot_id) or
             (p_showroom_id is not null and showroom_id = p_showroom_id));
  else
    insert into public.stock_levels (article_id, depot_id, showroom_id, quantity)
    values (p_article_id, p_depot_id, p_showroom_id, greatest(p_delta, 0));
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- DOCUMENT NUMBERING
-- ---------------------------------------------------------------------

-- Atomically returns the next document number for a given prefix.
-- Format: PREFIX-YYYY-NNNNNN  (e.g. ACH-2024-000001)
create or replace function public.next_document_number(p_prefix text)
returns text
language plpgsql
security definer
as $$
declare
  v_year int := extract(year from now())::int;
  v_next int;
  v_result text;
begin
  insert into public.document_sequences (prefix, year, last_number)
  values (p_prefix, v_year, 1)
  on conflict (prefix, year)
  do update set last_number = document_sequences.last_number + 1
  returning last_number into v_next;

  v_result := p_prefix || '-' || v_year::text || '-' || lpad(v_next::text, 6, '0');
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------
-- AUDIT LOG
-- ---------------------------------------------------------------------

create or replace function public.write_audit_log(
  p_action text,
  p_module text,
  p_object_type text default null,
  p_object_id uuid default null,
  p_object_label text default null,
  p_old_value jsonb default null,
  p_new_value jsonb default null,
  p_details text default null
) returns void
language plpgsql
security definer
as $$
begin
  insert into public.audit_logs (
    user_id, action, module, object_type, object_id,
    object_label, old_value, new_value, details
  ) values (
    auth.uid(), p_action, p_module, p_object_type, p_object_id,
    p_object_label, p_old_value, p_new_value, p_details
  );
end;
$$;

-- ---------------------------------------------------------------------
-- VALIDATE PURCHASE
-- ---------------------------------------------------------------------

create or replace function public.validate_purchase(p_purchase_id uuid)
returns public.purchases
language plpgsql
security definer
as $$
declare
  v_purchase public.purchases;
  v_line public.purchase_lines;
  v_doc_number text;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('purchases', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les achats.';
  end if;

  select * into v_purchase from public.purchases where id = p_purchase_id for update;

  if not found then
    raise exception 'Achat introuvable.';
  end if;
  if v_purchase.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_purchase.status;
  end if;

  -- Recalculate totals server-side from lines.
  select
    coalesce(sum(line_total_ht), 0),
    coalesce(sum(line_total_tva), 0),
    coalesce(sum(line_total_ttc), 0)
  into v_purchase.total_ht, v_purchase.total_tva, v_purchase.total_ttc
  from public.purchase_lines where purchase_id = p_purchase_id;

  -- Apply global discount if any.
  if v_purchase.discount_percent > 0 then
    v_purchase.discount_amount := round(v_purchase.total_ht * v_purchase.discount_percent / 100, 3);
    v_purchase.total_ht  := v_purchase.total_ht  - v_purchase.discount_amount;
    v_purchase.total_tva := round(v_purchase.total_ht * (
      case when v_purchase.total_ht > 0
           then v_purchase.total_tva / (v_purchase.total_ht + v_purchase.discount_amount)
           else 0 end), 3);
    v_purchase.total_ttc := v_purchase.total_ht + v_purchase.total_tva;
  end if;

  update public.purchases set
    status = 'valide',
    total_ht = v_purchase.total_ht,
    total_tva = v_purchase.total_tva,
    total_ttc = v_purchase.total_ttc,
    discount_amount = v_purchase.discount_amount,
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_purchase_id;

  -- Create stock entries and movements for each line.
  for v_line in select * from public.purchase_lines where purchase_id = p_purchase_id loop
    perform public.upsert_stock_level(v_line.article_id, v_purchase.depot_id, null, v_line.quantity);

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      destination_depot_id, destination_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'entree', v_line.quantity,
      v_purchase.depot_id, 'Achat ' || v_purchase.document_number,
      'achat', p_purchase_id, v_purchase.document_number, auth.uid()
    );
  end loop;

  perform public.write_audit_log(
    'validate', 'purchases', 'purchase', p_purchase_id,
    v_purchase.document_number, null, null,
    'Achat validé: ' || v_purchase.document_number
  );

  select * into v_purchase from public.purchases where id = p_purchase_id;
  return v_purchase;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL PURCHASE
-- ---------------------------------------------------------------------

create or replace function public.cancel_purchase(p_purchase_id uuid)
returns public.purchases
language plpgsql
security definer
as $$
declare
  v_purchase public.purchases;
  v_line public.purchase_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('purchases', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les achats.';
  end if;

  select * into v_purchase from public.purchases where id = p_purchase_id for update;

  if not found then
    raise exception 'Achat introuvable.';
  end if;
  if v_purchase.status = 'annule' then
    raise exception 'Cet achat est déjà annulé.';
  end if;
  if v_purchase.status = 'paye' then
    raise exception 'Impossible d''annuler un achat entièrement payé.';
  end if;

  -- Reverse stock if the purchase was validated.
  if v_purchase.status in ('valide', 'partiellement_paye') then
    for v_line in select * from public.purchase_lines where purchase_id = p_purchase_id loop
      perform public.upsert_stock_level(v_line.article_id, v_purchase.depot_id, null, -v_line.quantity);

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        source_depot_id, source_label,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'retour_fournisseur', v_line.quantity,
        v_purchase.depot_id, 'Annulation achat ' || v_purchase.document_number,
        'achat', p_purchase_id, v_purchase.document_number, auth.uid()
      );
    end loop;
  end if;

  update public.purchases set status = 'annule' where id = p_purchase_id;

  perform public.write_audit_log(
    'cancel', 'purchases', 'purchase', p_purchase_id,
    v_purchase.document_number, null, null,
    'Achat annulé: ' || v_purchase.document_number
  );

  select * into v_purchase from public.purchases where id = p_purchase_id;
  return v_purchase;
end;
$$;

-- ---------------------------------------------------------------------
-- VALIDATE TRANSFER
-- ---------------------------------------------------------------------

create or replace function public.validate_transfer(p_transfer_id uuid)
returns public.stock_transfers
language plpgsql
security definer
as $$
declare
  v_transfer public.stock_transfers;
  v_line public.stock_transfer_lines;
  v_src_depot uuid;
  v_src_showroom uuid;
  v_dst_depot uuid;
  v_dst_showroom uuid;
  v_src_label text;
  v_dst_label text;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('transfers', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les transferts.';
  end if;

  select * into v_transfer from public.stock_transfers where id = p_transfer_id for update;

  if not found then
    raise exception 'Transfert introuvable.';
  end if;
  if v_transfer.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_transfer.status;
  end if;

  v_src_depot := v_transfer.source_depot_id;
  v_src_showroom := v_transfer.source_showroom_id;
  v_dst_depot := v_transfer.destination_depot_id;
  v_dst_showroom := v_transfer.destination_showroom_id;

  select name into v_src_label from public.depots where id = v_src_depot;
  if v_src_label is null then
    select name into v_src_label from public.showrooms where id = v_src_showroom;
  end if;

  select name into v_dst_label from public.depots where id = v_dst_depot;
  if v_dst_label is null then
    select name into v_dst_label from public.showrooms where id = v_dst_showroom;
  end if;

  for v_line in select * from public.stock_transfer_lines where transfer_id = p_transfer_id loop
    -- Decrease source.
    perform public.upsert_stock_level(v_line.article_id, v_src_depot, v_src_showroom, -v_line.quantity);
    -- Increase destination.
    perform public.upsert_stock_level(v_line.article_id, v_dst_depot, v_dst_showroom, v_line.quantity);

    insert into public.stock_movements (
      article_id, movement_type, quantity,
      source_depot_id, source_showroom_id, source_label,
      destination_depot_id, destination_showroom_id, destination_label,
      document_type, document_id, document_number, created_by
    ) values (
      v_line.article_id, 'transfert', v_line.quantity,
      v_src_depot, v_src_showroom, v_src_label,
      v_dst_depot, v_dst_showroom, v_dst_label,
      'transfert', p_transfer_id, v_transfer.document_number, auth.uid()
    );
  end loop;

  update public.stock_transfers set
    status = 'valide',
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_transfer_id;

  perform public.write_audit_log(
    'validate', 'transfers', 'transfer', p_transfer_id,
    v_transfer.document_number, null, null,
    'Transfert validé: ' || v_transfer.document_number
  );

  select * into v_transfer from public.stock_transfers where id = p_transfer_id;
  return v_transfer;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL TRANSFER
-- ---------------------------------------------------------------------

create or replace function public.cancel_transfer(p_transfer_id uuid)
returns public.stock_transfers
language plpgsql
security definer
as $$
declare
  v_transfer public.stock_transfers;
  v_line public.stock_transfer_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('transfers', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les transferts.';
  end if;

  select * into v_transfer from public.stock_transfers where id = p_transfer_id for update;

  if not found then
    raise exception 'Transfert introuvable.';
  end if;
  if v_transfer.status = 'annule' then
    raise exception 'Ce transfert est déjà annulé.';
  end if;
  if v_transfer.status = 'valide' then
    -- Reverse stock movements.
    for v_line in select * from public.stock_transfer_lines where transfer_id = p_transfer_id loop
      perform public.upsert_stock_level(v_line.article_id, v_transfer.destination_depot_id, v_transfer.destination_showroom_id, -v_line.quantity);
      perform public.upsert_stock_level(v_line.article_id, v_transfer.source_depot_id, v_transfer.source_showroom_id, v_line.quantity);

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        source_depot_id, source_showroom_id,
        destination_depot_id, destination_showroom_id,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'transfert', v_line.quantity,
        v_transfer.destination_depot_id, v_transfer.destination_showroom_id,
        v_transfer.source_depot_id, v_transfer.source_showroom_id,
        'transfert', p_transfer_id, v_transfer.document_number, auth.uid()
      );
    end loop;
  end if;

  update public.stock_transfers set status = 'annule' where id = p_transfer_id;

  perform public.write_audit_log(
    'cancel', 'transfers', 'transfer', p_transfer_id,
    v_transfer.document_number, null, null,
    'Transfert annulé: ' || v_transfer.document_number
  );

  select * into v_transfer from public.stock_transfers where id = p_transfer_id;
  return v_transfer;
end;
$$;

-- ---------------------------------------------------------------------
-- VALIDATE INVENTORY
-- ---------------------------------------------------------------------

create or replace function public.validate_inventory(p_inventory_id uuid)
returns public.inventory_counts
language plpgsql
security definer
as $$
declare
  v_inventory public.inventory_counts;
  v_line public.inventory_lines;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('inventories', 'validate')) then
    raise exception 'Vous n''avez pas le droit de valider les inventaires.';
  end if;

  select * into v_inventory from public.inventory_counts where id = p_inventory_id for update;

  if not found then
    raise exception 'Inventaire introuvable.';
  end if;
  if v_inventory.status != 'brouillon' then
    raise exception 'Seul un brouillon peut être validé (statut actuel: %).', v_inventory.status;
  end if;

  for v_line in select * from public.inventory_lines where inventory_id = p_inventory_id loop
    -- Recalculate gap server-side.
    v_line.gap := v_line.real_quantity - v_line.theoretical_quantity;

    update public.inventory_lines set
      theoretical_quantity = v_line.theoretical_quantity,
      real_quantity = v_line.real_quantity,
      gap = v_line.gap
    where id = v_line.id;

    if v_line.gap != 0 then
      perform public.upsert_stock_level(
        v_line.article_id, v_inventory.depot_id, v_inventory.showroom_id, v_line.gap
      );

      insert into public.stock_movements (
        article_id, movement_type, quantity,
        source_depot_id, source_showroom_id,
        destination_depot_id, destination_showroom_id,
        document_type, document_id, document_number, created_by
      ) values (
        v_line.article_id, 'inventaire', v_line.gap,
        case when v_line.gap < 0 then v_inventory.depot_id end,
        case when v_line.gap < 0 then v_inventory.showroom_id end,
        case when v_line.gap > 0 then v_inventory.depot_id end,
        case when v_line.gap > 0 then v_inventory.showroom_id end,
        'inventaire', p_inventory_id, v_inventory.document_number, auth.uid()
      );
    end if;
  end loop;

  update public.inventory_counts set
    status = 'valide',
    validated_by = auth.uid(),
    validated_at = now()
  where id = p_inventory_id;

  perform public.write_audit_log(
    'validate', 'inventories', 'inventory', p_inventory_id,
    v_inventory.document_number, null, null,
    'Inventaire validé: ' || v_inventory.document_number
  );

  select * into v_inventory from public.inventory_counts where id = p_inventory_id;
  return v_inventory;
end;
$$;

-- ---------------------------------------------------------------------
-- CANCEL INVENTORY
-- ---------------------------------------------------------------------

create or replace function public.cancel_inventory(p_inventory_id uuid)
returns public.inventory_counts
language plpgsql
security definer
as $$
declare
  v_inventory public.inventory_counts;
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;
  if not (public.is_admin() or public.has_permission('inventories', 'cancel')) then
    raise exception 'Vous n''avez pas le droit d''annuler les inventaires.';
  end if;

  select * into v_inventory from public.inventory_counts where id = p_inventory_id for update;

  if not found then
    raise exception 'Inventaire introuvable.';
  end if;
  if v_inventory.status = 'annule' then
    raise exception 'Cet inventaire est déjà annulé.';
  end if;
  if v_inventory.status = 'valide' then
    raise exception 'Impossible d''annuler un inventaire déjà validé.';
  end if;

  update public.inventory_counts set status = 'annule' where id = p_inventory_id;

  perform public.write_audit_log(
    'cancel', 'inventories', 'inventory', p_inventory_id,
    v_inventory.document_number, null, null,
    'Inventaire annulé: ' || v_inventory.document_number
  );

  select * into v_inventory from public.inventory_counts where id = p_inventory_id;
  return v_inventory;
end;
$$;

-- ---------------------------------------------------------------------
-- FETCH THEORETICAL STOCK for inventory (helper for the UI)
-- Returns article_id, article reference, designation, current quantity
-- for a given depot or showroom.
-- ---------------------------------------------------------------------

create or replace function public.fetch_theoretical_stock(
  p_depot_id uuid default null,
  p_showroom_id uuid default null
) returns table (
  article_id uuid,
  reference text,
  designation text,
  theoretical_quantity numeric
)
language plpgsql
security definer
as $$
begin
  if not public.is_active_employee() then
    raise exception 'Accès refusé.';
  end if;

  return query
  select
    a.id as article_id,
    a.reference,
    a.designation,
    coalesce(sl.quantity, 0) as theoretical_quantity
  from public.articles a
  left join public.stock_levels sl
    on sl.article_id = a.id
    and ((p_depot_id is not null and sl.depot_id = p_depot_id) or
         (p_showroom_id is not null and sl.showroom_id = p_showroom_id))
  where a.active = true
  order by a.designation;
end;
$$;
