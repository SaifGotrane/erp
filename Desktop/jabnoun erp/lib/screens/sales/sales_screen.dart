import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sale.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import '../finance/payment_dialog.dart';
import 'sale_form_dialog.dart';
import 'sub_invoice_dialog.dart';
import '../../services/transaction_pdf_service.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(saleListProvider);
    final search = ref.watch(saleSearchProvider);
    final statusFilter = ref.watch(saleStatusFilterProvider);

    return PageScaffold(
      title: 'Ventes',
      subtitle: 'Factures clients et suivi des paiements',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showSaleFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvelle vente'),
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
                  hint: 'Rechercher par numéro de document',
                  initialValue: search,
                  onChanged: (v) =>
                      ref.read(saleSearchProvider.notifier).state = v,
                ),
                SizedBox(
                  width: 180,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
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
                        ref.read(saleStatusFilterProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: salesAsync.when(
                data: (sales) => sales.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune vente trouvée.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Total HT')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Payé')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final s in sales)
                              DataRow(
                                cells: [
                                  DataCell(Text(s.documentNumber)),
                                  DataCell(Text(_formatDate(s.saleDate))),
                                  DataCell(Text(s.customerName)),
                                  DataCell(Text(s.locationLabel)),
                                  DataCell(Text(s.totalHt.toStringAsFixed(3))),
                                  DataCell(Text(s.totalTtc.toStringAsFixed(3))),
                                  DataCell(
                                    Text(s.amountPaid.toStringAsFixed(3)),
                                  ),
                                  DataCell(StatusBadge.docStatus(s.status)),
                                  DataCell(_rowActions(context, ref, s)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Sale s) {
    return Row(
      children: [
        if (s.status == 'brouillon')
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
                title: 'Valider la vente',
                message:
                    'Confirmer la validation de la vente ${s.documentNumber} ? Le stock sera décrémenté.',
                confirmLabel: 'Valider',
              );
              if (confirmed) {
                try {
                  await ref.read(saleRepositoryProvider).validate(s.id);
                  ref.invalidate(saleListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Vente validée avec succès.');
                  }
                  try {
                    await TransactionPdfService().saleDocuments(s.id);
                  } catch (_) {
                    if (context.mounted) showAppSnackBar(context, 'Vente validée, mais la génération des PDF a échoué.', isError: true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if ((s.status == 'valide' || s.status == 'partiellement_paye') &&
            s.totalTtc > s.amountPaid)
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
              partnerType: 'customer',
              partnerId: s.customerId,
              partnerName: s.customerName,
              documentId: s.id,
              documentNumber: s.documentNumber,
              remainingAmount: s.totalTtc - s.amountPaid,
            ),
          ),
        if (s.status == 'brouillon')
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Modifier',
            onPressed: () => showSaleFormDialog(context, ref, sale: s),
          ),
        if (s.status != 'brouillon' && s.status != 'annule')
          IconButton(
            icon: const Icon(
              Icons.call_split,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Sous-factures',
            onPressed: () => showSubInvoiceDialog(context, ref, s),
          ),
        if (s.status != 'annule' && s.status != 'paye')
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
                title: 'Annuler la vente',
                message: s.status == 'valide'
                    ? 'L\'annulation de la vente ${s.documentNumber} réincrémentera le stock. Confirmer ?'
                    : 'Confirmer l\'annulation de la vente ${s.documentNumber} ?',
                confirmLabel: 'Annuler la vente',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(saleRepositoryProvider).cancel(s.id);
                  ref.invalidate(saleListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Vente annulée.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppSnackBar(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        if (s.status == 'brouillon')
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
                title: 'Supprimer la vente',
                message:
                    'Supprimer définitivement le brouillon ${s.documentNumber} ?',
                confirmLabel: 'Supprimer',
                danger: true,
              );
              if (confirmed) {
                try {
                  await ref.read(saleRepositoryProvider).delete(s.id);
                  ref.invalidate(saleListProvider);
                  if (context.mounted) {
                    showAppSnackBar(context, 'Vente supprimée.');
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
