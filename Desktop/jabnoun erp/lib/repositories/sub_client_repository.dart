import 'base_repository.dart';
import '../models/sub_client.dart';

class SubClientRepository extends BaseRepository {
  Future<List<SubClient>> fetchAll({
    String? search,
    bool activeOnly = false,
    int limit = 200,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('sub_clients').select('*');
      if (activeOnly) {
        query = query.eq('active', true);
      }
      final data = await query
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);
      var results = (data as List)
          .map((e) => SubClient.fromMap(e as Map<String, dynamic>))
          .toList();
      if (search != null && search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        results = results
            .where((sc) =>
                sc.name.toLowerCase().contains(s) ||
                sc.cin.toLowerCase().contains(s))
            .toList();
      }
      return results;
    });
  }

  Future<SubClient> create({
    required String name,
    required String cin,
    String? phone,
    String? address,
  }) {
    return guard(() async {
      final data = await client.from('sub_clients').insert({
        'name': name.trim(),
        'cin': cin.trim(),
        'phone': phone?.trim(),
        'address': address?.trim(),
      }).select().single();
      return SubClient.fromMap(data);
    });
  }

  Future<SubClient> update({
    required String id,
    String? name,
    String? cin,
    String? phone,
    String? address,
    bool? active,
  }) {
    return guard(() async {
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name.trim();
      if (cin != null) fields['cin'] = cin.trim();
      if (phone != null) fields['phone'] = phone.trim();
      if (address != null) fields['address'] = address.trim();
      if (active != null) fields['active'] = active;
      final data = await client
          .from('sub_clients')
          .update(fields)
          .eq('id', id)
          .select()
          .single();
      return SubClient.fromMap(data);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('sub_clients').delete().eq('id', id));
  }

  /// Fetch trimester usage count for a sub-client in a given year.
  Future<int> getTrimesterUsage(String subClientId, int year, String trimester) {
    return guard(() async {
      final data = await client.rpc('get_sub_client_trimester_usage', params: {
        'p_sub_client_id': subClientId,
        'p_year': year,
        'p_trimester': trimester,
      });
      final rows = data as List;
      for (final row in rows) {
        final m = row as Map<String, dynamic>;
        if (m['trimester'] == trimester) {
          return (m['usage_count'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    });
  }
}
