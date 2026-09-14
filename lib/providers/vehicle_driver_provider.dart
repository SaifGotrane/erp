import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle_driver.dart';
import '../repositories/vehicle_driver_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository());
final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

final vehicleSearchProvider = StateProvider<String>((ref) => '');
final driverSearchProvider = StateProvider<String>((ref) => '');

final vehicleListProvider = FutureProvider<List<Vehicle>>((ref) async {
  final search = ref.watch(vehicleSearchProvider);
  return ref.watch(vehicleRepositoryProvider).fetchAll(search: search);
});

final driverListProvider = FutureProvider<List<Driver>>((ref) async {
  final search = ref.watch(driverSearchProvider);
  return ref.watch(driverRepositoryProvider).fetchAll(search: search);
});

final activeVehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  return ref.watch(vehicleRepositoryProvider).fetchAll(activeOnly: true);
});

final activeDriversProvider = FutureProvider<List<Driver>>((ref) {
  return ref.watch(driverRepositoryProvider).fetchAll(activeOnly: true);
});
