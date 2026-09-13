-- Client sub-invoices: a main sale (invoice) can be split into several
-- sub-invoices, each attributed to a sub-client (an existing customer or a
-- freeform name), as long as the sum never exceeds the main invoice total.

create table if not exists public.sale_sub_invoices (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  document_number text not null unique,
  sub_client_name text not null,
  customer_id uuid references public.customers(id),
  amount numeric(14,3) not null check (amount > 0),
  notes text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_sale_sub_invoices_sale on public.sale_sub_invoices (sale_id);

alter table public.sale_sub_invoices enable row level security;

create policy sale_sub_invoices_read on public.sale_sub_invoices
  for select using (public.is_admin() or public.has_permission('sub_invoices', 'view'));

-- No direct insert/update/delete policies: writes only via SECURITY DEFINER
-- functions below, which enforce the allocation constraint server-side.

-- ---------------------------------------------------------------------
-- add_sale_sub_invoice: creates one sub-invoice, rejecting the operation
-- if it would push the allocated total above the main invoice's total_ttc.
-- ---------------------------------------------------------------------

create or replace function public.add_sale_sub_invoice(
  p_sale_id uuid,
  p_sub_client_name text,
  p_amount numeric,
  p_customer_id uuid default null,
  p_notes text default null
) returns public.sale_sub_invoices
language plpgsql security definer as $$
declare
  v_sale public.sales;
  v_allocated numeric;
  v_doc_number text;
  v_seq int;
  v_row public.sale_sub_invoices;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sub_invoices', 'create')) then
    raise exception 'Vous n''avez pas le droit de créer des sous-factures.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Le montant de la sous-facture doit être positif.';
  end if;
  if p_sub_client_name is null or trim(p_sub_client_name) = '' then
    raise exception 'Le nom du sous-client est requis.';
  end if;

  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then raise exception 'Vente introuvable.'; end if;

  select coalesce(sum(amount), 0) into v_allocated
  from public.sale_sub_invoices where sale_id = p_sale_id;

  if v_allocated + p_amount > v_sale.total_ttc + 0.001 then
    raise exception 'Montant refusé : le total des sous-factures (% ) dépasserait le montant de la facture principale (%).',
      round(v_allocated + p_amount, 3), v_sale.total_ttc;
  end if;

  select count(*) into v_seq from public.sale_sub_invoices where sale_id = p_sale_id;
  v_doc_number := v_sale.document_number || '-S' || (v_seq + 1)::text;

  insert into public.sale_sub_invoices (sale_id, document_number, sub_client_name, customer_id, amount, notes, created_by)
  values (p_sale_id, v_doc_number, trim(p_sub_client_name), p_customer_id, p_amount, nullif(trim(p_notes), ''), auth.uid())
  returning * into v_row;

  perform public.write_audit_log('create', 'sub_invoices', 'sale_sub_invoice', v_row.id, v_row.document_number, null, null,
    'Sous-facture créée pour ' || v_sale.document_number || ' : ' || v_row.sub_client_name || ' (' || v_row.amount || ')');

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- delete_sale_sub_invoice: removes an allocation (frees up the amount).
-- ---------------------------------------------------------------------

create or replace function public.delete_sale_sub_invoice(p_id uuid)
returns void language plpgsql security definer as $$
declare v_row public.sale_sub_invoices;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sub_invoices', 'edit')) then
    raise exception 'Vous n''avez pas le droit de supprimer des sous-factures.';
  end if;
  select * into v_row from public.sale_sub_invoices where id = p_id;
  if not found then raise exception 'Sous-facture introuvable.'; end if;
  delete from public.sale_sub_invoices where id = p_id;
  perform public.write_audit_log('delete', 'sub_invoices', 'sale_sub_invoice', v_row.id, v_row.document_number, null, null,
    'Sous-facture supprimée : ' || v_row.document_number);
end;
$$;
