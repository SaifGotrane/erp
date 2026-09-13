import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../providers/article_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/common/status_badge.dart';
import 'article_form_dialog.dart';
import 'article_detail_screen.dart';

class ArticlesScreen extends ConsumerWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articleListProvider);
    final search = ref.watch(articleSearchProvider);
    final categoriesAsync = ref.watch(articleCategoriesProvider);
    final categoryFilter = ref.watch(articleCategoryFilterProvider);

    return PageScaffold(
      title: 'Articles',
      subtitle: 'Catalogue centralisé des articles',
      actions: [
        ElevatedButton.icon(
          onPressed: () => showArticleFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvel article'),
        ),
      ],
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppSearchField(
                  hint: 'Rechercher par référence ou désignation',
                  initialValue: search,
                  onChanged: (v) => ref.read(articleSearchProvider.notifier).state = v,
                ),
                const SizedBox(width: 12),
                categoriesAsync.maybeWhen(
                  data: (categories) => SizedBox(
                    width: 220,
                    height: 38,
                    child: DropdownButtonFormField<String?>(
                      initialValue: categoryFilter,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes les catégories')),
                        for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => ref.read(articleCategoryFilterProvider.notifier).state = v,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: articlesAsync.when(
                data: (articles) => articles.isEmpty
                    ? const Center(child: Text('Aucun article trouvé.', style: TextStyle(color: AppColors.textMuted)))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Référence')),
                            DataColumn(label: Text('Désignation')),
                            DataColumn(label: Text('Prix achat HT')),
                            DataColumn(label: Text('Prix vente TTC')),
                            DataColumn(label: Text('Stock min')),
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final a in articles)
                              DataRow(cells: [
                                DataCell(
                                  Text(a.reference),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: a)),
                                  ),
                                ),
                                DataCell(Text(a.designation)),
                                DataCell(Text(a.purchasePriceHt.toStringAsFixed(3))),
                                DataCell(Text(a.sellingPriceTtc.toStringAsFixed(3))),
                                DataCell(Text(a.minStock.toStringAsFixed(0))),
                                DataCell(StatusBadge.active(a.active)),
                                DataCell(_rowActions(context, ref, a)),
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

  Widget _rowActions(BuildContext context, WidgetRef ref, Article a) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          onPressed: () => showArticleFormDialog(context, ref, article: a),
        ),
        IconButton(
          icon: Icon(a.active ? Icons.block_outlined : Icons.check_circle_outline,
              size: 18, color: a.active ? AppColors.danger : AppColors.success),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: a.active ? "Désactiver l'article" : "Activer l'article",
              message: a.active ? 'Êtes-vous sûr de vouloir désactiver cet article ?' : 'Êtes-vous sûr de vouloir activer cet article ?',
            );
            if (confirmed) {
              await ref.read(articleRepositoryProvider).setActive(a.id, !a.active);
              ref.invalidate(articleListProvider);
            }
          },
        ),
      ],
    );
  }
}
