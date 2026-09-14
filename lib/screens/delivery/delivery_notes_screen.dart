import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/delivery_note.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import '../../services/transaction_pdf_service.dart';
import 'delivery_note_form_dialog.dart';

class DeliveryNotesScreen extends ConsumerWidget {
  const DeliveryNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveryListProvider);
    final search = ref.watch(deliverySearchProvider);
    final statusFilter = ref.watch(deliveryStatusFilterProvider);
    final customerFilter = ref.watch(deliveryCustomerFilterProvider);
    final dateFrom = ref.watch(deliveryDateFromFilterProvider);
    final dateTo = ref.watch(deliveryDateToFilterProvider);
    final customersAsync = ref.watch(customerListProvider);

    return PageScaffold(
      title: 'Bons de livraison',
      subtitle: 'Gestion des bons de livraison clients',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showDeliveryNoteFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau bon'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppSearchField(
                  hint: 'Rechercher par numéro',
                  initialValue: search,
                  onChanged: (v) => ref.read(deliverySearchProvider.notifier).state = v,
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200, minHeight: 38),
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: statusFilter,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                        DropdownMenuItem(value: 'brouillon', child: Text('Brouillon')),
                        DropdownMenuItem(value: 'livre', child: Text('Livré')),
                        DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                      ],
                      onChanged: (v) => ref.read(deliveryStatusFilterProvider.notifier).state = v,
                    ),
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240, minHeight: 38),
                    child: customersAsync.when(
                      data: (customers) => DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: customerFilter,
                        decoration: const InputDecoration(labelText: 'Client'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous les clients')),
                          for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => ref.read(deliveryCustomerFilterProvider.notifier).state = v,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(_dateRangeLabel(dateFrom, dateTo)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange: dateFrom != null && dateTo != null
                          ? DateTimeRange(start: dateFrom, end: dateTo)
                          : null,
                      helpText: 'Sélectionner une période',
                    );
                    if (picked != null) {
                      ref.read(deliveryDateFromFilterProvider.notifier).state = picked.start;
                      ref.read(deliveryDateToFilterProvider.notifier).state = picked.end;
                    }
                  },
                ),
                if (dateFrom != null || dateTo != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Effacer la période',
                    onPressed: () {
                      ref.read(deliveryDateFromFilterProvider.notifier).state = null;
                      ref.read(deliveryDateToFilterProvider.notifier).state = null;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('Aucun bon de livraison.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Lignes')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                        rows: [
                            for (final d in items)
                              DataRow(cells: [
                                DataCell(Text(d.documentNumber)),
                                DataCell(Text(_fmtDate(d.deliveryDate))),
                                DataCell(Text(d.customerName)),
                                DataCell(Text(d.locationLabel)),
                                DataCell(Text('${d.lines.length}')),
                                DataCell(StatusBadge.docStatus(d.status)),
                                DataCell(_actions(context, ref, d)),
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

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _dateRangeLabel(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'Période';
    String fmt(DateTime? d) => d == null ? '…' : _fmtDate(d);
    return '${fmt(from)} → ${fmt(to)}';
  }

  Widget _actions(BuildContext context, WidgetRef ref, DeliveryNote d) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
      if (d.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          tooltip: 'Valider',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Valider le bon de livraison', message: 'Confirmer la validation de ${d.documentNumber} ? Le stock sera décrémenté.', confirmLabel: 'Valider');
            if (ok) {
              try {
                await ref.read(deliveryNoteRepositoryProvider).validate(d.id);
                ref.invalidate(deliveryListProvider);
                if (context.mounted) showAppSnackBar(context, 'Bon de livraison validé.');
                try {
                  await TransactionPdfService().deliveryNoteDocument(d.id);
                } catch (_) {
                  if (context.mounted) showAppSnackBar(context, 'Bon validé, mais la génération du PDF a échoué.', isError: true);
                }
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (d.status != 'brouillon' && d.status != 'annule')
        IconButton(
          icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
          tooltip: 'Télécharger le bon de livraison',
          onPressed: () async {
            try {
              await TransactionPdfService().deliveryNoteDocument(d.id);
              if (context.mounted) showAppSnackBar(context, 'Bon de livraison généré.');
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
            }
          },
        ),
      if (d.status != 'annule')
        IconButton(
          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
          tooltip: 'Annuler',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Annuler le bon de livraison', message: 'Confirmer l\'annulation de ${d.documentNumber} ?', confirmLabel: 'Annuler', danger: true);
            if (ok) {
              try {
                await ref.read(deliveryNoteRepositoryProvider).cancel(d.id);
                ref.invalidate(deliveryListProvider);
                if (context.mounted) showAppSnackBar(context, 'Bon de livraison annulé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (d.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
          tooltip: 'Supprimer',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Supprimer', message: 'Supprimer le brouillon ${d.documentNumber} ?', confirmLabel: 'Supprimer', danger: true);
            if (ok) {
              try {
                await ref.read(deliveryNoteRepositoryProvider).delete(d.id);
                ref.invalidate(deliveryListProvider);
                if (context.mounted) showAppSnackBar(context, 'Bon de livraison supprimé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
        ],
      ),
    );
  }
}
