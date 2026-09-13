import 'package:equatable/equatable.dart';

class Depot extends Equatable {
  final String id;
  final String code;
  final String name;
  final String? address;
  final String? phone;
  final String? responsibleEmployeeId;
  final bool active;
  final DateTime createdAt;

  const Depot({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.responsibleEmployeeId,
    required this.active,
    required this.createdAt,
  });

  factory Depot.fromMap(Map<String, dynamic> map) => Depot(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        responsibleEmployeeId: map['responsible_employee_id'] as String?,
        active: map['active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'code': code,
        'name': name,
        'address': address?.isEmpty == true ? null : address,
        'phone': phone?.isEmpty == true ? null : phone,
        'responsible_employee_id': responsibleEmployeeId,
        'active': active,
      };

  @override
  List<Object?> get props => [id, code, name, address, phone, responsibleEmployeeId, active];
}
