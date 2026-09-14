import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_of_exchange.dart';
import '../repositories/bill_of_exchange_repository.dart';

final billOfExchangeRepositoryProvider = Provider<BillOfExchangeRepository>((ref) => BillOfExchangeRepository());

final billSearchProvider = StateProvider<String>((ref) => '');
final billStatusFilterProvider = StateProvider<String?>((ref) => null);
final billSupplierFilterProvider = StateProvider<String?>((ref) => null);
final billDueFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final billDueToFilterProvider = StateProvider<DateTime?>((ref) => null);

final billListProvider = FutureProvider<List<BillOfExchange>>((ref) async {
  final search = ref.watch(billSearchProvider);
  final status = ref.watch(billStatusFilterProvider);
  final supplierId = ref.watch(billSupplierFilterProvider);
  final dueFrom = ref.watch(billDueFromFilterProvider);
  final dueTo = ref.watch(billDueToFilterProvider);
  return ref.watch(billOfExchangeRepositoryProvider).fetchBills(
        search: search,
        status: status,
        supplierId: supplierId,
        dueFrom: dueFrom,
        dueTo: dueTo,
      );
});

final settlementListProvider = FutureProvider<List<SupplierSettlement>>((ref) {
  return ref.watch(billOfExchangeRepositoryProvider).fetchSettlements();
});
