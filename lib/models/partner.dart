import 'package:equatable/equatable.dart';

/// Les 24 gouvernorats tunisiens, utilisés comme liste contrôlée pour les
/// clients et fournisseurs (voir §8 du cahier des charges).
const List<String> tunisianGovernorates = [
  'Tunis', 'Ariana', 'Ben Arous', 'Manouba', 'Nabeul', 'Zaghouan',
  'Bizerte', 'Béja', 'Jendouba', 'Le Kef', 'Siliana', 'Kairouan',
  'Kasserine', 'Sidi Bouzid', 'Sousse', 'Monastir', 'Mahdia', 'Sfax',
  'Gabès', 'Medenine', 'Tataouine', 'Gafsa', 'Tozeur', 'Kebili',
];

/// Fournisseur ou Client (structure identique, tables séparées).
class Partner extends Equatable {
  final String id;
  final String code;
  final String name;
  final String? companyName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? governorate;
  final String? taxId; // Matricule fiscal
  final int paymentTermsDays;
  final bool active;
  final DateTime createdAt;

  const Partner({
    required this.id,
    required this.code,
    required this.name,
    this.companyName,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.governorate,
    this.taxId,
    this.paymentTermsDays = 0,
    required this.active,
    required this.createdAt,
  });

  factory Partner.fromMap(Map<String, dynamic> map) => Partner(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        companyName: map['company_name'] as String?,
        contactPerson: map['contact_person'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        governorate: map['governorate'] as String?,
        taxId: map['tax_id'] as String?,
        paymentTermsDays: map['payment_terms_days'] as int? ?? 0,
        active: map['active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'code': code,
        'name': name,
        'company_name': companyName?.isEmpty == true ? null : companyName,
        'contact_person': contactPerson?.isEmpty == true ? null : contactPerson,
        'phone': phone?.isEmpty == true ? null : phone,
        'email': email?.isEmpty == true ? null : email,
        'address': address?.isEmpty == true ? null : address,
        'governorate': governorate,
        'tax_id': taxId?.isEmpty == true ? null : taxId,
        'payment_terms_days': paymentTermsDays,
        'active': active,
      };

  @override
  List<Object?> get props => [id, code, name, companyName, phone, email, governorate, active];
}
