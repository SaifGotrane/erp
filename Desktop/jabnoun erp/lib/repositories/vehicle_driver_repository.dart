import '../models/vehicle_driver.dart';
import 'base_repository.dart';

class VehicleRepository extends BaseRepository {
  Future<List<Vehicle>> fetchAll({String? search, bool? activeOnly}) {
    return guard(() async {
      var query = client.from('vehicles').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('registration_number', '%$search%');
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data = await query.order('registration_number');
      return (data as List).map((e) => Vehicle.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Vehicle> create(Vehicle vehicle) {
    return guard(() async {
      final data = await client.from('vehicles').insert(vehicle.toInsertMap()).select().single();
      return Vehicle.fromMap(data);
    });
  }

  Future<Vehicle> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data = await client.from('vehicles').update(changes).eq('id', id).select().single();
      return Vehicle.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('vehicles').update({'active': active}).eq('id', id));
  }
}

class DriverRepository extends BaseRepository {
  Future<List<Driver>> fetchAll({String? search, bool? activeOnly}) {
    return guard(() async {
      var query = client.from('drivers').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('full_name', '%$search%');
      }
      if (activeOnly == true) {
        query = query.eq('active', true);
      }
      final data = await query.order('full_name');
      return (data as List).map((e) => Driver.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Driver> create(Driver driver) {
    return guard(() async {
      final data = await client.from('drivers').insert(driver.toInsertMap()).select().single();
      return Driver.fromMap(data);
    });
  }

  Future<Driver> update(String id, Map<String, dynamic> changes) {
    return guard(() async {
      final data = await client.from('drivers').update(changes).eq('id', id).select().single();
      return Driver.fromMap(data);
    });
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('drivers').update({'active': active}).eq('id', id));
  }
}
