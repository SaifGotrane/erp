import '../models/inventory.dart';
import 'base_repository.dart';

class InventoryRepository extends BaseRepository {
  Future<List<Inventory>> fetchAll({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('inventory_counts').select(
          '*, depot:depots(name), showroom:showrooms(name), inventory_lines(*, article:articles(reference, designation))');
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query.order('inventory_date', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => Inventory.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Inventory> fetchById(String id) {
    return guard(() async {
      final data = await client.from('inventory_counts').select(
          '*, depot:depots(name), showroom:showrooms(name), inventory_lines(*, article:articles(reference, designation))')
          .eq('id', id)
          .single();
      return Inventory.fromMap(data);
    });
  }

  /// Fetches theoretical stock for all active articles at a given location.
  Future<List<Map<String, dynamic>>> fetchTheoreticalStock({
    String? depotId,
    String? showroomId,
  }) {
    return guard(() async {
      final result = await client.rpc('fetch_theoretical_stock', params: {
        'p_depot_id': depotId,
        'p_showroom_id': showroomId,
      });
      return (result as List).cast<Map<String, dynamic>>();
    });
  }

  Future<Inventory> createDraft({
    required String? depotId,
    required String? showroomId,
    required DateTime inventoryDate,
    String? notes,
    required List<InventoryLine> lines,
  }) {
    return guard(() async {
      final docNumber = await client.rpc('next_document_number', params: {'p_prefix': 'INV'}) as String;

      final data = await client.from('inventory_counts').insert({
        'document_number': docNumber,
        'depot_id': depotId,
        'showroom_id': showroomId,
        'inventory_date': inventoryDate.toIso8601String().split('T').first,
        'status': 'brouillon',
        'notes': notes?.isEmpty == true ? null : notes,
        'created_by': client.auth.currentUser?.id,
      }).select().single();

      final inventoryId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map((l) => {
                  'inventory_id': inventoryId,
                  'article_id': l.articleId,
                  'theoretical_quantity': l.theoreticalQuantity,
                  'real_quantity': l.realQuantity,
                  'gap': l.realQuantity - l.theoreticalQuantity,
                })
            .toList();
        await client.from('inventory_lines').insert(lineMaps);
      }

      return fetchById(inventoryId);
    });
  }

  Future<Inventory> updateDraft(String id, Map<String, dynamic> changes) {
    return guard(() async {
      await client.from('inventory_counts').update(changes).eq('id', id);
      return fetchById(id);
    });
  }

  Future<void> updateLines(String inventoryId, List<InventoryLine> lines) {
    return guard(() async {
      await client.from('inventory_lines').delete().eq('inventory_id', inventoryId);
      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map((l) => {
                  'inventory_id': inventoryId,
                  'article_id': l.articleId,
                  'theoretical_quantity': l.theoreticalQuantity,
                  'real_quantity': l.realQuantity,
                  'gap': l.realQuantity - l.theoreticalQuantity,
                })
            .toList();
        await client.from('inventory_lines').insert(lineMaps);
      }
    });
  }

  Future<Inventory> validate(String id) {
    return guard(() async {
      final result = await client.rpc('validate_inventory', params: {'p_inventory_id': id});
      return Inventory.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<Inventory> cancel(String id) {
    return guard(() async {
      final result = await client.rpc('cancel_inventory', params: {'p_inventory_id': id});
      return Inventory.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('inventory_counts').delete().eq('id', id));
  }
}
