import '../models/purchase.dart';
import 'base_repository.dart';

class PurchaseRepository extends BaseRepository {
  Future<List<Purchase>> fetchAll({
    String? search,
    String? status,
    String? supplierId,
    String? depotId,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('purchases')
          .select('*, supplier:suppliers(name), depot:depots(name), purchase_lines(*, article:articles(reference, designation))');
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('document_number.ilike.%$search%,supplier_document_ref.ilike.%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      if (supplierId != null) {
        query = query.eq('supplier_id', supplierId);
      }
      if (depotId != null) {
        query = query.eq('depot_id', depotId);
      }
      final data = await query.order('purchase_date', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => Purchase.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Purchase> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('purchases')
          .select('*, supplier:suppliers(name), depot:depots(name), purchase_lines(*, article:articles(reference, designation))')
          .eq('id', id)
          .single();
      return Purchase.fromMap(data);
    });
  }

  /// Creates a draft purchase with lines in a single round-trip.
  Future<Purchase> createDraft({
    required String supplierId,
    required String depotId,
    required DateTime purchaseDate,
    String? paymentMethodId,
    String? supplierDocumentRef,
    double discountPercent = 0,
    String? notes,
    required List<PurchaseLine> lines,
  }) {
    return guard(() async {
      final docNumber = await client.rpc('next_document_number', params: {'p_prefix': 'ACH'}) as String;

      // Compute totals client-side (server will recalculate on validate).
      double totalHt = 0, totalTva = 0, totalTtc = 0;
      for (final line in lines) {
        final netHt = line.lineTotalHt;
        totalHt += netHt;
        totalTva += line.lineTotalTva;
        totalTtc += line.lineTotalTtc;
      }

      final purchaseData = await client.from('purchases').insert({
        'document_number': docNumber,
        'supplier_id': supplierId,
        'depot_id': depotId,
        'purchase_date': purchaseDate.toIso8601String().split('T').first,
        'status': 'brouillon',
        'payment_method_id': paymentMethodId,
        'supplier_document_ref': supplierDocumentRef?.isEmpty == true ? null : supplierDocumentRef,
        'discount_percent': discountPercent,
        'total_ht': totalHt,
        'total_tva': totalTva,
        'total_ttc': totalTtc,
        'notes': notes?.isEmpty == true ? null : notes,
        'created_by': client.auth.currentUser?.id,
      }).select().single();

      final purchaseId = purchaseData['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map((l) => {
                  'purchase_id': purchaseId,
                  'article_id': l.articleId,
                  'quantity': l.quantity,
                  'unit_price_ht': l.unitPriceHt,
                  'tax_rate_percent': l.taxRatePercent,
                  'discount_percent': l.discountPercent,
                  'line_total_ht': l.lineTotalHt,
                  'line_total_tva': l.lineTotalTva,
                  'line_total_ttc': l.lineTotalTtc,
                })
            .toList();
        await client.from('purchase_lines').insert(lineMaps);
      }

      return fetchById(purchaseId);
    });
  }

  Future<Purchase> updateDraft(String id, Map<String, dynamic> changes) {
    return guard(() async {
      await client.from('purchases').update(changes).eq('id', id);
      return fetchById(id);
    });
  }

  Future<void> replaceLines(String purchaseId, List<PurchaseLine> lines) {
    return guard(() async {
      await client.from('purchase_lines').delete().eq('purchase_id', purchaseId);
      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map((l) => {
                  'purchase_id': purchaseId,
                  'article_id': l.articleId,
                  'quantity': l.quantity,
                  'unit_price_ht': l.unitPriceHt,
                  'tax_rate_percent': l.taxRatePercent,
                  'discount_percent': l.discountPercent,
                  'line_total_ht': l.lineTotalHt,
                  'line_total_tva': l.lineTotalTva,
                  'line_total_ttc': l.lineTotalTtc,
                })
            .toList();
        await client.from('purchase_lines').insert(lineMaps);
      }
    });
  }

  Future<Purchase> validate(String id) {
    return guard(() async {
      final result = await client.rpc('validate_purchase', params: {'p_purchase_id': id});
      return Purchase.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<Purchase> cancel(String id) {
    return guard(() async {
      final result = await client.rpc('cancel_purchase', params: {'p_purchase_id': id});
      return Purchase.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('purchases').delete().eq('id', id));
  }
}
