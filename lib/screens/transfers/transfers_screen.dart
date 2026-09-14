import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stock_transfer.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import '../../services/transaction_pdf_service.dart';
import 'transfer_form_dialog.dart';

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(transferListProvider);
    final search = ref.watch(transferSearchProvider);
    final statusFilter = ref.watch(transferStatusFilterProvider);

    return PageScaffold(
      title: 'Transferts',
      subtitle: 'Transferts de stock entre dépôts et showrooms',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showTransferFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau transfert'),
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
                  onChanged: (v) => ref.read(transferSearchProvider.notifier).state = v,
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
                    onChanged: (v) => ref.read(transferStatusFilterProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: transfersAsync.when(
                data: (transfers) => transfers.isEmpty
                    ? const Center(child: Text('Aucun transfert trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Source')),
                            DataColumn(label: Text('Destination')),
                            DataColumn(label: Text('Lignes')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                        rows: [
                            for (final t in transfers)
                              DataRow(cells: [
                                DataCell(Text(t.documentNumber)),
                                DataCell(Text(_formatDate(t.transferDate))),
                                DataCell(Text(t.sourceLabel)),
                                DataCell(Text(t.destinationLabel)),
                                DataCell(Text('${t.lines.length}')),
                                DataCell(StatusBadge.docStatus(t.status)),
                                DataCell(_rowActions(context, ref, t)),
                              ]),
                          ],
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

  Widget _rowActions(BuildContext context, WidgetRef ref, StockTransfer t) {
    return Row(
      children: [
        if (t.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
            tooltip: 'Valider',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Valider le transfert',
                message: 'Confirmer la validation du transfert ${t.documentNumber} ? Le stock sera déplacé.',
                confirmLabel: 'Valider',
              );
              if (confirmed) {
                try {
                  await ref.read(transferRepositoryProvider).validate(t.id);
                  ref.invalidate(transferListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Transfert validé avec succès.');
                  try {
                    await TransactionPdfService().transferDocument(t.id);
                  } catch (_) {
                    if (context.mounted) showAppSnackBar(context, 'Transfert validé, mais la génération du bon a échoué.', isError: true);
                  }
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                }
              }
            },
          ),
        if (t.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
            tooltip: 'Modifier',
            onPressed: () => showTransferFormDialog(context, ref, transfer: t),
          ),
        if (t.status != 'annule')
          IconButton(
            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
            tooltip: 'Annuler',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Annuler le transfert',
                message: t.status == 'valide'
                    ? 'L\'annulation du transfert ${t.documentNumber} reversera le stock. Confirmer ?'
                    : 'Confirmer l\'annulation du transfert ${t.documentNumber} ?',
                confirmLabel: 'Annuler le transfert',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(transferRepositoryProvider).cancel(t.id);
                  ref.invalidate(transferListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Transfert annulé.');
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                }
              }
            },
          ),
        if (t.status == 'brouillon')
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Supprimer le transfert',
                message: 'Supprimer définitivement le brouillon ${t.documentNumber} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(transferRepositoryProvider).delete(t.id);
                  ref.invalidate(transferListProvider);
                  if (context.mounted) showAppSnackBar(context, 'Transfert supprimé.');
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
