import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../services/report_export_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/partner_search_field.dart';

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesReportProvider);
    return PageScaffold(
      title: 'Rapport des ventes',
      subtitle: 'Synthèse des ventes par période',
      actions: [_dateRangeAction(context, ref), _exportMapAction(context, 'rapport_ventes', 'Ventes', async)],
      child: ContentCard(
        child: _summaryTable(async, [
          ('Total ventes (TTC)', 'total_sales'),
          ('Total HT', 'total_ht'),
          ('Total TVA', 'total_tva'),
          ('Total encaissé', 'total_paid'),
          ('Total impayé', 'total_unpaid'),
          ('Nombre de ventes', 'sales_count'),
        ]),
      ),
    );
  }
}

class PurchasesReportScreen extends ConsumerWidget {
  const PurchasesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchasesReportProvider);
    return PageScaffold(
      title: 'Rapport des achats',
      subtitle: 'Synthèse des achats par période',
      actions: [_dateRangeAction(context, ref), _exportMapAction(context, 'rapport_achats', 'Achats', async)],
      child: ContentCard(
        child: _summaryTable(async, [
          ('Total achats (TTC)', 'total_purchases'),
          ('Total HT', 'total_ht'),
          ('Total TVA', 'total_tva'),
          ('Total payé', 'total_paid'),
          ('Total à payer', 'total_unpaid'),
          ('Nombre d\'achats', 'purchases_count'),
        ]),
      ),
    );
  }
}

