import 'package:equatable/equatable.dart';

class SubClient extends Equatable {
  final String id;
  final String name;
  final String cin;
  final String? phone;
  final String? address;
  final bool active;
  final DateTime createdAt;

  const SubClient({
    required this.id,
    required this.name,
    required this.cin,
    this.phone,
    this.address,
    this.active = true,
    required this.createdAt,
  });

  factory SubClient.fromMap(Map<String, dynamic> map) => SubClient(
        id: map['id'] as String,
        name: map['name'] as String,
        cin: map['cin'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        active: map['active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, name, cin, phone, address, active, createdAt];
}
