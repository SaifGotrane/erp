import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  final String id;
  final String registrationNumber;
  final String? vehicleType;
  final String? brand;
  final String? model;
  final double? capacity;
  final String? driverId;
  final bool active;
  final String? notes;
  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.registrationNumber,
    this.vehicleType,
    this.brand,
    this.model,
    this.capacity,
    this.driverId,
    required this.active,
    this.notes,
    required this.createdAt,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as String,
        registrationNumber: map['registration_number'] as String,
        vehicleType: map['vehicle_type'] as String?,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
        capacity: (map['capacity'] as num?)?.toDouble(),
        driverId: map['driver_id'] as String?,
        active: map['active'] as bool? ?? true,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'registration_number': registrationNumber,
        'vehicle_type': vehicleType?.isEmpty == true ? null : vehicleType,
        'brand': brand?.isEmpty == true ? null : brand,
        'model': model?.isEmpty == true ? null : model,
        'capacity': capacity,
        'driver_id': driverId,
        'active': active,
        'notes': notes?.isEmpty == true ? null : notes,
      };

  @override
  List<Object?> get props => [id, registrationNumber, brand, model, active];
}

class Driver extends Equatable {
  final String id;
  final String fullName;
  final String? phone;
  final String? licenseNumber;
  final bool active;
  final String? notes;
  final DateTime createdAt;

  const Driver({
    required this.id,
    required this.fullName,
    this.phone,
    this.licenseNumber,
    required this.active,
    this.notes,
    required this.createdAt,
  });

  factory Driver.fromMap(Map<String, dynamic> map) => Driver(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String?,
        licenseNumber: map['license_number'] as String?,
        active: map['active'] as bool? ?? true,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'full_name': fullName,
        'phone': phone?.isEmpty == true ? null : phone,
        'license_number': licenseNumber?.isEmpty == true ? null : licenseNumber,
        'active': active,
        'notes': notes?.isEmpty == true ? null : notes,
      };

  @override
  List<Object?> get props => [id, fullName, phone, active];
}
