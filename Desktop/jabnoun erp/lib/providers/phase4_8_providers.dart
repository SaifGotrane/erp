import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../models/sale_sub_invoice.dart';
import '../models/delivery_note.dart';
import '../models/returns.dart';
import '../models/pos_finance.dart';
import '../repositories/phase4_8_repositories.dart';

// --- Repository providers ---

final saleRepositoryProvider = Provider<SaleRepository>((ref) => SaleRepository());
final deliveryNoteRepositoryProvider = Provider<DeliveryNoteRepository>((ref) => DeliveryNoteRepository());
final supplierReturnRepositoryProvider = Provider<SupplierReturnRepository>((ref) => SupplierReturnRepository());
final customerReturnRepositoryProvider = Provider<CustomerReturnRepository>((ref) => CustomerReturnRepository());
final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository());
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository());
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) => ExpenseRepository());
final adjustmentRepositoryProvider = Provider<AdjustmentRepository>((ref) => AdjustmentRepository());
final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository());

// --- Sales: list state + provider ---

final saleSearchProvider = StateProvider<String>((ref) => '');
final saleStatusFilterProvider = StateProvider<String?>((ref) => null);
final saleCustomerFilterProvider = StateProvider<String?>((ref) => null);
final saleDateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final saleDateToFilterProvider = StateProvider<DateTime?>((ref) => null);

final saleListProvider = FutureProvider<List<Sale>>((ref) async {
  final search = ref.watch(saleSearchProvider);
  final status = ref.watch(saleStatusFilterProvider);
  final customerId = ref.watch(saleCustomerFilterProvider);
  final from = ref.watch(saleDateFromFilterProvider);
  final to = ref.watch(saleDateToFilterProvider);
  return ref.watch(saleRepositoryProvider).fetchAll(
        search: search,
        status: status,
        customerId: customerId,
        from: from,
        to: to,
      );
});

final saleSubInvoicesProvider = FutureProvider.family<List<SaleSubInvoice>, String>((ref, saleId) {
  return ref.watch(saleRepositoryProvider).fetchSubInvoices(saleId);
});

final saleSubClientHistoryProvider = FutureProvider.family<List<SaleSubInvoice>, String>((ref, customerId) {
  return ref.watch(saleRepositoryProvider).fetchSubClientHistory(customerId);
});

// --- Delivery notes: list state + provider ---

final deliverySearchProvider = StateProvider<String>((ref) => '');
final deliveryStatusFilterProvider = StateProvider<String?>((ref) => null);
final deliveryCustomerFilterProvider = StateProvider<String?>((ref) => null);
final deliveryDateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final deliveryDateToFilterProvider = StateProvider<DateTime?>((ref) => null);

final deliveryListProvider = FutureProvider<List<DeliveryNote>>((ref) async {
  final search = ref.watch(deliverySearchProvider);
  final status = ref.watch(deliveryStatusFilterProvider);
  final customerId = ref.watch(deliveryCustomerFilterProvider);
  final from = ref.watch(deliveryDateFromFilterProvider);
  final to = ref.watch(deliveryDateToFilterProvider);
  return ref.watch(deliveryNoteRepositoryProvider).fetchAll(
        search: search,
        status: status,
        customerId: customerId,
        from: from,
        to: to,
      );
});

// --- Supplier returns ---

final supplierReturnSearchProvider = StateProvider<String>((ref) => '');
final supplierReturnStatusFilterProvider = StateProvider<String?>((ref) => null);

final supplierReturnListProvider = FutureProvider<List<SupplierReturn>>((ref) async {
  final search = ref.watch(supplierReturnSearchProvider);
  final status = ref.watch(supplierReturnStatusFilterProvider);
  return ref.watch(supplierReturnRepositoryProvider).fetchAll(search: search, status: status);
});

// --- Customer returns ---

final customerReturnSearchProvider = StateProvider<String>((ref) => '');
final customerReturnStatusFilterProvider = StateProvider<String?>((ref) => null);

final customerReturnListProvider = FutureProvider<List<CustomerReturn>>((ref) async {
  final search = ref.watch(customerReturnSearchProvider);
  final status = ref.watch(customerReturnStatusFilterProvider);
  return ref.watch(customerReturnRepositoryProvider).fetchAll(search: search, status: status);
});

// --- POS sessions ---

final posSessionStatusFilterProvider = StateProvider<String?>((ref) => null);

final posSessionListProvider = FutureProvider<List<PosSession>>((ref) async {
  final status = ref.watch(posSessionStatusFilterProvider);
  return ref.watch(posRepositoryProvider).fetchAll(status: status);
});

final currentOpenSessionProvider = FutureProvider<PosSession?>((ref) {
  return ref.watch(posRepositoryProvider).fetchOpenSession();
});

// --- Payments ---

final paymentTypeFilterProvider = StateProvider<String?>((ref) => null);

final paymentListProvider = FutureProvider<List<Payment>>((ref) async {
  final type = ref.watch(paymentTypeFilterProvider);
  return ref.watch(paymentRepositoryProvider).fetchAll(paymentType: type);
});

// --- Expenses ---

final expenseSearchProvider = StateProvider<String>((ref) => '');

final expenseListProvider = FutureProvider<List<Expense>>((ref) async {
  final search = ref.watch(expenseSearchProvider);
  return ref.watch(expenseRepositoryProvider).fetchAll(search: search);
});

// --- Adjustments ---

final adjustmentSearchProvider = StateProvider<String>((ref) => '');
final adjustmentStatusFilterProvider = StateProvider<String?>((ref) => null);

final adjustmentListProvider = FutureProvider<List<StockAdjustment>>((ref) async {
  final search = ref.watch(adjustmentSearchProvider);
  final status = ref.watch(adjustmentStatusFilterProvider);
  return ref.watch(adjustmentRepositoryProvider).fetchAll(search: search, status: status);
});

// --- Reports ---

final reportDateFromProvider = StateProvider<DateTime?>((ref) => null);
final reportDateToProvider = StateProvider<DateTime?>((ref) => null);

final salesReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final from = ref.watch(reportDateFromProvider);
  final to = ref.watch(reportDateToProvider);
  return ref.watch(reportRepositoryProvider).salesSummary(from: from, to: to);
});

final purchasesReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final from = ref.watch(reportDateFromProvider);
  final to = ref.watch(reportDateToProvider);
  return ref.watch(reportRepositoryProvider).purchasesSummary(from: from, to: to);
});

final salesMarginReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final from = ref.watch(reportDateFromProvider);
  final to = ref.watch(reportDateToProvider);
  return ref.watch(reportRepositoryProvider).salesMargin(from: from, to: to);
});

final stockValuationProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(reportRepositoryProvider).stockValuation();
});

final tvaReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final from = ref.watch(reportDateFromProvider);
  final to = ref.watch(reportDateToProvider);
  return ref.watch(reportRepositoryProvider).tvaSummary(from: from, to: to);
});

final partnerStatementProvider = FutureProvider.family<List<Map<String, dynamic>>, (String, String)>(
  (ref, params) async {
    final from = ref.watch(reportDateFromProvider);
    final to = ref.watch(reportDateToProvider);
    return ref.watch(reportRepositoryProvider).partnerStatement(
          partnerType: params.$1,
          partnerId: params.$2,
          from: from,
          to: to,
        );
  },
);
