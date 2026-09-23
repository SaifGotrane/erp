import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sale.dart';
import '../../providers/phase4_8_providers.dart';
import '../../services/transaction_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';

/// Écran de consultation et de retéléchargement des factures de vente
/// (toutes ventes validées, avec recherche par numéro et filtre par période).
class SalesInvoicesScreen extends ConsumerWidget {
  const SalesInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoiceSalesListProvider);
    final search = ref.watch(invoiceSalesSearchProvider);
    final dateFrom = ref.watch(invoiceSalesDateFromProvider);
    final dateTo = ref.watch(invoiceSalesDateToProvider);

    return PageScaffold(
      title: 'Factures ventes',
      subtitle: 'Historique des factures clients générées, avec retéléchargement',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppSearchField(
                  hint: 'Rechercher par numéro de document',
                  initialValue: search,
                  onChanged: (v) => ref.read(invoiceSalesSearchProvider.notifier).state = v,
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
                      ref.read(invoiceSalesDateFromProvider.notifier).state = picked.start;
                      ref.read(invoiceSalesDateToProvider.notifier).state = picked.end;
                    }
                  },
                ),
                if (dateFrom != null || dateTo != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Effacer la période',
                    onPressed: () {
                      ref.read(invoiceSalesDateFromProvider.notifier).state = null;
                      ref.read(invoiceSalesDateToProvider.notifier).state = null;
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
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Total HT')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final s in invoices)
                              DataRow(
                                cells: [
                                  DataCell(Text(s.documentNumber)),
                                  DataCell(Text(_formatDate(s.saleDate))),
                                  DataCell(Text(s.customerName)),
                                  DataCell(Text(s.locationLabel)),
                                  DataCell(Text(s.totalHt.toStringAsFixed(3))),
                                  DataCell(Text(s.totalTtc.toStringAsFixed(3))),
                                  DataCell(StatusBadge.docStatus(s.status)),
                                  DataCell(_downloadButton(context, s)),
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

  Widget _downloadButton(BuildContext context, Sale s) {
    return IconButton(
      icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
      tooltip: 'Retélécharger la facture et le bon de livraison',
      onPressed: () async {
        try {
          await TransactionPdfService().saleDocuments(s.id);
          if (context.mounted) showAppSnackBar(context, 'Documents générés.');
        } catch (e) {
          if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
        }
      },
    );
  }
}
