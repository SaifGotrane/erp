import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vehicle_driver.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'driver_form_dialog.dart';

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(driverListProvider);
    final search = ref.watch(driverSearchProvider);

    return PageScaffold(
      title: 'Chauffeurs',
      subtitle: 'Gestion des chauffeurs',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showDriverFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau chauffeur'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher un chauffeur',
              initialValue: search,
              onChanged: (v) => ref.read(driverSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: driversAsync.when(
                data: (drivers) => drivers.isEmpty
                    ? const Center(child: Text('Aucun chauffeur trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Nom')),
                            DataColumn(label: Text('Téléphone')),
                            DataColumn(label: Text('Permis')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final d in drivers)
                              DataRow(cells: [
                                DataCell(Text(d.fullName)),
                                DataCell(Text(d.phone ?? '-')),
                                DataCell(Text(d.licenseNumber ?? '-')),
                                DataCell(StatusBadge.active(d.active)),
                                DataCell(_rowActions(context, ref, d)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Driver d) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => showDriverFormDialog(context, ref, driver: d),
        ),
        IconButton(
          icon: Icon(d.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: d.active ? AppColors.danger : AppColors.success),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: d.active ? 'Désactiver le chauffeur' : 'Activer le chauffeur',
              message: d.active ? 'Êtes-vous sûr de vouloir désactiver ce chauffeur ?' : 'Êtes-vous sûr de vouloir activer ce chauffeur ?',
            );
            if (confirmed) {
              await ref.read(driverRepositoryProvider).setActive(d.id, !d.active);
              ref.invalidate(driverListProvider);
            }
          },
        ),
      ],
    );
  }
}
