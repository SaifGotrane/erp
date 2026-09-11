import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/partner.dart';
import '../../providers/partner_provider.dart';
import '../../providers/phase4_8_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'partner_form_dialog.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(customerListProvider);
    final search = ref.watch(customerSearchProvider);
    final governorate = ref.watch(customerGovernorateFilterProvider);

    return PageScaffold(
      title: 'Clients',
      subtitle: 'Gestion des clients et de leurs informations',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showPartnerFormDialog(
            context,
            ref,
            title: 'Nouveau client',
            repositoryProvider: customerRepositoryProvider,
            listProvider: customerListProvider,
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau client'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: AppSearchField(
                  hint: 'Rechercher Clients',
                  initialValue: search,
                  onChanged: (v) => ref.read(customerSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                height: 38,
                child: DropdownButtonFormField<String?>(
                  initialValue: governorate,
                  decoration: const InputDecoration(labelText: 'Gouvernorat'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final g in tunisianGovernorates) DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => ref.read(customerGovernorateFilterProvider.notifier).state = v,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: partnersAsync.when(
                data: (partners) => partners.isEmpty
                    ? const Center(child: Text('Aucun résultat.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Code')),
                            DataColumn(label: Text('Nom')),
                            DataColumn(label: Text('Société')),
                            DataColumn(label: Text('Téléphone')),
                            DataColumn(label: Text('Gouvernorat')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final p in partners)
                              DataRow(cells: [
                                DataCell(Text(p.code)),
                                DataCell(Text(p.name)),
                                DataCell(Text(p.companyName ?? '-')),
                                DataCell(Text(p.phone ?? '-')),
                                DataCell(Text(p.governorate ?? '-')),
                                DataCell(StatusBadge.active(p.active)),
                                DataCell(_rowActions(context, ref, p)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Partner p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.people_outline, size: 18, color: AppColors.primary),
          tooltip: 'Sous-clients',
          onPressed: () => _showSubClients(context, ref, p),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          tooltip: 'Modifier',
          onPressed: () => showPartnerFormDialog(
            context,
            ref,
            title: 'Nouveau client',
            repositoryProvider: customerRepositoryProvider,
            listProvider: customerListProvider,
            partner: p,
          ),
        ),
        IconButton(
          icon: Icon(p.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: p.active ? AppColors.danger : AppColors.success),
          tooltip: p.active ? 'Désactiver' : 'Activer',
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: p.active ? 'Désactiver' : 'Activer',
              message: p.active ? 'Êtes-vous sûr de vouloir désactiver cet enregistrement ?' : 'Êtes-vous sûr de vouloir activer cet enregistrement ?',
            );
            if (confirmed) {
              await ref.read(customerRepositoryProvider).setActive(p.id, !p.active);
              ref.invalidate(customerListProvider);
            }
          },
        ),
      ],
    );
  }

  void _showSubClients(BuildContext context, WidgetRef ref, Partner customer) {
    showDialog(
      context: context,
      builder: (_) => _SubClientsDialog(customer: customer),
    );
  }
}

class _SubClientsDialog extends ConsumerWidget {
  final Partner customer;
  const _SubClientsDialog({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(saleSubClientHistoryProvider(customer.id));

    return AlertDialog(
      title: Text(
        'Sous-clients — ${customer.name}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      content: SizedBox(
        width: 500,
        child: historyAsync.when(
          data: (subClients) {
            if (subClients.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucun sous-client enregistré pour ce client.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nom')),
                    DataColumn(label: Text('Facture')),
                    DataColumn(label: Text('Montant')),
                  ],
                  rows: [
                    for (final s in subClients)
                      DataRow(cells: [
                        DataCell(Text(s.subClientName)),
                        DataCell(Text(s.documentNumber)),
                        DataCell(Text('${s.amount.toStringAsFixed(3)} TND')),
                      ]),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }
}
