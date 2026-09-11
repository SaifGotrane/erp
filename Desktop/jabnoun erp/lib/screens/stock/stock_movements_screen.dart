import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';

class StockMovementsScreen extends ConsumerWidget {
  const StockMovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider);
    final typeFilter = ref.watch(stockMovementTypeFilterProvider);
    final depotFilter = ref.watch(stockMovementDepotFilterProvider);
    final depotsAsync = ref.watch(activeDepotsProvider);

    return PageScaffold(
      title: 'Mouvements de stock',
      subtitle: 'Historique complet des entrées et sorties',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  height: 38,
                  child: DropdownButtonFormField<String?>(
                    initialValue: typeFilter,
                    decoration: const InputDecoration(labelText: 'Type de mouvement'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous les types')),
                      DropdownMenuItem(value: 'entree', child: Text('Entrée')),
                      DropdownMenuItem(value: 'sortie', child: Text('Sortie')),
                      DropdownMenuItem(value: 'transfert', child: Text('Transfert')),
                      DropdownMenuItem(value: 'vente', child: Text('Vente')),
                      DropdownMenuItem(value: 'retour_fournisseur', child: Text('Retour fournisseur')),
                      DropdownMenuItem(value: 'retour_client', child: Text('Retour client')),
                      DropdownMenuItem(value: 'ajustement', child: Text('Ajustement')),
                      DropdownMenuItem(value: 'inventaire', child: Text('Inventaire')),
                    ],
                    onChanged: (v) => ref.read(stockMovementTypeFilterProvider.notifier).state = v,
                  ),
                ),
                depotsAsync.when(
                  data: (depots) => SizedBox(
                    width: 180,
                    height: 38,
                    child: DropdownButtonFormField<String?>(
                      initialValue: depotFilter,
                      decoration: const InputDecoration(labelText: 'Dépôt'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous les dépôts')),
                        for (final d in depots) DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => ref.read(stockMovementDepotFilterProvider.notifier).state = v,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: movementsAsync.when(
                data: (movements) => movements.isEmpty
                    ? const Center(child: Text('Aucun mouvement trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Article')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Quantité')),
                            DataColumn(label: Text('Source')),
                            DataColumn(label: Text('Destination')),
                            DataColumn(label: Text('Document')),
                          ],
                          rows: [
                            for (final m in movements)
                              DataRow(cells: [
                                DataCell(Text(_formatDate(m['created_at'] as String))),
                                DataCell(Text('${(m['article'] as Map<String, dynamic>?)?['reference'] ?? ''} — ${(m['article'] as Map<String, dynamic>?)?['designation'] ?? ''}')),
                                DataCell(_typeBadge(m['movement_type'] as String)),
                                DataCell(Text(((m['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(3))),
                                DataCell(Text(m['source_label'] as String? ?? '—')),
                                DataCell(Text(m['destination_label'] as String? ?? '—')),
                                DataCell(Text(m['document_number'] as String? ?? '—')),
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

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _typeBadge(String type) {
    final labels = {
      'entree': ('Entrée', AppColors.success, AppColors.successBg),
      'sortie': ('Sortie', AppColors.danger, AppColors.dangerBg),
      'transfert': ('Transfert', AppColors.info, AppColors.infoBg),
      'vente': ('Vente', AppColors.primary, AppColors.primaryLight),
      'retour_fournisseur': ('Retour four.', AppColors.warning, AppColors.warningBg),
      'retour_client': ('Retour client', AppColors.warning, AppColors.warningBg),
      'ajustement': ('Ajustement', AppColors.textSecondary, AppColors.surfaceAlt),
      'inventaire': ('Inventaire', AppColors.textSecondary, AppColors.surfaceAlt),
    };
    final entry = labels[type] ?? ('Type', AppColors.textSecondary, AppColors.surfaceAlt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: entry.$3, borderRadius: BorderRadius.circular(4)),
      child: Text(entry.$1, style: TextStyle(color: entry.$2, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
