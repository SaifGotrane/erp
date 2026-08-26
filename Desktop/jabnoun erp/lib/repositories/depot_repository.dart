import '../models/depot.dart';
import 'base_repository.dart';

class DepotRepository extends BaseRepository {
  Future<List<Depot>> fetchAll({String? search, bool? activeOnly}) {
    return guard(() async {
      var query = client.from('depots').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('name.ilike.%$search%,code.ilike.%$search%');
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data = await query.order('name');
      return (data as List).map((e) => Depot.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Depot> create(Depot depot) {
    return guard(() async {
      final data =
          await client.from('depots').insert(depot.toInsertMap()).select().single();
      return Depot.fromMap(data);
    });
  }

  Future<Depot> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data = await client.from('depots').update(changes).eq('id', id).select().single();
      return Depot.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('depots').update({'active': active}).eq('id', id));
  }
}
