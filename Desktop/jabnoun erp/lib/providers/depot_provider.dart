import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/depot.dart';
import '../repositories/depot_repository.dart';

final depotRepositoryProvider = Provider<DepotRepository>((ref) => DepotRepository());

final depotSearchProvider = StateProvider<String>((ref) => '');

final depotListProvider = FutureProvider<List<Depot>>((ref) async {
  final search = ref.watch(depotSearchProvider);
  return ref.watch(depotRepositoryProvider).fetchAll(search: search);
});

final activeDepotsProvider = FutureProvider<List<Depot>>((ref) async {
  return ref.watch(depotRepositoryProvider).fetchAll(activeOnly: true);
});
