import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/returns.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'return_form_dialog.dart';

class SupplierReturnsScreen extends ConsumerWidget {
  const SupplierReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supplierReturnListProvider);
    final search = ref.watch(supplierReturnSearchProvider);
    final statusFilter = ref.watch(supplierReturnStatusFilterProvider);

    return PageScaffold(
      title: 'Retours fournisseurs',
      subtitle: 'Retours de marchandises aux fournisseurs',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showSupplierReturnFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau retour'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              AppSearchField(hint: 'Rechercher par numéro', initialValue: search, onChanged: (v) => ref.read(supplierReturnSearchProvider.notifier).state = v),
              const SizedBox(width: 12),
              SizedBox(
                width: 180, height: 38,
                child: DropdownButtonFormField<String?>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'brouillon', child: Text('Brouillon')),
                    DropdownMenuItem(value: 'valide', child: Text('Validé')),
                    DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                  ],
                  onChanged: (v) => ref.read(supplierReturnStatusFilterProvider.notifier).state = v,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('Aucun retour fournisseur.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Fournisseur')),
                            DataColumn(label: Text('Dépôt')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                        rows: [
                            for (final r in items)
                              DataRow(cells: [
                                DataCell(Text(r.documentNumber)),
                                DataCell(Text(_fmtDate(r.returnDate))),
                                DataCell(Text(r.supplierName)),
                                DataCell(Text(r.depotName)),
                                DataCell(Text(r.totalTtc.toStringAsFixed(3))),
                                DataCell(StatusBadge.docStatus(r.status)),
                                DataCell(_actions(context, ref, r)),
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

  Widget _actions(BuildContext context, WidgetRef ref, SupplierReturn r) {
    return Row(children: [
      if (r.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          tooltip: 'Valider',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Valider le retour', message: 'Confirmer la validation de ${r.documentNumber} ? Le stock sera décrémenté.', confirmLabel: 'Valider');
            if (ok) {
              try {
                await ref.read(supplierReturnRepositoryProvider).validate(r.id);
                ref.invalidate(supplierReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour validé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (r.status != 'annule')
        IconButton(
          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
          tooltip: 'Annuler',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Annuler le retour', message: 'Confirmer l\'annulation de ${r.documentNumber} ?', confirmLabel: 'Annuler', danger: true);
            if (ok) {
              try {
                await ref.read(supplierReturnRepositoryProvider).cancel(r.id);
                ref.invalidate(supplierReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour annulé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (r.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
          tooltip: 'Supprimer',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Supprimer', message: 'Supprimer le brouillon ${r.documentNumber} ?', confirmLabel: 'Supprimer', danger: true);
            if (ok) {
              try {
                await ref.read(supplierReturnRepositoryProvider).delete(r.id);
                ref.invalidate(supplierReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour supprimé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
    ]);
  }
}

class CustomerReturnsScreen extends ConsumerWidget {
  const CustomerReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerReturnListProvider);
    final search = ref.watch(customerReturnSearchProvider);
    final statusFilter = ref.watch(customerReturnStatusFilterProvider);

    return PageScaffold(
      title: 'Retours clients',
      subtitle: 'Retours de marchandises par les clients',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showCustomerReturnFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau retour'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              AppSearchField(hint: 'Rechercher par numéro', initialValue: search, onChanged: (v) => ref.read(customerReturnSearchProvider.notifier).state = v),
              const SizedBox(width: 12),
              SizedBox(
                width: 180, height: 38,
                child: DropdownButtonFormField<String?>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'brouillon', child: Text('Brouillon')),
                    DropdownMenuItem(value: 'valide', child: Text('Validé')),
                    DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                  ],
                  onChanged: (v) => ref.read(customerReturnStatusFilterProvider.notifier).state = v,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: async.when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('Aucun retour client.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        columns: const [
                            DataColumn(label: Text('N° document')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Total TTC')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                        rows: [
                            for (final r in items)
                              DataRow(cells: [
                                DataCell(Text(r.documentNumber)),
                                DataCell(Text(_fmtDate(r.returnDate))),
                                DataCell(Text(r.customerName)),
                                DataCell(Text(r.locationLabel)),
                                DataCell(Text(r.totalTtc.toStringAsFixed(3))),
                                DataCell(StatusBadge.docStatus(r.status)),
                                DataCell(_actions(context, ref, r)),
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

  Widget _actions(BuildContext context, WidgetRef ref, CustomerReturn r) {
    return Row(children: [
      if (r.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          tooltip: 'Valider',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Valider le retour', message: 'Confirmer la validation de ${r.documentNumber} ? Le stock sera réincrémenté.', confirmLabel: 'Valider');
            if (ok) {
              try {
                await ref.read(customerReturnRepositoryProvider).validate(r.id);
                ref.invalidate(customerReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour validé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (r.status != 'annule')
        IconButton(
          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
          tooltip: 'Annuler',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Annuler le retour', message: 'Confirmer l\'annulation de ${r.documentNumber} ?', confirmLabel: 'Annuler', danger: true);
            if (ok) {
              try {
                await ref.read(customerReturnRepositoryProvider).cancel(r.id);
                ref.invalidate(customerReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour annulé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
      if (r.status == 'brouillon')
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
          tooltip: 'Supprimer',
          onPressed: () async {
            final ok = await showConfirmDialog(context, title: 'Supprimer', message: 'Supprimer le brouillon ${r.documentNumber} ?', confirmLabel: 'Supprimer', danger: true);
            if (ok) {
              try {
                await ref.read(customerReturnRepositoryProvider).delete(r.id);
                ref.invalidate(customerReturnListProvider);
                if (context.mounted) showAppSnackBar(context, 'Retour supprimé.');
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            }
          },
        ),
    ]);
  }
}
