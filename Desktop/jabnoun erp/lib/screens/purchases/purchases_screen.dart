import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/purchase.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import '../finance/payment_dialog.dart';
import 'purchase_form_dialog.dart';
import '../../services/transaction_pdf_service.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchaseListProvider);
    final search = ref.watch(purchaseSearchProvider);
    final statusFilter = ref.watch(purchaseStatusFilterProvider);

    return PageScaffold(
      title: 'Achats',
      subtitle: 'Bons de réception et factures fournisseurs',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showPurchaseFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvel achat'),
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
                  hint: 'Rechercher par numéro ou référence fournisseur',
                  initialValue: search,
                  onChanged: (v) => ref.read(purchaseSearchProvider.notifier).state = v,
                ),
                SizedBox(
                  width: 220,
                  height: 42,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: statusFilter,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Tous les statuts'),
                      ),
                      DropdownMenuItem(
                        value: 'brouillon',
                        child: Text('Brouillon'),
                      ),
                      DropdownMenuItem(value: 'valide', child: Text('Validé')),
                      DropdownMenuItem(
                        value: 'partiellement_paye',
                        child: Text('Partiellement payé'),
                      ),
                      DropdownMenuItem(value: 'paye', child: Text('Payé')),
                      DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                    ],
                    onChanged: (v) =>
                        ref.read(purchaseStatusFilterProvider.notifier).state =
                            v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: purchasesAsync.when(
                data: (purchases) => purchases.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun achat trouvé.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Fournisseur')),
                            DataColumn(label: Text('Dépôt')),
                            DataColumn(label: Text('Total HT')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final p in purchases)
                              DataRow(
                                cells: [
                                  DataCell(Text(p.documentNumber)),
                                  DataCell(Text(_formatDate(p.purchaseDate))),
                                  DataCell(Text(p.supplierName)),
                                  DataCell(Text(p.depotName)),
                                  DataCell(Text(p.totalHt.toStringAsFixed(3))),
                                  DataCell(Text(p.totalTtc.toStringAsFixed(3))),
                                  DataCell(StatusBadge.docStatus(p.status)),
                                  DataCell(_rowActions(context, ref, p)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Purchase p) {
    return Row(
      children: [
        if (p.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: AppColors.success,
            ),
            tooltip: 'Valider',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Valider l\'achat',
                message:
                    'Confirmer la validation de l\'achat ${p.documentNumber} ? Le stock sera mis à jour.',
                confirmLabel: 'Valider',
              );
              if (confirmed) {
                try {
                  await ref.read(purchaseRepositoryProvider).validate(p.id);
                  ref.invalidate(purchaseListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Achat validé avec succès.');
                  }
                  try {
                    await TransactionPdfService().purchaseDocuments(p.id);
                  } catch (_) {
                    if (context.mounted) showAppSnackBar(context, 'Achat validé, mais la génération des PDF a échoué.', isError: true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if ((p.status == 'valide' || p.status == 'partiellement_paye') &&
            p.totalTtc > p.amountPaid)
          IconButton(
            icon: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Enregistrer un paiement',
            onPressed: () => showPaymentDialog(
              context,
              ref,
              partnerType: 'supplier',
              partnerId: p.supplierId,
              partnerName: p.supplierName,
              documentId: p.id,
              documentNumber: p.documentNumber,
              remainingAmount: p.totalTtc - p.amountPaid,
            ),
          ),
        if (p.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Modifier',
            onPressed: () => showPurchaseFormDialog(context, ref, purchase: p),
          ),
        if (p.status != 'annule' && p.status != 'paye')
          IconButton(
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: 'Annuler',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Annuler l\'achat',
                message: p.status == 'valide'
                    ? 'L\'annulation de l\'achat ${p.documentNumber} reversera le stock. Confirmer ?'
                    : 'Confirmer l\'annulation de l\'achat ${p.documentNumber} ?',
                confirmLabel: 'Annuler l\'achat',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(purchaseRepositoryProvider).cancel(p.id);
                  ref.invalidate(purchaseListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Achat annulé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if (p.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: 'Supprimer',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Supprimer l\'achat',
                message:
                    'Supprimer définitivement le brouillon ${p.documentNumber} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(purchaseRepositoryProvider).delete(p.id);
                  ref.invalidate(purchaseListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Achat supprimé.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
      ],
    );
  }
}
