import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../providers/article_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/page_scaffold.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(articleCategoriesProvider);

    return PageScaffold(
      title: 'Catégories',
      subtitle: "Catégories d'articles pour le catalogue centralisé",
      actions: [
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nouvelle catégorie'),
        ),
      ],
      child: ContentCard(
        child: categoriesAsync.when(
          data: (categories) => categories.isEmpty
              ? const Center(child: Text('Aucune catégorie.', style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    return ListTile(
                      title: Text(c.name),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary), onPressed: () => _showFormDialog(context, ref, category: c)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          tooltip: 'Supprimer',
                          onPressed: () async {
                            final confirmed = await showConfirmDialog(context, title: 'Supprimer la catégorie', message: 'Supprimer la catégorie ${c.name} ?', confirmLabel: 'Supprimer', danger: true);
                            if (!confirmed) return;
                            try {
                              await ref.read(articleRepositoryProvider).deleteCategory(c.id);
                              ref.invalidate(articleCategoriesProvider);
                              if (context.mounted) showAppSnackBar(context, 'Catégorie supprimée.');
                            } catch (e) {
                              if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.danger))),
        ),
      ),
    );
  }

  void _showFormDialog(BuildContext context, WidgetRef ref, {ArticleCategory? category}) {
    final controller = TextEditingController(text: category?.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final repo = ref.read(articleRepositoryProvider);
                if (category == null) {
                  await repo.createCategory(name);
                } else {
                  await repo.updateCategory(category.id, name);
                }
                ref.invalidate(articleCategoriesProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
