import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/depot.dart';
import '../../providers/depot_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'depot_form_dialog.dart';

class DepotsScreen extends ConsumerWidget {
  const DepotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depotsAsync = ref.watch(depotListProvider);
    final search = ref.watch(depotSearchProvider);

    return PageScaffold(
      title: 'Dépôts',
      subtitle: 'Gestion des dépôts de l\'entreprise',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showDepotFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau dépôt'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher par nom ou code',
              initialValue: search,
              onChanged: (v) => ref.read(depotSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: depotsAsync.when(
                data: (depots) => depots.isEmpty
                    ? const Center(child: Text('Aucun dépôt trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : _DepotsTable(depots: depots),
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

class _DepotsTable extends ConsumerWidget {
  final List<Depot> depots;
  const _DepotsTable({required this.depots});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScrollableTable(
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Nom')),
          DataColumn(label: Text('Adresse')),
          DataColumn(label: Text('Téléphone')),
          DataColumn(label: Text('Statut')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final depot in depots)
            DataRow(cells: [
              DataCell(Text(depot.code)),
              DataCell(Text(depot.name)),
              DataCell(Text(depot.address ?? '-')),
              DataCell(Text(depot.phone ?? '-')),
              DataCell(StatusBadge.active(depot.active)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                    onPressed: () => showDepotFormDialog(context, ref, depot: depot),
                  ),
                  IconButton(
                    icon: Icon(
                      depot.active ? Icons.block_outlined : Icons.check_circle_outline,
                      size: 18,
                      color: depot.active ? AppColors.danger : AppColors.success,
                    ),
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: depot.active ? 'Désactiver le dépôt' : 'Activer le dépôt',
                        message: depot.active
                            ? 'Êtes-vous sûr de vouloir désactiver ce dépôt ?'
                            : 'Êtes-vous sûr de vouloir activer ce dépôt ?',
                      );
                      if (confirmed) {
                        await ref.read(depotRepositoryProvider).setActive(depot.id, !depot.active);
                        ref.invalidate(depotListProvider);
                      }
                    },
                  ),
                ],
              )),
            ]),
        ],
      ),
    );
  }
}
