import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vehicle_driver.dart';
import '../../providers/vehicle_driver_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/scrollable_table.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'vehicle_form_dialog.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListProvider);
    final search = ref.watch(vehicleSearchProvider);

    return PageScaffold(
      title: 'Véhicules',
      subtitle: 'Flotte de véhicules de l\'entreprise',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showVehicleFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau véhicule'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher véhicule',
              initialValue: search,
              onChanged: (v) => ref.read(vehicleSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: vehiclesAsync.when(
                data: (vehicles) => vehicles.isEmpty
                    ? const Center(child: Text('Aucun véhicule trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : ScrollableTable(
                        table: DataTable(
                          columns: const [
                            DataColumn(label: Text('Immatriculation')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Marque / Modèle')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final v in vehicles)
                              DataRow(cells: [
                                DataCell(Text(v.registrationNumber)),
                                DataCell(Text(v.vehicleType ?? '-')),
                                DataCell(Text('${v.brand ?? ''} ${v.model ?? ''}'.trim().isEmpty ? '-' : '${v.brand ?? ''} ${v.model ?? ''}')),
                                DataCell(StatusBadge.active(v.active)),
                                DataCell(_rowActions(context, ref, v)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Vehicle v) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => showVehicleFormDialog(context, ref, vehicle: v),
        ),
        IconButton(
          icon: Icon(v.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: v.active ? AppColors.danger : AppColors.success),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: v.active ? 'Désactiver le véhicule' : 'Activer le véhicule',
              message: v.active ? 'Êtes-vous sûr de vouloir désactiver ce véhicule ?' : 'Êtes-vous sûr de vouloir activer ce véhicule ?',
            );
            if (confirmed) {
              await ref.read(vehicleRepositoryProvider).setActive(v.id, !v.active);
              ref.invalidate(vehicleListProvider);
            }
          },
        ),
      ],
    );
  }
}
