import '../models/sav_ticket.dart';
import 'base_repository.dart';

class SavRepository extends BaseRepository {
  static const _selectClause =
      '*, customer:customers(name), article:articles(reference, designation), supplier:suppliers(name)';

  Future<List<SavTicket>> fetchAll({
    String? search,
    String? status,
    String? customerId,
    String? supplierId,
    String? articleId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('sav_tickets').select(_selectClause);
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('ticket_number', '%$search%');
      }
      if (status != null) query = query.eq('status', status);
      if (customerId != null) query = query.eq('customer_id', customerId);
      if (supplierId != null) query = query.eq('supplier_id', supplierId);
      if (articleId != null) query = query.eq('article_id', articleId);
      if (from != null) query = query.gte('reclamation_date', from.toIso8601String().split('T').first);
      if (to != null) query = query.lte('reclamation_date', to.toIso8601String().split('T').first);
      final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => SavTicket.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<SavTicket> fetchById(String id) {
    return guard(() async {
      final data = await client.from('sav_tickets').select(_selectClause).eq('id', id).single();
      return SavTicket.fromMap(data);
    });
  }

  Future<SavTicket> create({
    required String customerId,
    required String articleId,
    String? supplierId,
    required String issueDescription,
    required DateTime reclamationDate,
  }) {
    return guard(() async {
      final ticketNumber = await client.rpc('next_sav_ticket_number') as String;
      final data = await client
          .from('sav_tickets')
          .insert({
            'ticket_number': ticketNumber,
            'customer_id': customerId,
            'article_id': articleId,
            'supplier_id': supplierId,
            'issue_description': issueDescription,
            'reclamation_date': reclamationDate.toIso8601String().split('T').first,
            'status': 'ouvert',
            'created_by': client.auth.currentUser?.id,
          })
          .select(_selectClause)
          .single();
      return SavTicket.fromMap(data);
    });
  }

  Future<SavTicket> updateStatus(String id, String status) {
    return guard(() async {
      final data = await client
          .from('sav_tickets')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .select(_selectClause)
          .single();
      return SavTicket.fromMap(data);
    });
  }

  Future<SavTicket> resolve(String id, {required String resolutionType, String? resolutionNotes}) {
    return guard(() async {
      final result = await client.rpc('resolve_sav_ticket', params: {
        'p_ticket_id': id,
        'p_resolution_type': resolutionType,
        'p_resolution_notes': resolutionNotes,
      });
      return SavTicket.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<SavTicket> close(String id) {
    return guard(() async {
      final result = await client.rpc('close_sav_ticket', params: {'p_ticket_id': id});
      return SavTicket.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<List<SavTicketNote>> fetchNotes(String ticketId) {
    return guard(() async {
      final data = await client
          .from('sav_ticket_notes')
          .select('*, author:employees(full_name)')
          .eq('ticket_id', ticketId)
          .order('created_at');
      return (data as List).map((e) => SavTicketNote.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<SavTicketNote> addNote(String ticketId, String note) {
    return guard(() async {
      final data = await client
          .from('sav_ticket_notes')
          .insert({'ticket_id': ticketId, 'note': note, 'created_by': client.auth.currentUser?.id})
          .select('*, author:employees(full_name)')
          .single();
      return SavTicketNote.fromMap(data);
    });
  }
}
