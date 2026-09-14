import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bill_of_exchange.dart';
import '../../providers/bill_of_exchange_provider.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../services/bill_of_exchange_pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import 'settlement_form_dialog.dart';

class BillsOfExchangeScreen extends ConsumerWidget {
  const BillsOfExchangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billListProvider);
    final search = ref.watch(billSearchProvider);
    final statusFilter = ref.watch(billStatusFilterProvider);
    final supplierFilter = ref.watch(billSupplierFilterProvider);
    final suppliersAsync = ref.watch(supplierListProvider);

    return PageScaffold(
      title: 'Lettres de change',
      subtitle: 'Règlements fournisseurs par traites / lettres de change',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showSettlementFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau règlement'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            billsAsync.maybeWhen(
              data: (bills) => _SummaryRow(bills: bills),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppSearchField(
                  hint: 'Rechercher par n° de lettre',
                  initialValue: search,
                  onChanged: (v) => ref.read(billSearchProvider.notifier).state = v,
                ),
                SizedBox(
                  width: 180,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                      for (final s in billStatuses) DropdownMenuItem(value: s, child: Text(billStatusLabel(s))),
                    ],
                    onChanged: (v) => ref.read(billStatusFilterProvider.notifier).state = v,
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 38,
                  child: suppliersAsync.when(
                    data: (suppliers) => DropdownButtonFormField<String?>(
                      initialValue: supplierFilter,
                      decoration: const InputDecoration(labelText: 'Fournisseur'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous les fournisseurs')),
                        for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => ref.read(billSupplierFilterProvider.notifier).state = v,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: billsAsync.when(
                data: (bills) => bills.isEmpty
                    ? const Center(child: Text('Aucune lettre de change.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        table: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° lettre')),
                            DataColumn(label: Text('Fournisseur')),
                            DataColumn(label: Text('Facture')),
                            DataColumn(label: Text('Montant')),
                            DataColumn(label: Text('Échéance')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final b in bills)
                              DataRow(cells: [
                                DataCell(Text(b.billNumber)),
                                DataCell(Text(b.supplierName)),
                                DataCell(Text(b.purchaseDocumentNumber)),
                                DataCell(Text('${b.amount.toStringAsFixed(3)} TND')),
                                DataCell(Text(
                                  '${b.dueDate.day}/${b.dueDate.month}/${b.dueDate.year}',
                                  style: TextStyle(color: b.isOverdue ? AppColors.danger : null, fontWeight: b.isOverdue ? FontWeight.w700 : null),
                                )),
                                DataCell(_billStatusChip(b)),
                                DataCell(_rowActions(context, ref, b)),
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

  Widget _billStatusChip(BillOfExchange b) {
    if (b.status == 'non_payee' && b.isOverdue) {
      return const _Chip(label: 'Échue', color: AppColors.danger, background: AppColors.dangerBg);
    }
    switch (b.status) {
      case 'payee':
        return const _Chip(label: 'Payée', color: AppColors.success, background: AppColors.successBg);
      case 'annulee':
        return const _Chip(label: 'Annulée', color: AppColors.textMuted, background: AppColors.surfaceAlt);
      default:
        return const _Chip(label: 'Non payée', color: AppColors.warning, background: AppColors.warningBg);
    }
  }

  Widget _rowActions(BuildContext context, WidgetRef ref, BillOfExchange b) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
          tooltip: 'Imprimer',
          onPressed: () async {
            try {
              final settings = await ref.read(settingsRepositoryProvider).fetchSettings();
              await BillOfExchangePdfService().printBatch(
                [b],
                tireurAddress: b.supplierAddress ?? '',
                tireAddress: settings.address ?? settings.companyName,
              );
              if (context.mounted) showAppSnackBar(context, 'Lettre de change générée.');
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
            }
          },
        ),
        if (b.status == 'non_payee')
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
            tooltip: 'Marquer payée',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Marquer comme payée',
                message: 'Confirmer que la lettre ${b.billNumber} a été encaissée par le fournisseur ?',
                confirmLabel: 'Confirmer',
              );
              if (!confirmed) return;
              try {
                await ref.read(billOfExchangeRepositoryProvider).markPaid(b.id);
                ref.invalidate(billListProvider);
                if (context.mounted) showAppSnackBar(context, 'Lettre marquée comme payée.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            },
          ),
        if (b.status == 'non_payee')
          IconButton(
            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
            tooltip: 'Annuler',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Annuler la lettre de change',
                message: 'Confirmer l\'annulation de la lettre ${b.billNumber} ?',
                confirmLabel: 'Annuler',
                danger: true,
              );
              if (!confirmed) return;
              try {
                await ref.read(billOfExchangeRepositoryProvider).cancelBill(b.id);
                ref.invalidate(billListProvider);
                if (context.mounted) showAppSnackBar(context, 'Lettre annulée.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            },
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<BillOfExchange> bills;
  const _SummaryRow({required this.bills});

  @override
  Widget build(BuildContext context) {
    final total = bills.fold<double>(0, (sum, b) => sum + b.amount);
    final paid = bills.where((b) => b.status == 'payee').fold<double>(0, (sum, b) => sum + b.amount);
    final unpaid = bills.where((b) => b.status == 'non_payee').fold<double>(0, (sum, b) => sum + b.amount);
    final overdue = bills.where((b) => b.isOverdue).fold<double>(0, (sum, b) => sum + b.amount);
    final upcoming = bills.where((b) => b.status == 'non_payee' && !b.isOverdue).fold<double>(0, (sum, b) => sum + b.amount);
    final countPaid = bills.where((b) => b.status == 'payee').length;
    final countUnpaid = bills.where((b) => b.status == 'non_payee').length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _card('Total (${bills.length})', total, AppColors.navy, AppColors.surfaceAlt),
        _card('Payées ($countPaid)', paid, AppColors.success, AppColors.successBg),
        _card('Non payées ($countUnpaid)', unpaid, AppColors.warning, AppColors.warningBg),
        _card('Échues', overdue, AppColors.danger, AppColors.dangerBg),
        _card('À venir', upcoming, AppColors.primary, AppColors.primaryLight),
      ],
    );
  }

  Widget _card(String label, double value, Color color, Color bg) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(3)} TND', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const _Chip({required this.label, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
