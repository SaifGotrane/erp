import '../models/partner.dart';
import 'base_repository.dart';

/// Repository générique pour fournisseurs et clients (tables distinctes
/// mais structure identique). [table] doit être 'suppliers' ou 'customers'.
class PartnerRepository extends BaseRepository {
  final String table;
  PartnerRepository(this.table);

  Future<List<Partner>> fetchAll({String? search, bool? activeOnly}) {
    return guard(() async {
      var query = client.from(table).select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('name.ilike.%$search%,code.ilike.%$search%,company_name.ilike.%$search%');
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data = await query.order('name');
      return (data as List).map((e) => Partner.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Partner> create(Partner partner) {
    return guard(() async {
      final data = await client.from(table).insert(partner.toInsertMap()).select().single();
      return Partner.fromMap(data);
    });
  }

  Future<Partner> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data = await client.from(table).update(changes).eq('id', id).select().single();
      return Partner.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from(table).update({'active': active}).eq('id', id));
  }

  /// Calcule le solde (total, payé, restant) sur une période via une vue/RPC
  /// côté serveur. Nom de fonction attendu: `partner_statement`.
  Future<Map<String, dynamic>> fetchStatement({
    required String partnerId,
    required DateTime from,
    required DateTime to,
  }) {
    return guard(() async {
      final data = await client.rpc('partner_statement', params: {
        'p_partner_id': partnerId,
        'p_partner_table': table,
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
      });
      return Map<String, dynamic>.from(data as Map);
    });
  }
}
