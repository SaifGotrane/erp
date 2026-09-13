import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../providers/article_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';

/// Fiche article : informations générales, stock par emplacement et
/// historique complet des mouvements (traçabilité - voir cahier des charges §10).
class ArticleDetailScreen extends ConsumerWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(articleStockByLocationProvider(article.id));
    final movementsAsync = ref.watch(articleMovementsProvider(article.id));

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: Text('${article.reference} — ${article.designation}'),
      ),
      body: PageScaffold(
        title: 'Fiche article',
        subtitle: 'Traçabilité complète : stock, achats, ventes, mouvements',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContentCard(
                child: Wrap(
                  spacing: 32,
                  runSpacing: 12,
                  children: [
                    _infoTile('Prix achat HT', article.purchasePriceHt.toStringAsFixed(3)),
                    _infoTile('Marge %', '${article.marginPercent}%'),
                    _infoTile('TVA', '${article.taxRatePercent}%'),
                    _infoTile('Prix vente HT', article.sellingPriceHt.toStringAsFixed(3)),
                    _infoTile('Prix vente TTC', article.sellingPriceTtc.toStringAsFixed(3)),
                    _infoTile('Stock minimum', article.minStock.toStringAsFixed(0)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Stock par emplacement',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 8),
              ContentCard(
                child: stockAsync.when(
                  data: (rows) => rows.isEmpty
                      ? const Text('Aucun stock enregistré pour cet article.',
                          style: TextStyle(color: AppColors.textMuted))
                      : Column(
                          children: [
                            for (final row in rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(row['depots'] != null
                                        ? (row['depots']['name'] ?? '-')
                                        : (row['showrooms']?['name'] ?? '-')),
                                    Text('${row['quantity']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Historique des mouvements',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 8),
              ContentCard(
                child: movementsAsync.when(
                  data: (rows) => rows.isEmpty
                      ? const Text('Aucun mouvement enregistré pour cet article.',
                          style: TextStyle(color: AppColors.textMuted))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Quantité')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('Destination')),
                              DataColumn(label: Text('Document')),
                            ],
                            rows: [
                              for (final m in rows)
                                DataRow(cells: [
                                  DataCell(Text('${m['created_at']}'.split('T').first)),
                                  DataCell(Text('${m['movement_type'] ?? '-'}')),
                                  DataCell(Text('${m['quantity'] ?? '-'}')),
                                  DataCell(Text('${m['source_label'] ?? '-'}')),
                                  DataCell(Text('${m['destination_label'] ?? '-'}')),
                                  DataCell(Text('${m['document_number'] ?? '-'}')),
                                ]),
                            ],
                          ),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
        ],
      ),
    );
  }
}
