import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/depot_provider.dart';
import '../../providers/phase3_providers.dart';
import '../../providers/showroom_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/location_search_field.dart';
import '../../widgets/common/page_scaffold.dart';

class StockDashboardScreen extends ConsumerStatefulWidget {
  const StockDashboardScreen({super.key});

  @override
  ConsumerState<StockDashboardScreen> createState() =>
      _StockDashboardScreenState();
}

class _StockDashboardScreenState extends ConsumerState<StockDashboardScreen> {
  String? _depotId;
  String? _showroomId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final depotsAsync = ref.watch(activeDepotsProvider);
    final showroomsAsync = ref.watch(activeShowroomsProvider);

    final hasLocation = _depotId != null || _showroomId != null;

    return PageScaffold(
      title: 'Tableau de bord stock',
      subtitle: 'Vue cartographique du stock par emplacement',
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: depotsAsync.when(
                    data: (depots) => showroomsAsync.when(
                      data: (showrooms) => LocationSearchField(
                        depots: depots,
                        showrooms: showrooms,
                        selectedDepotId: _depotId,
                        selectedShowroomId: _showroomId,
                        label: 'Emplacement',
                        required: true,
                        onChanged: (depotId, showroomId) => setState(() {
                          _depotId = depotId;
                          _showroomId = showroomId;
                        }),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Filtrer les articles',
                      suffixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasLocation)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warehouse_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'Sélectionnez un emplacement pour visualiser le stock.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildGrid(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final stockFuture = ref.watch(stockRepositoryProvider).fetchStockLevels(
          depotId: _depotId,
          showroomId: _showroomId,
          search: _search.trim().isEmpty ? null : _search.trim(),
          limit: 500,
        );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: stockFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          );
        }
        final stock = snapshot.data ?? [];
        if (stock.isEmpty) {
          return const Center(
            child: Text(
              'Aucun article en stock pour cet emplacement.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final totalArticles = stock.length;
        final ruptures = stock.where((r) {
          final qty = (r['quantity'] as num?)?.toDouble() ?? 0;
          return qty <= 0;
        }).length;
        final faibles = stock.where((r) {
          final qty = (r['quantity'] as num?)?.toDouble() ?? 0;
          final minStock =
              ((r['article'] as Map<String, dynamic>?)?['min_stock'] as num?)
                      ?.toDouble() ??
                  0;
          return qty > 0 && qty <= minStock;
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _statCard('Articles', totalArticles.toString(),
                    AppColors.navy, Icons.inventory_2_outlined),
                const SizedBox(width: 12),
                _statCard('Ruptures', ruptures.toString(),
                    AppColors.danger, Icons.error_outline),
                const SizedBox(width: 12),
                _statCard('Stock faible', faibles.toString(),
                    AppColors.warning, Icons.warning_amber_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: stock.length,
                itemBuilder: (context, index) {
                  final row = stock[index];
                  final article =
                      row['article'] as Map<String, dynamic>? ?? {};
                  final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
                  final minStock =
                      (article['min_stock'] as num?)?.toDouble() ?? 0;
                  final ref = article['reference'] as String? ?? '';
                  final desig = article['designation'] as String? ?? '';

                  final isRupture = qty <= 0;
                  final isLow = !isRupture && qty <= minStock;

                  return _articleCard(
                    reference: ref,
                    designation: desig,
                    quantity: qty,
                    minStock: minStock,
                    isRupture: isRupture,
                    isLow: isLow,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _articleCard({
    required String reference,
    required String designation,
    required double quantity,
    required double minStock,
    required bool isRupture,
    required bool isLow,
  }) {
    final Color borderColor;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeLabel;

    if (isRupture) {
      borderColor = AppColors.danger.withValues(alpha: 0.3);
      badgeBg = AppColors.dangerBg;
      badgeFg = AppColors.danger;
      badgeLabel = 'Rupture';
    } else if (isLow) {
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      badgeBg = AppColors.warningBg;
      badgeFg = AppColors.warning;
      badgeLabel = 'Faible';
    } else {
      borderColor = AppColors.success.withValues(alpha: 0.3);
      badgeBg = AppColors.successBg;
      badgeFg = AppColors.success;
      badgeLabel = 'OK';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            designation,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quantity.toStringAsFixed(3),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'min: ${minStock.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
