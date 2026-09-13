import '../models/bill_of_exchange.dart';
import 'base_repository.dart';

class BillOfExchangeRepository extends BaseRepository {
  Future<SupplierSettlement> createSettlement({
    required String supplierId,
    required String purchaseId,
    required List<Map<String, dynamic>> bills, // [{amount, due_date (ISO)}]
    String? bankName,
    String? bankAgency,
    String? ribCodeBanque,
    String? ribCodeAgence,
    String? ribCompte,
    String? ribCle,
    String? billPlace,
    String? avalInfo,
    String? notes,
  }) {
    return guard(() async {
      final result = await client.rpc('create_supplier_settlement', params: {
        'p_supplier_id': supplierId,
        'p_purchase_id': purchaseId,
        'p_bills': bills,
        'p_bank_name': bankName,
        'p_bank_agency': bankAgency,
        'p_rib_code_banque': ribCodeBanque,
        'p_rib_code_agence': ribCodeAgence,
        'p_rib_compte': ribCompte,
        'p_rib_cle': ribCle,
        'p_bill_place': billPlace,
        'p_aval_info': avalInfo,
        'p_notes': notes,
      });
      return SupplierSettlement.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<List<BillOfExchange>> fetchBills({
    String? search,
    String? status,
    String? supplierId,
    String? settlementId,
    DateTime? dueFrom,
    DateTime? dueTo,
    int limit = 200,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client.from('bills_of_exchange').select(
          '*, supplier:suppliers(name, address), purchase:purchases(document_number), settlement:supplier_settlements(bank_name, bank_agency, rib_code_banque, rib_code_agence, rib_compte, rib_cle, bill_place, aval_info)');
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('bill_number', '%$search%');
      }
      if (status != null) query = query.eq('status', status);
      if (supplierId != null) query = query.eq('supplier_id', supplierId);
      if (settlementId != null) query = query.eq('settlement_id', settlementId);
      if (dueFrom != null) query = query.gte('due_date', dueFrom.toIso8601String().split('T').first);
      if (dueTo != null) query = query.lte('due_date', dueTo.toIso8601String().split('T').first);
      final data = await query.order('due_date').range(offset, offset + limit - 1);
      return (data as List).map((e) => BillOfExchange.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<List<SupplierSettlement>> fetchSettlements({String? supplierId}) {
    return guard(() async {
      var query = client.from('supplier_settlements').select('*, supplier:suppliers(name), purchase:purchases(document_number)');
      if (supplierId != null) query = query.eq('supplier_id', supplierId);
      final data = await query.order('created_at', ascending: false);
      return (data as List).map((e) => SupplierSettlement.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<BillOfExchange> markPaid(String billId, {DateTime? paymentDate}) {
    return guard(() async {
      final result = await client.rpc('mark_bill_paid', params: {
        'p_bill_id': billId,
        'p_payment_date': (paymentDate ?? DateTime.now()).toIso8601String().split('T').first,
      });
      return BillOfExchange.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<BillOfExchange> cancelBill(String billId) {
    return guard(() async {
      final result = await client.rpc('cancel_bill', params: {'p_bill_id': billId});
      return BillOfExchange.fromMap(result as Map<String, dynamic>);
    });
  }
}
