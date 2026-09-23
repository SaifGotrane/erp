import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase4_8_providers.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';

class DeclarationsScreen extends ConsumerWidget {
  const DeclarationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedDeclarationMonthProvider);
    final salesAsync = ref.watch(declarationSalesProvider);
    final purchasesAsync = ref.watch(declarationPurchasesProvider);
    final retenueAsync = ref.watch(declarationRetenueProvider);

    return PageScaffold(
      title: 'Déclaration mensuelle',
      subtitle: 'Synthèse achats / ventes / retenue à la source par mois',
      actions: [
        _MonthPicker(month: month),
        const SizedBox(width: 10),
        _ExportButton(
          month: month,
          salesAsync: salesAsync,
          purchasesAsync: purchasesAsync,
          retenueAsync: retenueAsync,
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCard('VENTES', salesAsync, AppColors.success)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCard('ACHATS', purchasesAsync, AppColors.primary)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRetenueCard(retenueAsync)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, AsyncValue<Map<String, dynamic>> async, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent)),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              data: (data) => ScrollableTable(
                table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Indicateur')),
                    DataColumn(label: Text('Montant TND')),
                  ],
                  rows: [
                    _row('Total HT', data['total_ht'] ?? 0),
                    _row('Total TVA', data['total_tva'] ?? 0),
                    _row('Total TTC', data['total_ttc'] ?? data['total_sales'] ?? data['total_purchases'] ?? 0),
                    _row('Total payé', data['total_paid'] ?? 0),
                    _row('Total impayé', data['total_unpaid'] ?? 0),
                    _row('Nombre', (data['sales_count'] ?? data['purchases_count'] ?? 0).toDouble()),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetenueCard(AsyncValue<Map<String, dynamic>> async) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RETENUE À LA SOURCE (salaires)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warning),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              data: (data) => ScrollableTable(
                table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Indicateur')),
                    DataColumn(label: Text('Montant TND')),
                  ],
                  rows: [
                    _row('IRPP retenu', data['total_irpp'] ?? 0),
                    _row('CSS retenue', data['total_css'] ?? 0),
                    _row('Total retenue à reverser', data['total_retenue'] ?? 0),
                    _row('CNSS salarié', data['total_cnss'] ?? 0),
                    _row('Nombre d\'employés payés', (data['employees_count'] ?? 0).toDouble()),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, double value) {
    return DataRow(cells: [
      DataCell(Text(label)),
      DataCell(Text(value.toStringAsFixed(3))),
    ]);
  }
}

class _MonthPicker extends ConsumerWidget {
  final DateTime month;
  const _MonthPicker({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: month,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDatePickerMode: DatePickerMode.year,
          helpText: 'Sélectionner un mois',
        );
        if (picked != null) {
          ref.read(selectedDeclarationMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('${month.month.toString().padLeft(2, '0')}/${month.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends ConsumerWidget {
  final DateTime month;
  final AsyncValue<Map<String, dynamic>> salesAsync;
  final AsyncValue<Map<String, dynamic>> purchasesAsync;
  final AsyncValue<Map<String, dynamic>> retenueAsync;
  const _ExportButton({
    required this.month,
    required this.salesAsync,
    required this.purchasesAsync,
    required this.retenueAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return salesAsync.when(
      data: (sales) => purchasesAsync.when(
        data: (purchases) => retenueAsync.when(
          data: (retenue) => ElevatedButton.icon(
            onPressed: () => _export(context, sales, purchases, retenue),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Exporter Excel'),
          ),
          loading: () => _disabled,
          error: (_, _) => _disabled,
        ),
        loading: () => _disabled,
        error: (_, _) => _disabled,
      ),
      loading: () => _disabled,
      error: (_, _) => _disabled,
    );
  }

  Widget get _disabled => ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Exporter Excel'),
      );

  Future<void> _export(
    BuildContext context,
    Map<String, dynamic> sales,
    Map<String, dynamic> purchases,
    Map<String, dynamic> retenue,
  ) async {
    try {
      final rows = <List<Object?>>[
        ['Total HT', _v(sales, 'total_ht'), _v(purchases, 'total_ht'), null],
        ['Total TVA', _v(sales, 'total_tva'), _v(purchases, 'total_tva'), null],
        ['Total TTC', _v(sales, 'total_ttc', fallback: sales['total_sales']), _v(purchases, 'total_ttc', fallback: purchases['total_purchases']), null],
        ['Total payé', _v(sales, 'total_paid'), _v(purchases, 'total_paid'), null],
        ['Total impayé', _v(sales, 'total_unpaid'), _v(purchases, 'total_unpaid'), null],
        ['Nombre', _v(sales, 'sales_count'), _v(purchases, 'purchases_count'), null],
        ['IRPP retenu', null, null, _v(retenue, 'total_irpp')],
        ['CSS retenue', null, null, _v(retenue, 'total_css')],
        ['Total retenue à reverser', null, null, _v(retenue, 'total_retenue')],
        ['CNSS salarié', null, null, _v(retenue, 'total_cnss')],
      ];
      await ReportExportService.exportXlsx(
        filename: 'declaration_mensuelle_${month.month.toString().padLeft(2, '0')}_${month.year}',
        sheetName: 'Declaration',
        headers: ['Indicateur', 'Ventes', 'Achats', 'Retenue à la source'],
        rows: rows,
      );
      if (context.mounted) showAppSnackBar(context, 'Export généré.');
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  double _v(Map<String, dynamic> data, String key, {Object? fallback}) {
    final value = data[key] ?? fallback ?? 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
