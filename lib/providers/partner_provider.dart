import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/partner.dart';
import '../repositories/partner_repository.dart';

final supplierRepositoryProvider =
    Provider<PartnerRepository>((ref) => PartnerRepository('suppliers'));
final customerRepositoryProvider =
    Provider<PartnerRepository>((ref) => PartnerRepository('customers'));

final supplierSearchProvider = StateProvider<String>((ref) => '');
final customerSearchProvider = StateProvider<String>((ref) => '');
final supplierGovernorateFilterProvider = StateProvider<String?>((ref) => null);
final customerGovernorateFilterProvider = StateProvider<String?>((ref) => null);

final supplierListProvider = FutureProvider<List<Partner>>((ref) async {
  final search = ref.watch(supplierSearchProvider);
  final governorate = ref.watch(supplierGovernorateFilterProvider);
  return ref.watch(supplierRepositoryProvider).fetchAll(search: search, governorate: governorate);
});

final customerListProvider = FutureProvider<List<Partner>>((ref) async {
  final search = ref.watch(customerSearchProvider);
  final governorate = ref.watch(customerGovernorateFilterProvider);
  return ref.watch(customerRepositoryProvider).fetchAll(search: search, governorate: governorate);
});
