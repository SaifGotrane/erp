import '../models/showroom.dart';
import 'base_repository.dart';

class ShowroomRepository extends BaseRepository {
  Future<List<Showroom>> fetchAll({String? search, bool? activeOnly}) {
    return guard(() async {
      var query = client.from('showrooms').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('name.ilike.%$search%,code.ilike.%$search%');
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data = await query.order('name');
      return (data as List).map((e) => Showroom.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Showroom> create(Showroom showroom) {
    return guard(() async {
      final data =
          await client.from('showrooms').insert(showroom.toInsertMap()).select().single();
      return Showroom.fromMap(data);
    });
  }

  Future<Showroom> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data =
          await client.from('showrooms').update(changes).eq('id', id).select().single();
      return Showroom.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('showrooms').update({'active': active}).eq('id', id));
  }
}
