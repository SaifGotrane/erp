import '../models/article.dart';
import 'base_repository.dart';

class ArticleRepository extends BaseRepository {
  Future<List<Article>> fetchAll({
    String? search,
    String? categoryId,
    bool? activeOnly,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('articles').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('reference.ilike.%$search%,designation.ilike.%$search%,barcode.ilike.%$search%');
      }
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data =
          await query.order('designation').range(offset, offset + limit - 1);
      return (data as List).map((e) => Article.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Article?> fetchByReference(String reference) {
    return guard(() async {
      final data = await client
          .from('articles')
          .select()
          .eq('reference', reference)
          .maybeSingle();
      return data == null ? null : Article.fromMap(data);
    });
  }

  /// Stock par dépôt/showroom pour un article (agrégation `stock_levels`).
  Future<List<Map<String, dynamic>>> fetchStockByLocation(String articleId) {
    return guard(() async {
      final data = await client
          .from('stock_levels')
          .select('quantity, depot_id, showroom_id, depots(name), showrooms(name)')
          .eq('article_id', articleId);
      return (data as List).cast<Map<String, dynamic>>();
    });
  }

  Future<List<Map<String, dynamic>>> fetchMovements(String articleId, {int limit = 100}) {
    return guard(() async {
      final data = await client
          .from('stock_movements')
          .select()
          .eq('article_id', articleId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    });
  }

  Future<Article> create(Article article) {
    return guard(() async {
      final data =
          await client.from('articles').insert(article.toInsertMap()).select().single();
      return Article.fromMap(data);
    });
  }

  Future<Article> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data =
          await client.from('articles').update(changes).eq('id', id).select().single();
      return Article.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('articles').update({'active': active}).eq('id', id));
  }

  // --- Catégories, unités, taux de TVA ---

  Future<List<ArticleCategory>> fetchCategories() {
    return guard(() async {
      final data = await client.from('article_categories').select().order('name');
      return (data as List)
          .map((e) => ArticleCategory.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<ArticleUnit>> fetchUnits() {
    return guard(() async {
      final data = await client.from('units').select().order('name');
      return (data as List).map((e) => ArticleUnit.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<List<TaxRate>> fetchTaxRates() {
    return guard(() async {
      final data = await client.from('tax_rates').select().order('rate_percent');
      return (data as List).map((e) => TaxRate.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  // --- Catégories : création / modification ---

  Future<ArticleCategory> createCategory(String name) {
    return guard(() async {
      final data = await client
          .from('article_categories')
          .insert({'name': name, 'active': true})
          .select()
          .single();
      return ArticleCategory.fromMap(data);
    });
  }

  Future<ArticleCategory> updateCategory(String id, String name) {
    return guard(() async {
      final data = await client
          .from('article_categories')
          .update({'name': name})
          .eq('id', id)
          .select()
          .single();
      return ArticleCategory.fromMap(data);
    });
  }

  Future<void> deleteCategory(String id) {
    return guard(() => client.from('article_categories').delete().eq('id', id));
  }
}
