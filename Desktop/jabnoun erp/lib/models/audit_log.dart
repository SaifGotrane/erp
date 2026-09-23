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
  final String? bankName;
  final String? bankAgency;
  final String? ribCodeBanque;
  final String? ribCodeAgence;
  final String? ribCompte;
  final String? ribCle;
  final String? defaultBillPlace;
  final double cnssEmployeeRate;
  final double cssRate;
  final double professionalExpensesRate;
  final double professionalExpensesAnnualCap;
  final double headOfHouseholdAnnualDeduction;
  final double childAnnualDeduction;
  final int maxDeductibleChildren;

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
    this.bankName,
    this.bankAgency,
    this.ribCodeBanque,
    this.ribCodeAgence,
    this.ribCompte,
    this.ribCle,
    this.defaultBillPlace,
    this.cnssEmployeeRate = 0.0918,
    this.cssRate = 0.01,
    this.professionalExpensesRate = 0.10,
    this.professionalExpensesAnnualCap = 2000,
    this.headOfHouseholdAnnualDeduction = 300,
    this.childAnnualDeduction = 100,
    this.maxDeductibleChildren = 4,
  });

  /// Vrai si toutes les informations bancaires nécessaires à l'impression
  /// des lettres de change sont déjà connues (voir §1.8/§10).
  bool get hasCompleteBankInfo =>
      (bankName?.isNotEmpty ?? false) &&
      (bankAgency?.isNotEmpty ?? false) &&
      (ribCodeBanque?.isNotEmpty ?? false) &&
      (ribCodeAgence?.isNotEmpty ?? false) &&
      (ribCompte?.isNotEmpty ?? false) &&
      (ribCle?.isNotEmpty ?? false) &&
      (defaultBillPlace?.isNotEmpty ?? false);

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
        bankName: map['bank_name'] as String?,
        bankAgency: map['bank_agency'] as String?,
        ribCodeBanque: map['rib_code_banque'] as String?,
        ribCodeAgence: map['rib_code_agence'] as String?,
        ribCompte: map['rib_compte'] as String?,
        ribCle: map['rib_cle'] as String?,
        defaultBillPlace: map['default_bill_place'] as String?,
        cnssEmployeeRate: (map['cnss_employee_rate'] as num?)?.toDouble() ?? 0.0918,
        cssRate: (map['css_rate'] as num?)?.toDouble() ?? 0.01,
        professionalExpensesRate: (map['professional_expenses_rate'] as num?)?.toDouble() ?? 0.10,
        professionalExpensesAnnualCap: (map['professional_expenses_annual_cap'] as num?)?.toDouble() ?? 2000,
        headOfHouseholdAnnualDeduction: (map['head_of_household_annual_deduction'] as num?)?.toDouble() ?? 300,
        childAnnualDeduction: (map['child_annual_deduction'] as num?)?.toDouble() ?? 100,
        maxDeductibleChildren: (map['max_deductible_children'] as num?)?.toInt() ?? 4,
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
        'bank_name': bankName?.isEmpty == true ? null : bankName,
        'bank_agency': bankAgency?.isEmpty == true ? null : bankAgency,
        'rib_code_banque': ribCodeBanque?.isEmpty == true ? null : ribCodeBanque,
        'rib_code_agence': ribCodeAgence?.isEmpty == true ? null : ribCodeAgence,
        'rib_compte': ribCompte?.isEmpty == true ? null : ribCompte,
        'rib_cle': ribCle?.isEmpty == true ? null : ribCle,
        'default_bill_place': defaultBillPlace?.isEmpty == true ? null : defaultBillPlace,
        'cnss_employee_rate': cnssEmployeeRate,
        'css_rate': cssRate,
        'professional_expenses_rate': professionalExpensesRate,
        'professional_expenses_annual_cap': professionalExpensesAnnualCap,
        'head_of_household_annual_deduction': headOfHouseholdAnnualDeduction,
        'child_annual_deduction': childAnnualDeduction,
        'max_deductible_children': maxDeductibleChildren,
        'updated_at': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, companyName, currency];
}
