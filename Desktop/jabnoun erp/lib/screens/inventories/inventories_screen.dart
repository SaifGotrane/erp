import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'inventory_form_dialog.dart';

class InventoriesScreen extends ConsumerWidget {
  const InventoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoriesAsync = ref.watch(inventoryListProvider);
    final search = ref.watch(inventorySearchProvider);
    final statusFilter = ref.watch(inventoryStatusFilterProvider);

    return PageScaffold(
      title: 'Inventaires',
      subtitle: 'Inventaires de stock et calcul des écarts',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showInventoryFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvel inventaire'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppSearchField(
                  hint: 'Rechercher par numéro de document',
                  initialValue: search,
                  onChanged: (v) => ref.read(inventorySearchProvider.notifier).state = v,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                      DropdownMenuItem(value: 'brouillon', child: Text('Brouillon')),
                      DropdownMenuItem(value: 'valide', child: Text('Validé')),
                      DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                    ],
                    onChanged: (v) => ref.read(inventoryStatusFilterProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: inventoriesAsync.when(
                data: (inventories) => inventories.isEmpty
                    ? const Center(child: Text('Aucun inventaire trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        table: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Articles')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final inv in inventories)
                              DataRow(cells: [
                                DataCell(Text(inv.documentNumber)),
                                DataCell(Text(_formatDate(inv.inventoryDate))),
                                DataCell(Text(inv.locationLabel)),
                                DataCell(Text('${inv.lines.length}')),
                                DataCell(StatusBadge.docStatus(inv.status)),
                                DataCell(_rowActions(context, ref, inv)),
                              ]),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _rowActions(BuildContext context, WidgetRef ref, Inventory inv) {
    return Row(
      children: [
        if (inv.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
            tooltip: 'Valider',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Valider l\'inventaire',
                message: 'Confirmer la validation de l\'inventaire ${inv.documentNumber} ? Les écarts de stock seront appliqués.',
                confirmLabel: 'Valider',
              );
              if (confirmed) {
                try {
                  await ref.read(inventoryRepositoryProvider).validate(inv.id);
                  ref.invalidate(inventoryListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Inventaire validé avec succès.');
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                }
              }
            },
          ),
        if (inv.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            tooltip: 'Modifier',
            onPressed: () => showInventoryFormDialog(context, ref, inventory: inv),
          ),
        if (inv.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
            tooltip: 'Annuler',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Annuler l\'inventaire',
                message: 'Confirmer l\'annulation de l\'inventaire ${inv.documentNumber} ?',
                confirmLabel: 'Annuler',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(inventoryRepositoryProvider).cancel(inv.id);
                  ref.invalidate(inventoryListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Inventaire annulé.');
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                }
              }
            },
          ),
        if (inv.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Supprimer l\'inventaire',
                message: 'Supprimer définitivement le brouillon ${inv.documentNumber} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(inventoryRepositoryProvider).delete(inv.id);
                  ref.invalidate(inventoryListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Inventaire supprimé.');
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                }
              }
            },
          ),
      ],
    );
  }
}
