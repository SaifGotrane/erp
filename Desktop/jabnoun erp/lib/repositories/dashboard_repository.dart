import 'base_repository.dart';

/// Récupère les indicateurs du tableau de bord via une fonction RPC
/// PostgreSQL (`dashboard_summary`) qui calcule tout côté serveur à partir
/// des données réelles (aucune donnée fictive ne doit être affichée ici).
class DashboardRepository extends BaseRepository {
  Future<Map<String, dynamic>> fetchSummary({
    required DateTime from,
    required DateTime to,
    String? depotId,
    String? showroomId,
  }) {
    return guard(() async {
      final data = await client.rpc('dashboard_summary', params: {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
        'p_depot_id': depotId,
        'p_showroom_id': showroomId,
      });
      return Map<String, dynamic>.from(data as Map);
    });
  }
}
