import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/showroom.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'showroom_form_dialog.dart';

class ShowroomsScreen extends ConsumerWidget {
  const ShowroomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showroomsAsync = ref.watch(showroomListProvider);
    final search = ref.watch(showroomSearchProvider);

    return PageScaffold(
      title: 'Showrooms',
      subtitle: 'Gestion des points de vente physiques',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showShowroomFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouveau showroom'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Rechercher par nom ou code',
              initialValue: search,
              onChanged: (v) => ref.read(showroomSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: showroomsAsync.when(
                data: (showrooms) => showrooms.isEmpty
                    ? const Center(child: Text('Aucun showroom trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : _ShowroomsTable(showrooms: showrooms),
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

class _ShowroomsTable extends ConsumerWidget {
  final List<Showroom> showrooms;
  const _ShowroomsTable({required this.showrooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Nom')),
          DataColumn(label: Text('Adresse')),
          DataColumn(label: Text('Téléphone')),
          DataColumn(label: Text('Statut')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final showroom in showrooms)
            DataRow(cells: [
              DataCell(Text(showroom.code)),
              DataCell(Text(showroom.name)),
              DataCell(Text(showroom.address ?? '-')),
              DataCell(Text(showroom.phone ?? '-')),
              DataCell(StatusBadge.active(showroom.active)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                    onPressed: () => showShowroomFormDialog(context, ref, showroom: showroom),
                  ),
                  IconButton(
                    icon: Icon(
                      showroom.active ? Icons.block_outlined : Icons.check_circle_outline,
                      size: 18,
                      color: showroom.active ? AppColors.danger : AppColors.success,
                    ),
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: showroom.active ? 'Désactiver le showroom' : 'Activer le showroom',
                        message: showroom.active
                            ? 'Êtes-vous sûr de vouloir désactiver ce showroom ?'
                            : 'Êtes-vous sûr de vouloir activer ce showroom ?',
                      );
                      if (confirmed) {
                        await ref.read(showroomRepositoryProvider).setActive(showroom.id, !showroom.active);
                        ref.invalidate(showroomListProvider);
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
