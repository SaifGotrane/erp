-- Service Après-Vente (SAV): ticket-based support workflow.

do $$ begin
  create type public.sav_status as enum ('ouvert', 'en_cours', 'en_attente_fournisseur', 'resolu', 'termine');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.sav_resolution_type as enum ('remplacement', 'reparation', 'autre');
exception when duplicate_object then null; end $$;

create table if not exists public.sav_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number text not null unique,
  customer_id uuid not null references public.customers(id),
  article_id uuid not null references public.articles(id),
  supplier_id uuid references public.suppliers(id),
  issue_description text not null,
  reclamation_date date not null default current_date,
  status public.sav_status not null default 'ouvert',
  resolution_type public.sav_resolution_type,
  resolution_notes text,
  resolution_date date,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sav_tickets_customer on public.sav_tickets (customer_id);
create index if not exists idx_sav_tickets_supplier on public.sav_tickets (supplier_id);
create index if not exists idx_sav_tickets_article on public.sav_tickets (article_id);
create index if not exists idx_sav_tickets_status on public.sav_tickets (status);

create table if not exists public.sav_ticket_notes (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.sav_tickets(id) on delete cascade,
  note text not null,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_sav_ticket_notes_ticket on public.sav_ticket_notes (ticket_id);

alter table public.sav_tickets enable row level security;
alter table public.sav_ticket_notes enable row level security;

create policy sav_tickets_select on public.sav_tickets
  for select using (public.is_admin() or public.has_permission('sav', 'view'));

create policy sav_tickets_insert on public.sav_tickets
  for insert with check (public.is_admin() or public.has_permission('sav', 'create'));

-- Regular edits (status progression, reassigning supplier, editing the
-- description...) require 'edit'. Explicit resolution is handled by the
-- resolve_sav_ticket() function below, which requires 'resolve' instead,
-- so that "closing" a ticket is a distinct, auditable permission.
create policy sav_tickets_update on public.sav_tickets
  for update using (public.is_admin() or public.has_permission('sav', 'edit'))
  with check (public.is_admin() or public.has_permission('sav', 'edit'));

create policy sav_ticket_notes_select on public.sav_ticket_notes
  for select using (public.is_admin() or public.has_permission('sav', 'view'));

create policy sav_ticket_notes_insert on public.sav_ticket_notes
  for insert with check (
    public.is_admin() or public.has_permission('sav', 'create') or public.has_permission('sav', 'edit')
  );

create or replace function public.next_sav_ticket_number()
returns text language plpgsql security definer as $$
declare v_number text;
begin
  v_number := 'SAV-' || to_char(now(), 'YYYY') || '-' || lpad((
    select count(*) + 1 from public.sav_tickets where extract(year from created_at) = extract(year from now())
  )::text, 4, '0');
  return v_number;
end;
$$;

-- resolve_sav_ticket: the only way to move a ticket to 'resolu'. Requires
-- the dedicated 'resolve' permission and always records the resolution
-- date explicitly (never inferred from elapsed time — see §4.3).
create or replace function public.resolve_sav_ticket(
  p_ticket_id uuid,
  p_resolution_type public.sav_resolution_type,
  p_resolution_notes text default null
) returns public.sav_tickets language plpgsql security definer as $$
declare v_ticket public.sav_tickets;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sav', 'resolve')) then
    raise exception 'Vous n''avez pas le droit de résoudre les tickets SAV.';
  end if;
  select * into v_ticket from public.sav_tickets where id = p_ticket_id for update;
  if not found then raise exception 'Ticket SAV introuvable.'; end if;
  if p_resolution_type is null then raise exception 'Le type de résolution est requis.'; end if;

  update public.sav_tickets set
    status = 'resolu',
    resolution_type = p_resolution_type,
    resolution_notes = nullif(trim(p_resolution_notes), ''),
    resolution_date = current_date,
    updated_at = now()
  where id = p_ticket_id;

  perform public.write_audit_log('resolve', 'sav', 'sav_ticket', p_ticket_id, v_ticket.ticket_number, null, null,
    'Ticket SAV résolu : ' || v_ticket.ticket_number || ' (' || p_resolution_type::text || ')');

  select * into v_ticket from public.sav_tickets where id = p_ticket_id;
  return v_ticket;
end;
$$;

-- close_sav_ticket: final, explicit confirmation that closes an already
-- resolved ticket. Never triggered automatically by elapsed time.
create or replace function public.close_sav_ticket(p_ticket_id uuid)
returns public.sav_tickets language plpgsql security definer as $$
declare v_ticket public.sav_tickets;
begin
  if not public.is_active_employee() then raise exception 'Accès refusé.'; end if;
  if not (public.is_admin() or public.has_permission('sav', 'resolve')) then
    raise exception 'Vous n''avez pas le droit de clôturer les tickets SAV.';
  end if;
  select * into v_ticket from public.sav_tickets where id = p_ticket_id for update;
  if not found then raise exception 'Ticket SAV introuvable.'; end if;
  if v_ticket.status != 'resolu' then
    raise exception 'Seul un ticket résolu peut être clôturé (statut actuel: %).', v_ticket.status;
  end if;

  update public.sav_tickets set status = 'termine', updated_at = now() where id = p_ticket_id;

  perform public.write_audit_log('close', 'sav', 'sav_ticket', p_ticket_id, v_ticket.ticket_number, null, null,
    'Ticket SAV clôturé : ' || v_ticket.ticket_number);

  select * into v_ticket from public.sav_tickets where id = p_ticket_id;
  return v_ticket;
end;
$$;
