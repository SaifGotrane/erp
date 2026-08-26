import 'package:equatable/equatable.dart';

class AuditLog extends Equatable {
  final String id;
  final DateTime createdAt;
  final String? userId;
  final String? userFullName;
  final String action;
  final String module;
  final String? objectType;
  final String? objectId;
  final String? objectLabel;
  final String? details;

  const AuditLog({
    required this.id,
    required this.createdAt,
    this.userId,
    this.userFullName,
    required this.action,
    required this.module,
    this.objectType,
    this.objectId,
    this.objectLabel,
    this.details,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        userId: map['user_id'] as String?,
        userFullName: (map['user'] as Map<String, dynamic>?)?['full_name'] as String?,
        action: map['action'] as String,
        module: map['module'] as String,
        objectType: map['object_type'] as String?,
        objectId: map['object_id'] as String?,
        objectLabel: map['object_label'] as String?,
        details: map['details'] as String?,
      );

  @override
  List<Object?> get props => [id, createdAt, action, module];
}

class PaymentMethod extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final int sortOrder;

  const PaymentMethod({
    required this.id,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic> map) => PaymentMethod(
        id: map['id'] as String,
        name: map['name'] as String,
        isActive: map['is_active'] as bool? ?? true,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, name];
}

class CompanySettings extends Equatable {
  final String id;
  final String companyName;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxId;
  final String currency;
  final bool allowNegativeStock;

  const CompanySettings({
    required this.id,
    required this.companyName,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.taxId,
    this.currency = 'TND',
    this.allowNegativeStock = false,
  });

  factory CompanySettings.fromMap(Map<String, dynamic> map) => CompanySettings(
        id: map['id'] as String,
        companyName: map['company_name'] as String,
        logoUrl: map['logo_url'] as String?,
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        taxId: map['tax_id'] as String?,
        currency: map['currency'] as String? ?? 'TND',
        allowNegativeStock: map['allow_negative_stock'] as bool? ?? false,
      );

  Map<String, dynamic> toUpdateMap() => {
        'company_name': companyName,
        'logo_url': logoUrl,
        'address': address?.isEmpty == true ? null : address,
        'phone': phone?.isEmpty == true ? null : phone,
        'email': email?.isEmpty == true ? null : email,
        'tax_id': taxId?.isEmpty == true ? null : taxId,
        'currency': currency,
        'allow_negative_stock': allowNegativeStock,
        'updated_at': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, companyName, currency];
}
