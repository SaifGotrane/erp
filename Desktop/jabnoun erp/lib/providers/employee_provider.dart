import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee.dart';
import '../repositories/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) => EmployeeRepository());

final employeeSearchProvider = StateProvider<String>((ref) => '');

final employeeListProvider = FutureProvider<List<Employee>>((ref) async {
  final search = ref.watch(employeeSearchProvider);
  return ref.watch(employeeRepositoryProvider).fetchAll(search: search);
});

final employeePermissionsProvider =
    FutureProvider.family<List<EmployeePermission>, String>((ref, employeeId) {
  return ref.watch(employeeRepositoryProvider).fetchPermissions(employeeId);
});
