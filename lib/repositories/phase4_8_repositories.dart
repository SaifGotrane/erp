import '../models/sale.dart';
import '../models/sale_sub_invoice.dart';
import '../models/delivery_note.dart';
import '../models/returns.dart';
import '../models/pos_finance.dart';
import 'base_repository.dart';

class SaleRepository extends BaseRepository {
  Future<List<Sale>> fetchAll({
    String? search,
    String? status,
    String? customerId,
    DateTime? from,
    DateTime? to,
    bool posOnly = false,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('sales')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), sale_lines(*, article:articles(reference, designation)), sale_sub_invoices(count)',
          );
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }
      if (from != null) {
        query = query.gte('sale_date', from.toIso8601String().split('T').first);
      }
      if (to != null) {
        query = query.lte('sale_date', to.toIso8601String().split('T').first);
      }
      if (posOnly) {
        query = query.eq('is_pos', true);
      }
      final data = await query
          .order('sale_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Sale.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Sale> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('sales')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), sale_lines(*, article:articles(reference, designation))',
          )
          .eq('id', id)
          .single();
      return Sale.fromMap(data);
    });
  }

  Future<Sale> createDraft({
    required String customerId,
    String? depotId,
    String? showroomId,
    required DateTime saleDate,
    String? paymentMethodId,
    double discountPercent = 0,
    bool isPos = false,
    String? posSessionId,
    String? notes,
    String? customerDisplayName,
    required List<SaleLine> lines,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'VTE'})
              as String;

      double totalHt = 0, totalTva = 0, totalTtc = 0;
      for (final line in lines) {
        totalHt += line.lineTotalHt;
        totalTva += line.lineTotalTva;
        totalTtc += line.lineTotalTtc;
      }

      final data = await client
          .from('sales')
          .insert({
            'document_number': docNumber,
            'customer_id': customerId,
            'depot_id': depotId,
            'showroom_id': showroomId,
            'sale_date': saleDate.toIso8601String().split('T').first,
            'status': 'brouillon',
            'payment_method_id': paymentMethodId,
            'discount_percent': discountPercent,
            'total_ht': totalHt,
            'total_tva': totalTva,
            'total_ttc': totalTtc,
            'is_pos': isPos,
            'pos_session_id': posSessionId,
            'notes': notes?.isEmpty == true ? null : notes,
            'customer_display_name': customerDisplayName?.isEmpty == true ? null : customerDisplayName,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final saleId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'sale_id': saleId,
                'article_id': l.articleId,
                'quantity': l.quantity,
                'unit_price_ht': l.unitPriceHt,
                'tax_rate_percent': l.taxRatePercent,
                'discount_percent': l.discountPercent,
                'line_total_ht': l.lineTotalHt,
                'line_total_tva': l.lineTotalTva,
                'line_total_ttc': l.lineTotalTtc,
              },
            )
            .toList();
        await client.from('sale_lines').insert(lineMaps);
      }

      return fetchById(saleId);
    });
  }

  Future<Sale> updateDraft(String id, Map<String, dynamic> changes) {
    return guard(() async {
      await client.from('sales').update(changes).eq('id', id);
      return fetchById(id);
    });
  }

  Future<void> replaceLines(String saleId, List<SaleLine> lines) {
    return guard(() async {
      await client.from('sale_lines').delete().eq('sale_id', saleId);
      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'sale_id': saleId,
                'article_id': l.articleId,
                'quantity': l.quantity,
                'unit_price_ht': l.unitPriceHt,
                'tax_rate_percent': l.taxRatePercent,
                'discount_percent': l.discountPercent,
                'line_total_ht': l.lineTotalHt,
                'line_total_tva': l.lineTotalTva,
                'line_total_ttc': l.lineTotalTtc,
              },
            )
            .toList();
        await client.from('sale_lines').insert(lineMaps);
      }
    });
  }

  Future<Sale> validate(String id) {
    return guard(() async {
      final result = await client.rpc(
        'validate_sale',
        params: {'p_sale_id': id},
      );
      return Sale.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<Sale> cancel(String id) {
    return guard(() async {
      final result = await client.rpc('cancel_sale', params: {'p_sale_id': id});
      return Sale.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('sales').delete().eq('id', id));
  }

  Future<List<SaleSubInvoice>> fetchSubInvoices(String saleId) {
    return guard(() async {
      final data = await client
          .from('sale_sub_invoices')
          .select('*, customer:customers(name), sale_sub_invoice_lines(*, article:articles(reference, designation))')
          .eq('sale_id', saleId)
          .order('created_at');
      return (data as List)
          .map((e) => SaleSubInvoice.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<SaleSubInvoice> addSubInvoiceWithLines({
    required String saleId,
    required String subClientId,
    required List<Map<String, dynamic>> lines,
    String? notes,
  }) {
    return guard(() async {
      final result = await client.rpc('add_sale_sub_invoice_with_lines', params: {
        'p_sale_id': saleId,
        'p_sub_client_id': subClientId,
        'p_lines': lines,
        'p_notes': notes,
      });
      return SaleSubInvoice.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<SaleSubInvoice> addSubInvoice({
    required String saleId,
    required String subClientName,
    required double amount,
    String? customerId,
    String? notes,
  }) {
    return guard(() async {
      final result = await client.rpc('add_sale_sub_invoice', params: {
        'p_sale_id': saleId,
        'p_sub_client_name': subClientName,
        'p_amount': amount,
        'p_customer_id': customerId,
        'p_notes': notes,
      });
      return SaleSubInvoice.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> deleteSubInvoice(String id) {
    return guard(() => client.rpc('delete_sale_sub_invoice', params: {'p_id': id}));
  }

  /// Sous-clients déjà utilisés pour ce client (toutes factures confondues),
  /// afin de pouvoir les réutiliser lors d'un prochain fractionnement plutôt
  /// que d'en générer un nouveau à chaque fois.
  Future<List<SaleSubInvoice>> fetchSubClientHistory(String customerId) {
    return guard(() async {
      final data = await client
          .from('sale_sub_invoices')
          .select('*, customer:customers(name), sale:sales!inner(customer_id)')
          .eq('sale.customer_id', customerId)
          .order('created_at', ascending: false);
      final seen = <String>{};
      final result = <SaleSubInvoice>[];
      for (final e in (data as List)) {
        final sub = SaleSubInvoice.fromMap(e as Map<String, dynamic>);
        final key = '${sub.subClientName}|${sub.customerId ?? ''}';
        if (seen.add(key)) result.add(sub);
      }
      return result;
    });
  }
}

class DeliveryNoteRepository extends BaseRepository {
  Future<List<DeliveryNote>> fetchAll({
    String? search,
    String? status,
    String? customerId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('delivery_notes')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), delivery_note_lines(*, article:articles(reference, designation))',
          );
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }
      if (from != null) {
        query = query.gte('delivery_date', from.toIso8601String().split('T').first);
      }
      if (to != null) {
        query = query.lte('delivery_date', to.toIso8601String().split('T').first);
      }
      final data = await query
          .order('delivery_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => DeliveryNote.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<DeliveryNote> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('delivery_notes')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), delivery_note_lines(*, article:articles(reference, designation))',
          )
          .eq('id', id)
          .single();
      return DeliveryNote.fromMap(data);
    });
  }

  Future<DeliveryNote> createDraft({
    required String customerId,
    String? saleId,
    String? depotId,
    String? showroomId,
    required DateTime deliveryDate,
    String? vehicleId,
    String? driverId,
    String? notes,
    required List<DeliveryNoteLine> lines,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'BL'})
              as String;

      final data = await client
          .from('delivery_notes')
          .insert({
            'document_number': docNumber,
            'customer_id': customerId,
            'sale_id': saleId,
            'depot_id': depotId,
            'showroom_id': showroomId,
            'delivery_date': deliveryDate.toIso8601String().split('T').first,
            'status': 'brouillon',
            'vehicle_id': vehicleId,
            'driver_id': driverId,
            'notes': notes?.isEmpty == true ? null : notes,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final dnId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'delivery_note_id': dnId,
                'article_id': l.articleId,
                'quantity': l.quantity,
              },
            )
            .toList();
        await client.from('delivery_note_lines').insert(lineMaps);
      }

      return fetchById(dnId);
    });
  }

  Future<DeliveryNote> validate(String id) {
    return guard(() async {
      final result = await client.rpc(
        'validate_delivery',
        params: {'p_delivery_id': id},
      );
      return DeliveryNote.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<DeliveryNote> cancel(String id) {
    return guard(() async {
      final result = await client.rpc(
        'cancel_delivery',
        params: {'p_delivery_id': id},
      );
      return DeliveryNote.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('delivery_notes').delete().eq('id', id));
  }
}

class SupplierReturnRepository extends BaseRepository {
  Future<List<SupplierReturn>> fetchAll({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('supplier_returns')
          .select(
            '*, supplier:suppliers(name), depot:depots(name), supplier_return_lines(*, article:articles(reference, designation))',
          );
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query
          .order('return_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => SupplierReturn.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<SupplierReturn> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('supplier_returns')
          .select(
            '*, supplier:suppliers(name), depot:depots(name), supplier_return_lines(*, article:articles(reference, designation))',
          )
          .eq('id', id)
          .single();
      return SupplierReturn.fromMap(data);
    });
  }

  Future<SupplierReturn> createDraft({
    required String supplierId,
    String? purchaseId,
    required String depotId,
    required DateTime returnDate,
    String? notes,
    required List<SupplierReturnLine> lines,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'RF'})
              as String;

      double totalHt = 0, totalTva = 0, totalTtc = 0;
      for (final line in lines) {
        totalHt += line.lineTotalHt;
        totalTva += line.lineTotalTva;
        totalTtc += line.lineTotalTtc;
      }

      final data = await client
          .from('supplier_returns')
          .insert({
            'document_number': docNumber,
            'supplier_id': supplierId,
            'purchase_id': purchaseId,
            'depot_id': depotId,
            'return_date': returnDate.toIso8601String().split('T').first,
            'status': 'brouillon',
            'total_ht': totalHt,
            'total_tva': totalTva,
            'total_ttc': totalTtc,
            'notes': notes?.isEmpty == true ? null : notes,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final retId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'supplier_return_id': retId,
                'article_id': l.articleId,
                'quantity': l.quantity,
                'unit_price_ht': l.unitPriceHt,
                'tax_rate_percent': l.taxRatePercent,
                'line_total_ht': l.lineTotalHt,
                'line_total_tva': l.lineTotalTva,
                'line_total_ttc': l.lineTotalTtc,
              },
            )
            .toList();
        await client.from('supplier_return_lines').insert(lineMaps);
      }

      return fetchById(retId);
    });
  }

  Future<SupplierReturn> validate(String id) {
    return guard(() async {
      final result = await client.rpc(
        'validate_supplier_return',
        params: {'p_return_id': id},
      );
      return SupplierReturn.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<SupplierReturn> cancel(String id) {
    return guard(() async {
      final result = await client.rpc(
        'cancel_supplier_return',
        params: {'p_return_id': id},
      );
      return SupplierReturn.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('supplier_returns').delete().eq('id', id));
  }
}

class CustomerReturnRepository extends BaseRepository {
  Future<List<CustomerReturn>> fetchAll({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('customer_returns')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), customer_return_lines(*, article:articles(reference, designation))',
          );
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query
          .order('return_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => CustomerReturn.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<CustomerReturn> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('customer_returns')
          .select(
            '*, customer:customers(name), depot:depots(name), showroom:showrooms(name), customer_return_lines(*, article:articles(reference, designation))',
          )
          .eq('id', id)
          .single();
      return CustomerReturn.fromMap(data);
    });
  }

  Future<CustomerReturn> createDraft({
    required String customerId,
    String? saleId,
    String? depotId,
    String? showroomId,
    required DateTime returnDate,
    String? notes,
    required List<CustomerReturnLine> lines,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'RC'})
              as String;

      double totalHt = 0, totalTva = 0, totalTtc = 0;
      for (final line in lines) {
        totalHt += line.lineTotalHt;
        totalTva += line.lineTotalTva;
        totalTtc += line.lineTotalTtc;
      }

      final data = await client
          .from('customer_returns')
          .insert({
            'document_number': docNumber,
            'customer_id': customerId,
            'sale_id': saleId,
            'depot_id': depotId,
            'showroom_id': showroomId,
            'return_date': returnDate.toIso8601String().split('T').first,
            'status': 'brouillon',
            'total_ht': totalHt,
            'total_tva': totalTva,
            'total_ttc': totalTtc,
            'notes': notes?.isEmpty == true ? null : notes,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final retId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'customer_return_id': retId,
                'article_id': l.articleId,
                'quantity': l.quantity,
                'unit_price_ht': l.unitPriceHt,
                'tax_rate_percent': l.taxRatePercent,
                'line_total_ht': l.lineTotalHt,
                'line_total_tva': l.lineTotalTva,
                'line_total_ttc': l.lineTotalTtc,
              },
            )
            .toList();
        await client.from('customer_return_lines').insert(lineMaps);
      }

      return fetchById(retId);
    });
  }

  Future<CustomerReturn> validate(String id) {
    return guard(() async {
      final result = await client.rpc(
        'validate_customer_return',
        params: {'p_return_id': id},
      );
      return CustomerReturn.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<CustomerReturn> cancel(String id) {
    return guard(() async {
      final result = await client.rpc(
        'cancel_customer_return',
        params: {'p_return_id': id},
      );
      return CustomerReturn.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('customer_returns').delete().eq('id', id));
  }
}

class PosRepository extends BaseRepository {
  Future<List<PosSession>> fetchAll({
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('pos_sessions')
          .select('*, showroom:showrooms(name), employee:employees(full_name)');
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query
          .order('opening_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => PosSession.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<PosSession?> fetchOpenSession() {
    return guard(() async {
      final data = await client
          .from('pos_sessions')
          .select('*, showroom:showrooms(name), employee:employees(full_name)')
          .eq('employee_id', client.auth.currentUser!.id)
          .eq('status', 'ouverte')
          .maybeSingle();
      return data == null ? null : PosSession.fromMap(data);
    });
  }

  Future<PosSession> openSession({String? showroomId, double openingCash = 0}) {
    return guard(() async {
      final result = await client.rpc(
        'open_pos_session',
        params: {'p_showroom_id': showroomId, 'p_opening_cash': openingCash},
      );
      return PosSession.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<PosSession> closeSession(
    String sessionId,
    double closingCash, {
    String? notes,
  }) {
    return guard(() async {
      final result = await client.rpc(
        'close_pos_session',
        params: {
          'p_session_id': sessionId,
          'p_closing_cash': closingCash,
          'p_notes': notes,
        },
      );
      return PosSession.fromMap(result as Map<String, dynamic>);
    });
  }
}

class PaymentRepository extends BaseRepository {
  Future<List<Payment>> fetchAll({
    String? paymentType,
    String? partnerType,
    String? partnerId,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('payments')
          .select('*, payment_method:payment_methods(name)');
      if (paymentType != null) {
        query = query.eq('payment_type', paymentType);
      }
      if (partnerType != null) {
        query = query.eq('partner_type', partnerType);
      }
      if (partnerId != null) {
        query = query.eq('partner_id', partnerId);
      }
      final data = await query
          .order('payment_date', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (data as List).cast<Map<String, dynamic>>();

      // Enrich partner names
      final result = <Payment>[];
      for (final row in list) {
        if (row['partner_type'] == 'customer') {
          final c = await client
              .from('customers')
              .select('name')
              .eq('id', row['partner_id'] as String)
              .maybeSingle();
          row['partner_name'] = c?['name'];
        } else {
          final s = await client
              .from('suppliers')
              .select('name')
              .eq('id', row['partner_id'] as String)
              .maybeSingle();
          row['partner_name'] = s?['name'];
        }
        result.add(Payment.fromMap(row));
      }
      return result;
    });
  }

  Future<Payment> recordPayment({
    required String paymentType,
    required String partnerType,
    required String partnerId,
    required double amount,
    String? paymentMethodId,
    String? saleId,
    String? purchaseId,
    DateTime? paymentDate,
    String? notes,
  }) {
    return guard(() async {
      final result = await client.rpc(
        'record_payment',
        params: {
          'p_payment_type': paymentType,
          'p_partner_type': partnerType,
          'p_partner_id': partnerId,
          'p_amount': amount,
          'p_payment_method_id': paymentMethodId,
          'p_sale_id': saleId,
          'p_purchase_id': purchaseId,
          'p_payment_date': paymentDate?.toIso8601String().split('T').first,
          'p_notes': notes,
        },
      );
      return Payment.fromMap(result as Map<String, dynamic>);
    });
  }
}

class ExpenseRepository extends BaseRepository {
  Future<List<Expense>> fetchAll({
    String? search,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('expenses')
          .select('*, payment_method:payment_methods(name)');
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('label.ilike.%$search%,category.ilike.%$search%');
      }
      final data = await query
          .order('expense_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Expense.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Expense> create({
    required String label,
    required double amount,
    DateTime? expenseDate,
    String? category,
    String? paymentMethodId,
    String? depotId,
    String? showroomId,
    String? notes,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'CHG'})
              as String;
      final data = await client
          .from('expenses')
          .insert({
            'document_number': docNumber,
            'expense_date': (expenseDate ?? DateTime.now())
                .toIso8601String()
                .split('T')
                .first,
            'category': category?.isEmpty == true ? null : category,
            'label': label,
            'amount': amount,
            'payment_method_id': paymentMethodId,
            'depot_id': depotId,
            'showroom_id': showroomId,
            'notes': notes?.isEmpty == true ? null : notes,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();
      return Expense.fromMap(data);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('expenses').delete().eq('id', id));
  }
}

class AdjustmentRepository extends BaseRepository {
  Future<List<StockAdjustment>> fetchAll({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      var query = client
          .from('stock_adjustments')
          .select(
            '*, depot:depots(name), showroom:showrooms(name), stock_adjustment_lines(*, article:articles(reference, designation))',
          );
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('document_number', '%$search%');
      }
      if (status != null) {
        query = query.eq('status', status);
      }
      final data = await query
          .order('adjustment_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => StockAdjustment.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<StockAdjustment> fetchById(String id) {
    return guard(() async {
      final data = await client
          .from('stock_adjustments')
          .select(
            '*, depot:depots(name), showroom:showrooms(name), stock_adjustment_lines(*, article:articles(reference, designation))',
          )
          .eq('id', id)
          .single();
      return StockAdjustment.fromMap(data);
    });
  }

  Future<StockAdjustment> createDraft({
    required String? depotId,
    required String? showroomId,
    required DateTime adjustmentDate,
    required String reason,
    String? notes,
    required List<StockAdjustmentLine> lines,
  }) {
    return guard(() async {
      final docNumber =
          await client.rpc('next_document_number', params: {'p_prefix': 'ADJ'})
              as String;

      final data = await client
          .from('stock_adjustments')
          .insert({
            'document_number': docNumber,
            'depot_id': depotId,
            'showroom_id': showroomId,
            'adjustment_date': adjustmentDate
                .toIso8601String()
                .split('T')
                .first,
            'status': 'brouillon',
            'reason': reason,
            'notes': notes?.isEmpty == true ? null : notes,
            'created_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final adjId = data['id'] as String;

      if (lines.isNotEmpty) {
        final lineMaps = lines
            .map(
              (l) => {
                'adjustment_id': adjId,
                'article_id': l.articleId,
                'current_quantity': l.currentQuantity,
                'new_quantity': l.newQuantity,
                'delta': l.newQuantity - l.currentQuantity,
              },
            )
            .toList();
        await client.from('stock_adjustment_lines').insert(lineMaps);
      }

      return fetchById(adjId);
    });
  }

  Future<void> replaceLines(
    String adjustmentId,
    List<StockAdjustmentLine> lines,
  ) {
    return guard(() async {
      await client
          .from('stock_adjustment_lines')
          .delete()
          .eq('adjustment_id', adjustmentId);
      if (lines.isNotEmpty) {
        await client
            .from('stock_adjustment_lines')
            .insert(
              lines
                  .map(
                    (line) => {
                      'adjustment_id': adjustmentId,
                      'article_id': line.articleId,
                      'current_quantity': line.currentQuantity,
                      'new_quantity': line.newQuantity,
                      'delta': line.newQuantity - line.currentQuantity,
                    },
                  )
                  .toList(),
            );
      }
    });
  }

  Future<StockAdjustment> validate(String id) {
    return guard(() async {
      final result = await client.rpc(
        'validate_adjustment',
        params: {'p_adjustment_id': id},
      );
      return StockAdjustment.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<StockAdjustment> cancel(String id) {
    return guard(() async {
      final result = await client.rpc(
        'cancel_adjustment',
        params: {'p_adjustment_id': id},
      );
      return StockAdjustment.fromMap(result as Map<String, dynamic>);
    });
  }

  Future<void> delete(String id) {
    return guard(() => client.from('stock_adjustments').delete().eq('id', id));
  }
}

class ReportRepository extends BaseRepository {
  Future<Map<String, dynamic>> salesMargin({DateTime? from, DateTime? to}) {
    return guard(() async {
      final result = await client.rpc('report_sales_margin', params: {
        'p_from': from?.toIso8601String().split('T').first,
        'p_to': to?.toIso8601String().split('T').first,
      });
      final list = result as List;
      return list.isEmpty ? {} : list.first as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> salesSummary({DateTime? from, DateTime? to}) {
    return guard(() async {
      final result = await client.rpc(
        'report_sales_summary',
        params: {
          'p_from': from?.toIso8601String().split('T').first,
          'p_to': to?.toIso8601String().split('T').first,
        },
      );
      final list = result as List;
      if (list.isEmpty) return {};
      return list.first as Map<String, dynamic>;
    });
  }

  Future<Map<String, dynamic>> purchasesSummary({
    DateTime? from,
    DateTime? to,
  }) {
    return guard(() async {
      final result = await client.rpc(
        'report_purchases_summary',
        params: {
          'p_from': from?.toIso8601String().split('T').first,
          'p_to': to?.toIso8601String().split('T').first,
        },
      );
      final list = result as List;
      if (list.isEmpty) return {};
      return list.first as Map<String, dynamic>;
    });
  }

  Future<List<Map<String, dynamic>>> stockValuation({
    String? depotId,
    String? showroomId,
  }) {
    return guard(() async {
      final result = await client.rpc(
        'report_stock_valuation',
        params: {'p_depot_id': depotId, 'p_showroom_id': showroomId},
      );
      return (result as List).cast<Map<String, dynamic>>();
    });
  }

  Future<Map<String, dynamic>> tvaSummary({DateTime? from, DateTime? to}) {
    return guard(() async {
      final result = await client.rpc(
        'report_tva_summary',
        params: {
          'p_from': from?.toIso8601String().split('T').first,
          'p_to': to?.toIso8601String().split('T').first,
        },
      );
      final list = result as List;
      if (list.isEmpty) return {};
      return list.first as Map<String, dynamic>;
    });
  }

  Future<List<Map<String, dynamic>>> partnerStatement({
    required String partnerType,
    required String partnerId,
    DateTime? from,
    DateTime? to,
  }) {
    return guard(() async {
      final result = await client.rpc(
        'report_partner_statement',
        params: {
          'p_partner_type': partnerType,
          'p_partner_id': partnerId,
          'p_from': from?.toIso8601String().split('T').first,
          'p_to': to?.toIso8601String().split('T').first,
        },
      );
      return (result as List).cast<Map<String, dynamic>>();
    });
  }
}
