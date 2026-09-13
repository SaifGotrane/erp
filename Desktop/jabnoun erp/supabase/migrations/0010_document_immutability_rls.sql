-- Prevent client-side changes to documents after their draft workflow.
-- SECURITY DEFINER validation/cancellation RPCs remain the only transition path.

create or replace function public.is_draft_document(p_status text)
returns boolean language sql immutable as $$ select p_status = 'brouillon' $$;

drop policy if exists purchases_update on public.purchases;
drop policy if exists purchases_delete on public.purchases;
drop policy if exists purchases_insert on public.purchases;
drop policy if exists purchases_insert_draft on public.purchases;
drop policy if exists purchases_update_draft on public.purchases;
drop policy if exists purchases_delete_draft on public.purchases;
create policy purchases_insert_draft on public.purchases for insert
  with check (public.is_draft_document(status) and (public.is_admin() or public.has_permission('purchases', 'create')));
create policy purchases_update on public.purchases for update
  using (public.is_draft_document(status) and (public.is_admin() or public.has_permission('purchases', 'edit')))
  with check (public.is_draft_document(status) and (public.is_admin() or public.has_permission('purchases', 'edit')));
create policy purchases_delete on public.purchases for delete
  using (public.is_draft_document(status) and (public.is_admin() or public.has_permission('purchases', 'delete')));

drop policy if exists purchase_lines_update on public.purchase_lines;
drop policy if exists purchase_lines_delete on public.purchase_lines;
drop policy if exists purchase_lines_insert on public.purchase_lines;
drop policy if exists purchase_lines_insert_draft on public.purchase_lines;
drop policy if exists purchase_lines_update_draft on public.purchase_lines;
drop policy if exists purchase_lines_delete_draft on public.purchase_lines;
create policy purchase_lines_insert_draft on public.purchase_lines for insert with check (
  exists (select 1 from public.purchases p where p.id = purchase_lines.purchase_id and public.is_draft_document(p.status))
  and (public.is_admin() or public.has_permission('purchases', 'create'))
);
create policy purchase_lines_update on public.purchase_lines for update using (
  exists (select 1 from public.purchases p where p.id = purchase_lines.purchase_id and public.is_draft_document(p.status))
  and (public.is_admin() or public.has_permission('purchases', 'edit'))
) with check (
  exists (select 1 from public.purchases p where p.id = purchase_lines.purchase_id and public.is_draft_document(p.status))
  and (public.is_admin() or public.has_permission('purchases', 'edit'))
);
create policy purchase_lines_delete on public.purchase_lines for delete using (
  exists (select 1 from public.purchases p where p.id = purchase_lines.purchase_id and public.is_draft_document(p.status))
  and (public.is_admin() or public.has_permission('purchases', 'edit'))
);

do $$
declare
  header_table text;
  line_table text;
  permission_module text;
  foreign_key_column text;
  legacy_header_prefix text;
  legacy_line_prefix text;
