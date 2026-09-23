import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/purchase.dart';
import '../../providers/phase3_providers.dart';
import '../../services/transaction_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';

/// Écran de consultation et de retéléchargement des factures d'achat
/// (tous achats validés, avec recherche par numéro et filtre par période).
class PurchaseInvoicesScreen extends ConsumerWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicePurchasesListProvider);
    final search = ref.watch(invoicePurchasesSearchProvider);
    final dateFrom = ref.watch(invoicePurchasesDateFromProvider);
    final dateTo = ref.watch(invoicePurchasesDateToProvider);

    return PageScaffold(
      title: 'Factures achats',
      subtitle: 'Historique des factures fournisseurs générées, avec retéléchargement',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppSearchField(
                  hint: 'Rechercher par numéro ou référence fournisseur',
                  initialValue: search,
                  onChanged: (v) => ref.read(invoicePurchasesSearchProvider.notifier).state = v,
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
                      ref.read(invoicePurchasesDateFromProvider.notifier).state = picked.start;
                      ref.read(invoicePurchasesDateToProvider.notifier).state = picked.end;
                    }
                  },
                ),
                if (dateFrom != null || dateTo != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Effacer la période',
                    onPressed: () {
                      ref.read(invoicePurchasesDateFromProvider.notifier).state = null;
                      ref.read(invoicePurchasesDateToProvider.notifier).state = null;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: invoicesAsync.when(
                data: (invoices) => invoices.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune facture trouvée.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ScrollableTable(
                        table: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° facture')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Fournisseur')),
                            DataColumn(label: Text('Dépôt')),
                            DataColumn(label: Text('Total HT')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final p in invoices)
                              DataRow(
                                cells: [
                                  DataCell(Text(p.documentNumber)),
                                  DataCell(Text(_formatDate(p.purchaseDate))),
                                  DataCell(Text(p.supplierName)),
                                  DataCell(Text(p.depotName)),
                                  DataCell(Text(p.totalHt.toStringAsFixed(3))),
                                  DataCell(Text(p.totalTtc.toStringAsFixed(3))),
                                  DataCell(StatusBadge.docStatus(p.status)),
                                  DataCell(_downloadButton(context, p)),
                                ],
                              ),
                          ],
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _dateRangeLabel(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'Période';
    String fmt(DateTime? d) => d == null ? '…' : _formatDate(d);
    return '${fmt(from)} → ${fmt(to)}';
  }

  Widget _downloadButton(BuildContext context, Purchase p) {
    return IconButton(
      icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
      tooltip: 'Retélécharger la facture et le bon de réception',
      onPressed: () async {
        try {
          await TransactionPdfService().purchaseDocuments(p.id);
          if (context.mounted) showAppSnackBar(context, 'Documents générés.');
        } catch (e) {
          if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
        }
      },
    );
  }
}
