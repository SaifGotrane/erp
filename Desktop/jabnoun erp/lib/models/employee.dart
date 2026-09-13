import 'package:equatable/equatable.dart';

/// Rôle global de l'employé. La granularité fine est gérée par
/// [EmployeePermission] (table employee_permissions).
enum EmployeeRole { admin, employee }

EmployeeRole employeeRoleFromString(String? value) {
  switch (value) {
    case 'admin':
      return EmployeeRole.admin;
    default:
      return EmployeeRole.employee;
  }
}

String employeeRoleToString(EmployeeRole role) =>
    role == EmployeeRole.admin ? 'admin' : 'employee';

class Employee extends Equatable {
  final String id; // = auth.users.id
  final String fullName;
  final String email;
  final String? phone;
  final EmployeeRole role;
  final bool active;
  final String? depotId;
  final String? showroomId;
  final double? maxDiscountPercent;
  final bool canApplyDiscount;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.active,
    this.depotId,
    this.showroomId,
    this.maxDiscountPercent,
    this.canApplyDiscount = false,
    required this.createdAt,
  });

  bool get isAdmin => role == EmployeeRole.admin;

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      role: employeeRoleFromString(map['role'] as String?),
      active: map['active'] as bool? ?? true,
      depotId: map['depot_id'] as String?,
      showroomId: map['showroom_id'] as String?,
      maxDiscountPercent: (map['max_discount_percent'] as num?)?.toDouble(),
      canApplyDiscount: map['can_apply_discount'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone?.isEmpty == true ? null : phone,
      'role': employeeRoleToString(role),
      'active': active,
      'depot_id': depotId,
      'showroom_id': showroomId,
      'max_discount_percent': maxDiscountPercent,
      'can_apply_discount': canApplyDiscount,
    };
  }

  @override
  List<Object?> get props => [id, fullName, email, phone, role, active, depotId, showroomId];
}

/// Une permission granulaire employé -> module -> action.
class EmployeePermission extends Equatable {
  final String employeeId;
  final String module;
  final String action;
  final bool allowed;

  const EmployeePermission({
    required this.employeeId,
    required this.module,
    required this.action,
    required this.allowed,
  });

  factory EmployeePermission.fromMap(Map<String, dynamic> map) {
    return EmployeePermission(
      employeeId: map['employee_id'] as String,
      module: map['module'] as String,
      action: map['action'] as String,
      allowed: map['allowed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'employee_id': employeeId,
        'module': module,
        'action': action,
        'allowed': allowed,
      };

  @override
  List<Object?> get props => [employeeId, module, action, allowed];
}
