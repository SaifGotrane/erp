import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';

final articleRepositoryProvider = Provider<ArticleRepository>((ref) => ArticleRepository());

final articleSearchProvider = StateProvider<String>((ref) => '');
final articleCategoryFilterProvider = StateProvider<String?>((ref) => null);

final articleListProvider = FutureProvider<List<Article>>((ref) async {
  final search = ref.watch(articleSearchProvider);
  final categoryId = ref.watch(articleCategoryFilterProvider);
  return ref.watch(articleRepositoryProvider).fetchAll(search: search, categoryId: categoryId);
});

final articleCategoriesProvider = FutureProvider<List<ArticleCategory>>((ref) {
  return ref.watch(articleRepositoryProvider).fetchCategories();
});

final articleUnitsProvider = FutureProvider<List<ArticleUnit>>((ref) {
  return ref.watch(articleRepositoryProvider).fetchUnits();
});

final taxRatesProvider = FutureProvider<List<TaxRate>>((ref) {
  return ref.watch(articleRepositoryProvider).fetchTaxRates();
});

final articleStockByLocationProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, articleId) {
  return ref.watch(articleRepositoryProvider).fetchStockByLocation(articleId);
});

final articleMovementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, articleId) {
  return ref.watch(articleRepositoryProvider).fetchMovements(articleId);
});
