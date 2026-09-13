import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/partner.dart';
import '../../repositories/partner_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'partner_form_dialog.dart';

/// Écran générique de liste fournisseurs/clients (structure identique).
class PartnersListScreen extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String newButtonLabel;
  final Provider<PartnerRepository> repositoryProvider;
  final FutureProvider<List<Partner>> listProvider;
  final StateProvider<String> searchProvider;
  final StateProvider<String?> governorateFilterProvider;

  const PartnersListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.newButtonLabel,
    required this.repositoryProvider,
    required this.listProvider,
    required this.searchProvider,
    required this.governorateFilterProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(listProvider);
    final search = ref.watch(searchProvider);
    final governorate = ref.watch(governorateFilterProvider);

    return PageScaffold(
      title: title,
      subtitle: subtitle,
      actions: [
        ElevatedButton.icon(
          onPressed: () => showPartnerFormDialog(
            context,
            ref,
            title: newButtonLabel,
            repositoryProvider: repositoryProvider,
            listProvider: listProvider,
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(newButtonLabel),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: AppSearchField(
                  hint: 'Rechercher $title',
                  initialValue: search,
                  onChanged: (v) => ref.read(searchProvider.notifier).state = v,
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
                  onChanged: (v) => ref.read(governorateFilterProvider.notifier).state = v,
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
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => showPartnerFormDialog(
            context,
            ref,
            title: newButtonLabel,
            repositoryProvider: repositoryProvider,
            listProvider: listProvider,
            partner: p,
          ),
        ),
        IconButton(
          icon: Icon(p.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: p.active ? AppColors.danger : AppColors.success),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: p.active ? 'Désactiver' : 'Activer',
              message: p.active ? 'Êtes-vous sûr de vouloir désactiver cet enregistrement ?' : 'Êtes-vous sûr de vouloir activer cet enregistrement ?',
            );
            if (confirmed) {
              await ref.read(repositoryProvider).setActive(p.id, !p.active);
              ref.invalidate(listProvider);
            }
          },
        ),
      ],
    );
  }
}