begin
  for header_table, line_table, permission_module, foreign_key_column, legacy_header_prefix, legacy_line_prefix in
    select * from (values
      ('sales', 'sale_lines', 'sales', 'sale_id', 'sales', 'sale_lines'),
      ('delivery_notes', 'delivery_note_lines', 'delivery_notes', 'delivery_note_id', 'delivery', 'delivery_lines'),
      ('supplier_returns', 'supplier_return_lines', 'supplier_returns', 'supplier_return_id', 'supplier_returns', 'supplier_return_lines'),
      ('customer_returns', 'customer_return_lines', 'customer_returns', 'customer_return_id', 'customer_returns', 'customer_return_lines'),
      ('stock_transfers', 'stock_transfer_lines', 'transfers', 'transfer_id', 'transfers', 'transfer_lines'),
      ('inventory_counts', 'inventory_lines', 'inventories', 'inventory_id', 'inventories', 'inventory_lines'),
      ('stock_adjustments', 'stock_adjustment_lines', 'adjustments', 'adjustment_id', 'adjustments', 'adjustment_lines')
    ) as documents(header_table, line_table, permission_module, foreign_key_column, legacy_header_prefix, legacy_line_prefix)
  loop
    execute format('drop policy if exists %I on public.%I', header_table || '_write', header_table);
    execute format('drop policy if exists %I on public.%I', header_table || '_update', header_table);
    execute format('drop policy if exists %I on public.%I', header_table || '_delete', header_table);
    execute format('drop policy if exists %I on public.%I', header_table || '_insert_draft', header_table);
    execute format('drop policy if exists %I on public.%I', header_table || '_update_draft', header_table);
    execute format('drop policy if exists %I on public.%I', header_table || '_delete_draft', header_table);
    execute format('drop policy if exists %I on public.%I', legacy_header_prefix || '_write', header_table);
    execute format('drop policy if exists %I on public.%I', legacy_header_prefix || '_insert', header_table);
    execute format('drop policy if exists %I on public.%I', legacy_header_prefix || '_update', header_table);
    execute format('drop policy if exists %I on public.%I', legacy_header_prefix || '_delete', header_table);
    execute format('create policy %I on public.%I for insert with check (public.is_draft_document(status) and (public.is_admin() or public.has_permission(%L, ''create'')))', header_table || '_insert_draft', header_table, permission_module);
    execute format('create policy %I on public.%I for update using (public.is_draft_document(status) and (public.is_admin() or public.has_permission(%L, ''edit''))) with check (public.is_draft_document(status) and (public.is_admin() or public.has_permission(%L, ''edit'')))', header_table || '_update_draft', header_table, permission_module, permission_module);
    execute format('create policy %I on public.%I for delete using (public.is_draft_document(status) and (public.is_admin() or public.has_permission(%L, ''delete'')))', header_table || '_delete_draft', header_table, permission_module);
    execute format('drop policy if exists %I on public.%I', line_table || '_write', line_table);
    execute format('drop policy if exists %I on public.%I', line_table || '_update', line_table);
    execute format('drop policy if exists %I on public.%I', line_table || '_delete', line_table);
    execute format('drop policy if exists %I on public.%I', line_table || '_insert_draft', line_table);
    execute format('drop policy if exists %I on public.%I', line_table || '_update_draft', line_table);
    execute format('drop policy if exists %I on public.%I', line_table || '_delete_draft', line_table);
    execute format('drop policy if exists %I on public.%I', legacy_line_prefix || '_write', line_table);
    execute format('drop policy if exists %I on public.%I', legacy_line_prefix || '_insert', line_table);
    execute format('drop policy if exists %I on public.%I', legacy_line_prefix || '_update', line_table);
    execute format('drop policy if exists %I on public.%I', legacy_line_prefix || '_delete', line_table);
    execute format('create policy %I on public.%I for insert with check (exists (select 1 from public.%I h where h.id = %I.%I and public.is_draft_document(h.status)) and (public.is_admin() or public.has_permission(%L, ''create'')))', line_table || '_insert_draft', line_table, header_table, line_table, foreign_key_column, permission_module);
    execute format('create policy %I on public.%I for update using (exists (select 1 from public.%I h where h.id = %I.%I and public.is_draft_document(h.status)) and (public.is_admin() or public.has_permission(%L, ''edit''))) with check (exists (select 1 from public.%I h where h.id = %I.%I and public.is_draft_document(h.status)) and (public.is_admin() or public.has_permission(%L, ''edit'')))', line_table || '_update_draft', line_table, header_table, line_table, foreign_key_column, permission_module, header_table, line_table, foreign_key_column, permission_module);
    execute format('create policy %I on public.%I for delete using (exists (select 1 from public.%I h where h.id = %I.%I and public.is_draft_document(h.status)) and (public.is_admin() or public.has_permission(%L, ''edit'')))', line_table || '_delete_draft', line_table, header_table, line_table, foreign_key_column, permission_module);
  end loop;
end $$;
