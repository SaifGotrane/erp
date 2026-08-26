import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/partner.dart';
import '../repositories/partner_repository.dart';

final supplierRepositoryProvider =
    Provider<PartnerRepository>((ref) => PartnerRepository('suppliers'));
final customerRepositoryProvider =
    Provider<PartnerRepository>((ref) => PartnerRepository('customers'));

final supplierSearchProvider = StateProvider<String>((ref) => '');
final customerSearchProvider = StateProvider<String>((ref) => '');

final supplierListProvider = FutureProvider<List<Partner>>((ref) async {
  final search = ref.watch(supplierSearchProvider);
  return ref.watch(supplierRepositoryProvider).fetchAll(search: search);
});

final customerListProvider = FutureProvider<List<Partner>>((ref) async {
  final search = ref.watch(customerSearchProvider);
  return ref.watch(customerRepositoryProvider).fetchAll(search: search);
});
