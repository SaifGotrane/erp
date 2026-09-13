import '../models/stock_transfer.dart';
import 'base_repository.dart';

class TransferRepository extends BaseRepository {
  Future<List<StockTransfer>> fetchAll({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('stock_transfers').select(
          '*, source_depot:depots!stock_transfers_source_depot_id_fkey(name), source_showroom:showrooms!stock_transfers_source_showroom_id_fkey(name), destination_depot:depots!stock_transfers_destination_depot_id_fkey(name), destination_showroom:showrooms!stock_transfers_destination_showroom_id_fkey(name), stock_transfer_lines(*, article:articles(reference, designation))');
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query.order('transfer_date', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => StockTransfer.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<StockTransfer> fetchById(String id) {
    return guard(() async {
      final data = await client.from('stock_transfers').select(
          '*, source_depot:depots!stock_transfers_source_depot_id_fkey(name), source_showroom:showrooms!stock_transfers_source_showroom_id_fkey(name), destination_depot:depots!stock_transfers_destination_depot_id_fkey(name), destination_showroom:showrooms!stock_transfers_destination_showroom_id_fkey(name), stock_transfer_lines(*, article:articles(reference, designation))')
          .eq('id', id)
          .single();
      return StockTransfer.fromMap(data);
    });
  }

  Future<StockTransfer> createDraft({
    required String? sourceDepotId,
    required String? sourceShowroomId,
    required String? destinationDepotId,
    required String? destinationShowroomId,
    required DateTime transferDate,
    String? vehicleId,
    String? driverId,
    String? notes,
    required List<StockTransferLine> lines,
  }) {
    return guard(() async {
      final docNumber = await client.rpc('next_document_number', params: {'p_prefix': 'TRF'}) as String;

      final data = await client.from('stock_transfers').insert({
        'document_number': docNumber,
        'source_depot_id': sourceDepotId,
        'source_showroom_id': sourceShowroomId,
        'destination_depot_id': destinationDepotId,
        'destination_showroom_id': destinationShowroomId,
        'transfer_date': transferDate.toIso8601String().split('T').first,
        'status': 'brouillon',
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'notes': notes?.isEmpty == true ? null : notes,
        'created_by': client.auth.currentUser?.id,
      }).select().single();

      final transferId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map((l) => {
                  'transfer_id': transferId,
                  'article_id': l.articleId,
                  'quantity': l.quantity,
                })
            .toList();
        await client.from('stock_transfer_lines').insert(lineMaps);
      }

      return fetchById(transferId);
    });
  }

  Future<StockTransfer> validate(String id) {
    return guard(() async {
      final result = await client.rpc('validate_transfer', params: {'p_transfer_id': id});
      return StockTransfer.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<StockTransfer> cancel(String id) {
    return guard(() async {
      final result = await client.rpc('cancel_transfer', params: {'p_transfer_id': id});
      return StockTransfer.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('stock_transfers').delete().eq('id', id));
  }
}
