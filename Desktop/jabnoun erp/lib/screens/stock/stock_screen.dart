import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      ref.invalidate(stockLevelsProvider);
      await ref.read(stockLevelsProvider.future);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockLevelsProvider);
    final search = ref.watch(stockSearchProvider);
    final depotFilter = ref.watch(stockDepotFilterProvider);
    final showroomFilter = ref.watch(stockShowroomFilterProvider);
    final lowStockOnly = ref.watch(stockLowStockOnlyProvider);
    final depotsAsync = ref.watch(activeDepotsProvider);
    final showroomsAsync = ref.watch(activeShowroomsProvider);

    return PageScaffold(
      title: 'État du stock',
      subtitle: 'Stock actuel par article et emplacement',
      actions: [
        FilterChip(
          label: const Text('Stock faible'),
          selected: lowStockOnly,
          onSelected: (v) =>
              ref.read(stockLowStockOnlyProvider.notifier).state = v,
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
                  hint: 'Rechercher par référence ou désignation',
                  initialValue: search,
                  onChanged: (v) =>
                      ref.read(stockSearchProvider.notifier).state = v,
                ),
                depotsAsync.when(
                  data: (depots) => SizedBox(
                    width: 180,
                    height: 38,
                    child: DropdownButtonFormField<String?>(
                      initialValue: depotFilter,
                      decoration: const InputDecoration(labelText: 'Dépôt'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous les dépôts'),
                        ),
                        for (final d in depots)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) =>
                          ref.read(stockDepotFilterProvider.notifier).state = v,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                showroomsAsync.when(
                  data: (showrooms) => SizedBox(
                    width: 180,
                    height: 38,
                    child: DropdownButtonFormField<String?>(
                      initialValue: showroomFilter,
                      decoration: const InputDecoration(labelText: 'Showroom'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous les showrooms'),
                        ),
                        for (final s in showrooms)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) =>
                          ref.read(stockShowroomFilterProvider.notifier).state =
                              v,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: stockAsync.when(
                data: (stock) => stock.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun stock trouvé.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Référence')),
                            DataColumn(label: Text('Désignation')),
                            DataColumn(label: Text('Emplacement')),
                            DataColumn(label: Text('Quantité')),
                            DataColumn(label: Text('Stock min')),
                            DataColumn(label: Text('Statut')),
                          ],
                          rows: [
                            for (final row in stock)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      (row['article']
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >?)?['reference']
                                              as String? ??
                                          '',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      (row['article']
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >?)?['designation']
                                              as String? ??
                                          '',
                                    ),
                                  ),
                                  DataCell(Text(_locationLabel(row))),
                                  DataCell(
                                    Text(
                                      ((row['quantity'] as num?)?.toDouble() ??
                                              0)
                                          .toStringAsFixed(3),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      ((row['article']
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >?)?['min_stock']
                                                  as num?)
                                              ?.toDouble()
                                              .toStringAsFixed(0) ??
                                          '0',
                                    ),
                                  ),
                                  DataCell(_stockBadge(row)),
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

  String _locationLabel(Map<String, dynamic> row) {
    final depot = row['depot'] as Map<String, dynamic>?;
    final showroom = row['showroom'] as Map<String, dynamic>?;
    return depot?['name'] as String? ?? showroom?['name'] as String? ?? '—';
  }

  Widget _stockBadge(Map<String, dynamic> row) {
    final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
    final minStock =
        ((row['article'] as Map<String, dynamic>?)?['min_stock'] as num?)
            ?.toDouble() ??
        0;
    if (qty <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Rupture',
          style: TextStyle(
            color: AppColors.danger,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (qty <= minStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Faible',
          style: TextStyle(
            color: AppColors.warning,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'OK',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
