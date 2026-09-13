import '../core/constants/app_constants.dart';
import '../models/employee.dart';
import 'base_repository.dart';

class EmployeeRepository extends BaseRepository {
  Future<List<Employee>> fetchAll({String? search}) {
    return guard(() async {
      var query = client.from('employees').select();
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('full_name.ilike.%$search%,email.ilike.%$search%');
      }
      final data = await query.order('full_name');
      return (data as List).map((e) => Employee.fromMap(e as Map<String, dynamic>)).toList();
    });
  }

  /// Crée un employé : appelle une Edge Function Supabase (`create-employee`)
  /// qui utilise la clé service_role côté serveur pour créer l'utilisateur
  /// Auth puis la ligne `employees`. Ne jamais exposer service_role côté client.
  Future<void> createEmployee({
    required String fullName,
    required String email,
    required String password,
    required EmployeeRole role,
    String? phone,
    String? depotId,
    String? showroomId,
  }) {
    return guard(() async {
      await client.functions.invoke('create-employee', body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': employeeRoleToString(role),
        'phone': phone,
        'depot_id': depotId,
        'showroom_id': showroomId,
      });
    });
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> changes) {
    return guard(() => client.from('employees').update(changes).eq('id', id));
  }

  Future<void> setActive(String id, bool active) {
    return guard(() => client.from('employees').update({'active': active}).eq('id', id));
  }

  /// Réinitialise le mot de passe d'un employé via Edge Function
  /// (`reset-employee-password`), protégée côté serveur.
  Future<void> resetPassword(String employeeId, String newPassword) {
    return guard(() => client.functions.invoke('reset-employee-password', body: {
          'employee_id': employeeId,
          'new_password': newPassword,
        }));
  }

  Future<List<EmployeePermission>> fetchPermissions(String employeeId) {
    return guard(() async {
      final data = await client.from('employee_permissions').select().eq('employee_id', employeeId);
      return (data as List)
          .map((e) => EmployeePermission.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Enregistre l'ensemble des permissions d'un employé (upsert en masse).
  Future<void> savePermissions(String employeeId, List<EmployeePermission> permissions) {
    return guard(() async {
      final rows = permissions.map((p) => p.toMap()).toList();
      await client.from('employee_permissions').upsert(rows, onConflict: 'employee_id,module,action');
    });
  }

  /// Retourne la matrice complète module x action initialisée à `false`
  /// pour un nouvel employé (avant sauvegarde).
  static List<EmployeePermission> emptyPermissionMatrix(String employeeId) {
    final result = <EmployeePermission>[];
    for (final module in PermissionModule.all) {
      for (final action in _actionsForModule(module)) {
        result.add(EmployeePermission(employeeId: employeeId, module: module, action: action, allowed: false));
      }
    }
    return result;
  }

  static List<String> _actionsForModule(String module) {
    switch (module) {
      case PermissionModule.purchases:
      case PermissionModule.sales:
        return [
          PermissionAction.view,
          PermissionAction.create,
          PermissionAction.edit,
          PermissionAction.validate,
          PermissionAction.cancel,
        ];
      case PermissionModule.supplierReturns:
      case PermissionModule.customerReturns:
        return [
          PermissionAction.view,
          PermissionAction.create,
          PermissionAction.edit,
          PermissionAction.validate,
          PermissionAction.cancel,
        ];
      case PermissionModule.stock:
        return [PermissionAction.view, PermissionAction.adjustStock, PermissionAction.transferStock];
      case PermissionModule.pos:
        return [
          PermissionAction.openPos,
          PermissionAction.sellPos,
          PermissionAction.cancelSalePos,
          PermissionAction.closePos,
          PermissionAction.viewRevenuePos,
        ];
      case PermissionModule.reports:
        return [PermissionAction.view, PermissionAction.export];
      case PermissionModule.journalisation:
        return [PermissionAction.view];
      case PermissionModule.settings:
        return [PermissionAction.edit];
      case PermissionModule.subInvoices:
        return [PermissionAction.view, PermissionAction.create, PermissionAction.edit];
      case PermissionModule.billsOfExchange:
        return [
          PermissionAction.view,
          PermissionAction.create,
          PermissionAction.edit,
          PermissionAction.markPaid,
          PermissionAction.print,
        ];
      case PermissionModule.supplierSettlements:
        return [PermissionAction.view, PermissionAction.create, PermissionAction.edit];
      case PermissionModule.sav:
        return [
          PermissionAction.view,
          PermissionAction.create,
          PermissionAction.edit,
          PermissionAction.resolve,
        ];
      default:
        return [
          PermissionAction.view,
          PermissionAction.create,
          PermissionAction.edit,
          PermissionAction.delete,
        ];
    }
  }
}