class StockReportScreen extends ConsumerWidget {
  const StockReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockValuationProvider);
    return PageScaffold(
      title: 'Valorisation du stock',
      subtitle: 'Valeur du stock par article',
      actions: [_exportListAction(context, 'etat_stock', 'Stock', async)],
      child: ContentCard(
        child: async.when(
          data: (items) {
            double totalValue = 0;
            final hasUnknownCost = items.any((item) => item['stock_value'] == null);
            for (final item in items) {
              totalValue += (item['stock_value'] as num?)?.toDouble() ?? 0;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${hasUnknownCost ? 'Valeur connue' : 'Valeur totale'} du stock: ${totalValue.toStringAsFixed(3)} TND',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Référence')),
                        DataColumn(label: Text('Désignation')),
                        DataColumn(label: Text('Quantité')),
                        DataColumn(label: Text('Prix achat HT')),
                        DataColumn(label: Text('Valeur')),
                      ],
                      rows: [
                        for (final item in items)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(item['reference'] as String? ?? ''),
                              ),
                              DataCell(
                                Text(item['designation'] as String? ?? ''),
                              ),
                              DataCell(
                                Text(
                                  (item['quantity'] as num?)
                                          ?.toDouble()
                                          .toStringAsFixed(3) ??
                                      '0',
                                ),
                              ),
                              DataCell(
                                Text(
                                  (item['purchase_price_ht'] as num?)?.toDouble().toStringAsFixed(3) ?? 'Indisponible',
                                ),
                              ),
                              DataCell(
                                Text(
                                  (item['stock_value'] as num?)?.toDouble().toStringAsFixed(3) ?? 'Indisponible',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              e.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}

class MarginsReportScreen extends ConsumerWidget {
  const MarginsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marginAsync = ref.watch(salesMarginReportProvider);
    return PageScaffold(
      title: 'Analyse des marges',
      subtitle: 'Marge brute historique des ventes',
      actions: [_dateRangeAction(context, ref), _exportMapAction(context, 'rapport_marges', 'Marges', marginAsync)],
      child: ContentCard(
        child: marginAsync.when(
          data: (marginData) {
              final salesHt = (marginData['total_sales_ht'] as num?)?.toDouble() ?? 0;
              final costHt = (marginData['total_cost_ht'] as num?)?.toDouble() ?? 0;
              final margin = (marginData['margin_ht'] as num?)?.toDouble();
              final marginPct = (marginData['margin_percent'] as num?)?.toDouble();
              final unknownCosts = (marginData['unknown_cost_lines'] as num?)?.toInt() ?? 0;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _card(
                      'Ventes HT',
                      salesHt.toStringAsFixed(3),
                      AppColors.success,
                      AppColors.successBg,
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'Coût des ventes HT',
                      costHt.toStringAsFixed(3),
                      AppColors.danger,
                      AppColors.dangerBg,
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'Marge brute',
                      margin?.toStringAsFixed(3) ?? 'Indisponible',
                      AppColors.primary,
                      AppColors.primaryLight,
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'Marge %',
                      marginPct == null ? 'Indisponible' : '${marginPct.toStringAsFixed(2)} %',
                      AppColors.navy,
                      AppColors.surfaceAlt,
                    ),
                    if (unknownCosts > 0) Padding(padding: const EdgeInsets.only(top: 12), child: Text('$unknownCosts ligne(s) historique(s) sans coût : marge indisponible.', style: const TextStyle(color: AppColors.textMuted))),
                  ],
                ),
              );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              e.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String label, String value, Color color, Color bg) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class TvaReportScreen extends ConsumerWidget {
  const TvaReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tvaReportProvider);
    return PageScaffold(
      title: 'Rapport TVA',
      subtitle: 'TVA collectée et déductible',
      actions: [_dateRangeAction(context, ref)],
      child: ContentCard(
        child: _summaryTable(async, [
          ('TVA collectée', 'collected_tva'),
          ('TVA déductible', 'paid_tva'),
          ('TVA nette à payer', 'net_tva'),
        ]),
      ),
    );
  }
}

class SupplierStatementScreen extends ConsumerStatefulWidget {
  const SupplierStatementScreen({super.key});

  @override
  ConsumerState<SupplierStatementScreen> createState() =>
      _SupplierStatementScreenState();
}

class _SupplierStatementScreenState
    extends ConsumerState<SupplierStatementScreen> {
  String? _supplierId;
  bool _unpaidOnly = false;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider);
    return PageScaffold(
      title: 'Relevés fournisseurs',
      subtitle: 'Relevé détaillé par fournisseur',
      actions: [_dateRangeAction(context, ref)],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: suppliersAsync.when(
                data: (suppliers) => PartnerSearchField(
                  partners: suppliers,
                  selectedId: _supplierId,
                  label: 'Fournisseur',
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _unpaidOnly,
                  onChanged: (v) => setState(() => _unpaidOnly = v ?? false),
                ),
                const SizedBox(width: 4),
                const Text('Afficher uniquement les documents impayés'),
              ],
            ),
            const SizedBox(height: 8),
            if (_supplierId != null)
              Expanded(
                child: _statementTable(context, ref, 'supplier', _supplierId!, unpaidOnly: _unpaidOnly),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Sélectionnez un fournisseur.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomerStatementScreen extends ConsumerStatefulWidget {
  const CustomerStatementScreen({super.key});

  @override
  ConsumerState<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState
    extends ConsumerState<CustomerStatementScreen> {
  String? _customerId;
  bool _unpaidOnly = false;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    return PageScaffold(
      title: 'Relevés clients',
      subtitle: 'Relevé détaillé par client',
      actions: [_dateRangeAction(context, ref)],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: customersAsync.when(
                data: (customers) => PartnerSearchField(
                  partners: customers,
                  selectedId: _customerId,
                  label: 'Client',
                  onChanged: (v) => setState(() => _customerId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _unpaidOnly,
                  onChanged: (v) => setState(() => _unpaidOnly = v ?? false),
                ),
                const SizedBox(width: 4),
                const Text('Afficher uniquement les documents impayés'),
              ],
            ),
            const SizedBox(height: 8),
            if (_customerId != null)
              Expanded(
                child: _statementTable(context, ref, 'customer', _customerId!, unpaidOnly: _unpaidOnly),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Sélectionnez un client.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Helpers ---

Widget _dateRangeAction(BuildContext context, WidgetRef ref) {
  final from = ref.watch(reportDateFromProvider);
  final to = ref.watch(reportDateToProvider);
  String format(DateTime? value) => value == null
      ? '—'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  return OutlinedButton.icon(
    icon: const Icon(Icons.date_range_outlined, size: 18),
    label: Text('${format(from)} → ${format(to)}'),
    onPressed: () async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 5),
        initialDateRange: from != null && to != null
            ? DateTimeRange(start: from, end: to)
            : null,
        helpText: 'Sélectionner la période du rapport',
      );
      if (picked != null) {
        ref.read(reportDateFromProvider.notifier).state = picked.start;
        ref.read(reportDateToProvider.notifier).state = picked.end;
      }
    },
  );
}

Widget _summaryTable(
  AsyncValue<Map<String, dynamic>> async,
  List<(String, String)> fields,
) {
  return async.when(
    data: (data) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, key) in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _fmtValue(data[key]),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Text(
        e.toString(),
        style: const TextStyle(color: AppColors.danger),
      ),
    ),
  );
}

String _fmtValue(dynamic v) {
  if (v == null) return '0';
  if (v is num) return v.toDouble().toStringAsFixed(3);
  return v.toString();
}

Widget _exportMapAction(
  BuildContext context,
  String filename,
  String sheet,
  AsyncValue<Map<String, dynamic>> report,
) => _ExportButton(
  onExport: report.valueOrNull == null ? null : () async {
      final data = report.value!;
      await ReportExportService.exportXlsx(
        filename: '${filename}_${DateTime.now().toIso8601String().split('T').first}',
        sheetName: sheet,
        headers: data.keys.toList(),
        rows: [data.values.toList()],
      );
      if (context.mounted) showAppSnackBar(context, 'Rapport exporté avec succès.');
  },
);

Widget _exportListAction(
  BuildContext context,
  String filename,
  String sheet,
  AsyncValue<List<Map<String, dynamic>>> report,
) => _ExportButton(
  onExport: report.valueOrNull == null ? null : () async {
      final rows = report.value!;
      await ReportExportService.exportXlsx(
        filename: '${filename}_${DateTime.now().toIso8601String().split('T').first}',
        sheetName: sheet,
        headers: rows.isEmpty ? const ['Aucune donnée'] : rows.first.keys.toList(),
        rows: rows.isEmpty ? const [] : rows.map((row) => row.values.toList()).toList(),
      );
      if (context.mounted) showAppSnackBar(context, 'Rapport exporté avec succès.');
  },
);

class _ExportButton extends StatefulWidget {
  final Future<void> Function()? onExport;
  const _ExportButton({this.onExport});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _exporting = false;

  Future<void> _run() async {
    if (_exporting || widget.onExport == null) return;
    setState(() => _exporting = true);
    try {
      await widget.onExport!();
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Impossible d’exporter le rapport.', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: _exporting || widget.onExport == null ? null : _run,
    icon: _exporting
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download_outlined),
    label: Text(_exporting ? 'Exportation...' : 'Exporter'),
  );
}

Widget _statementTable(
  BuildContext context,
  WidgetRef ref,
  String type,
  String partnerId, {
  bool unpaidOnly = false,
}) {
  final async = ref.watch(partnerStatementProvider((type, partnerId)));
  return async.when(
    data: (allRows) {
      final rows = unpaidOnly
          ? allRows.where((r) => ((r['balance'] as num?)?.toDouble() ?? 0) > 0.001).toList()
          : allRows;
      final totalInvoiced = allRows.fold<double>(0, (sum, r) => sum + ((r['total_ttc'] as num?)?.toDouble() ?? 0));
      final totalPaid = allRows.fold<double>(0, (sum, r) => sum + ((r['amount_paid'] as num?)?.toDouble() ?? 0));
      final totalOutstanding = allRows.fold<double>(0, (sum, r) => sum + ((r['balance'] as num?)?.toDouble() ?? 0));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _balanceCard('Total facturé', totalInvoiced, AppColors.navy, AppColors.surfaceAlt)),
              const SizedBox(width: 12),
              Expanded(child: _balanceCard('Total payé', totalPaid, AppColors.success, AppColors.successBg)),
              const SizedBox(width: 12),
              Expanded(child: _balanceCard(
                totalOutstanding > 0.001 ? 'Solde dû (débit)' : 'Solde',
                totalOutstanding,
                totalOutstanding > 0.001 ? AppColors.danger : AppColors.textMuted,
                totalOutstanding > 0.001 ? AppColors.dangerBg : AppColors.surfaceAlt,
              )),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun document.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('N° document')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Total TTC')),
                        DataColumn(label: Text('Payé')),
                        DataColumn(label: Text('Solde')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r['document_type'] as String? ?? '')),
                              DataCell(Text(r['document_number'] as String? ?? '')),
                              DataCell(
                                Text(
                                  r['document_date']?.toString().split(' ').first ?? '',
                                ),
                              ),
                              DataCell(
                                Text(
                                  (r['total_ttc'] as num?)?.toDouble().toStringAsFixed(
                                        3,
                                      ) ??
                                      '0',
                                ),
                              ),
                              DataCell(
                                Text(
                                  (r['amount_paid'] as num?)
                                          ?.toDouble()
                                          .toStringAsFixed(3) ??
                                      '0',
                                ),
                              ),
                              DataCell(
                                Text(
                                  (r['balance'] as num?)?.toDouble().toStringAsFixed(
                                        3,
                                      ) ??
                                      '0',
                                  style: TextStyle(
                                    color: ((r['balance'] as num?)?.toDouble() ?? 0) > 0.001 ? AppColors.danger : null,
                                    fontWeight: ((r['balance'] as num?)?.toDouble() ?? 0) > 0.001 ? FontWeight.w600 : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Text(
        e.toString(),
        style: const TextStyle(color: AppColors.danger),
      ),
    ),
  );
}

Widget _balanceCard(String label, double value, Color color, Color bg) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('${value.toStringAsFixed(3)} TND', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}
