import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentListProvider);
    final typeFilter = ref.watch(paymentTypeFilterProvider);

    return PageScaffold(
      title: 'Paiements',
      subtitle: 'Suivi des encaissements et décaissements',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 200, height: 38,
              child: DropdownButtonFormField<String?>(
                initialValue: typeFilter,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'encaissement', child: Text('Encaissements')),
                  DropdownMenuItem(value: 'decaissement', child: Text('Décaissements')),
                ],
                onChanged: (v) => ref.read(paymentTypeFilterProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (payments) => payments.isEmpty
                    ? const Center(child: Text('Aucun paiement.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Partenaire')),
                            DataColumn(label: Text('Méthode')),
                            DataColumn(label: Text('Montant')),
                            DataColumn(label: Text('Statut')),
                          ],
                        rows: [
                            for (final p in payments)
                              DataRow(cells: [
                                DataCell(Text(p.documentNumber)),
                                DataCell(Text('${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}')),
                                DataCell(Text(p.paymentType == 'encaissement' ? 'Encaissement' : 'Décaissement')),
                                DataCell(Text(p.partnerName)),
                                DataCell(Text(p.paymentMethodName ?? '—')),
                                DataCell(Text('${p.amount.toStringAsFixed(3)} TND', style: TextStyle(color: p.paymentType == 'encaissement' ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600))),
                                DataCell(p.status == 'annule'
                                    ? Text('Annulé', style: TextStyle(color: AppColors.danger, fontSize: 12))
                                    : Text('Actif', style: TextStyle(color: AppColors.success, fontSize: 12))),
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
}

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saleListProvider);

    return PageScaffold(
      title: 'Créances clients',
      subtitle: 'Suivi des paiements dus par les clients',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
          child: async.when(
            data: (sales) {
              final unpaid = sales.where((s) => s.status == 'valide' || s.status == 'partiellement_paye').toList();
              if (unpaid.isEmpty) return const Center(child: Text('Aucune créance.', style: TextStyle(color: AppColors.textMuted)));
              return ScrollableTable(
                columns: const [
                    DataColumn(label: Text('N° document')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Client')),
                    DataColumn(label: Text('Total TTC')),
                    DataColumn(label: Text('Payé')),
                    DataColumn(label: Text('Reste')),
                  ],
                rows: [
                    for (final s in unpaid)
                      DataRow(cells: [
                        DataCell(Text(s.documentNumber)),
                        DataCell(Text('${s.saleDate.day}/${s.saleDate.month}/${s.saleDate.year}')),
                        DataCell(Text(s.customerName)),
                        DataCell(Text(s.totalTtc.toStringAsFixed(3))),
                        DataCell(Text(s.amountPaid.toStringAsFixed(3))),
                        DataCell(Text((s.totalTtc - s.amountPaid).toStringAsFixed(3), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
                      ]),
                  ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
          ),
            ),
          ],
        ),
      ),
    );
  }
}

class PayablesScreen extends ConsumerWidget {
  const PayablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseListProvider);

    return PageScaffold(
      title: 'Dettes fournisseurs',
      subtitle: 'Suivi des paiements dus aux fournisseurs',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
          child: async.when(
            data: (purchases) {
              final unpaid = purchases.where((p) => p.status == 'valide' || p.status == 'partiellement_paye').toList();
              if (unpaid.isEmpty) return const Center(child: Text('Aucune dette.', style: TextStyle(color: AppColors.textMuted)));
              return ScrollableTable(
                columns: const [
                    DataColumn(label: Text('N° document')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Fournisseur')),
                    DataColumn(label: Text('Total TTC')),
                    DataColumn(label: Text('Payé')),
                    DataColumn(label: Text('Reste')),
                  ],
                rows: [
                    for (final p in unpaid)
                      DataRow(cells: [
                        DataCell(Text(p.documentNumber)),
                        DataCell(Text('${p.purchaseDate.day}/${p.purchaseDate.month}/${p.purchaseDate.year}')),
                        DataCell(Text(p.supplierName)),
                        DataCell(Text(p.totalTtc.toStringAsFixed(3))),
                        DataCell(Text(p.amountPaid.toStringAsFixed(3))),
                        DataCell(Text((p.totalTtc - p.amountPaid).toStringAsFixed(3), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
                      ]),
                  ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
          ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(expenseListProvider);

    return PageScaffold(
      title: 'Charges',
      subtitle: 'Dépenses de l\'entreprise',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showAddDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvelle charge'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300, height: 38,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (v) => ref.read(expenseSearchProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (expenses) => expenses.isEmpty
                    ? const Center(child: Text('Aucune charge.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Catégorie')),
                            DataColumn(label: Text('Libellé')),
                            DataColumn(label: Text('Montant')),
                            DataColumn(label: Text('')),
                          ],
                        rows: [
                            for (final e in expenses)
                              DataRow(cells: [
                                DataCell(Text(e.documentNumber)),
                                DataCell(Text('${e.expenseDate.day}/${e.expenseDate.month}/${e.expenseDate.year}')),
                                DataCell(Text(e.category ?? '—')),
                                DataCell(Text(e.label)),
                                DataCell(Text('${e.amount.toStringAsFixed(3)} TND')),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                  onPressed: () async {
                                    try {
                                      await ref.read(expenseRepositoryProvider).delete(e.id);
                                      ref.invalidate(expenseListProvider);
                                      if (context.mounted) showAppSnackBar(context, 'Charge supprimée.');
                                    } catch (err) {
                                      if (context.mounted) showAppSnackBar(context, err.toString(), isError: true);
                                    }
                                  },
                                )),
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle charge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Libellé *')),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant (TND) *')),
          const SizedBox(height: 12),
          TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Catégorie (optionnel)')),
          const SizedBox(height: 12),
          TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optionnel)'), maxLines: 2),
        ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (labelCtrl.text.trim().isEmpty) return;
              try {
                await ref.read(expenseRepositoryProvider).create(
                      label: labelCtrl.text.trim(),
                      amount: double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                      category: categoryCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );
                ref.invalidate(expenseListProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ctx.mounted) showAppSnackBar(ctx, 'Charge enregistrée.');
              } catch (e) {
                if (ctx.mounted) showAppSnackBar(ctx, e.toString(), isError: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class TvaScreen extends ConsumerWidget {
  const TvaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tvaReportProvider);

    return PageScaffold(
      title: 'TVA',
      subtitle: 'Calcul de la TVA collectée et déductible',
      child: ContentCard(
        child: async.when(
          data: (data) {
            final collected = (data['collected_tva'] as num?)?.toDouble() ?? 0;
            final paid = (data['paid_tva'] as num?)?.toDouble() ?? 0;
            final net = (data['net_tva'] as num?)?.toDouble() ?? 0;
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _tvaCard('TVA collectée (ventes)', collected, AppColors.success, AppColors.successBg),
                const SizedBox(height: 16),
                _tvaCard('TVA déductible (achats)', paid, AppColors.danger, AppColors.dangerBg),
                const SizedBox(height: 16),
                _tvaCard('TVA à payer', net, net > 0 ? AppColors.primary : AppColors.success, AppColors.primaryLight),
              ]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
        ),
      ),
    );
  }

  Widget _tvaCard(String label, double value, Color color, Color bg) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${value.toStringAsFixed(3)} TND', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
