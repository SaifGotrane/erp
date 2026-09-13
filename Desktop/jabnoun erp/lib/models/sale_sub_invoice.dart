import 'package:equatable/equatable.dart';

/// Noms tunisiens réalistes utilisés pour générer automatiquement des
/// sous-clients lors du fractionnement d'une facture (voir §2.3).
const List<String> tunisianSampleNames = [
  'Mohamed Ben Fraj', 'Ahmed Ghali', 'Mohamed Trabelsi', 'Ahmed Ben Salah',
  'Sami Jebali', 'Karim Chaabane', 'Walid Hammami', 'Nizar Bouazizi',
  'Anis Gharbi', 'Hatem Sassi', 'Riadh Mejri', 'Youssef Karray',
  'Bilel Rekik', 'Fares Ouali', 'Chokri Ayari', 'Imed Zouari',
];

class SaleSubInvoice extends Equatable {
  final String id;
  final String saleId;
  final String documentNumber;
  final String subClientName;
  final String? customerId;
  final String? customerName;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  const SaleSubInvoice({
    required this.id,
    required this.saleId,
    required this.documentNumber,
    required this.subClientName,
    this.customerId,
    this.customerName,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  factory SaleSubInvoice.fromMap(Map<String, dynamic> map) => SaleSubInvoice(
        id: map['id'] as String,
        saleId: map['sale_id'] as String,
        documentNumber: map['document_number'] as String,
        subClientName: map['sub_client_name'] as String,
        customerId: map['customer_id'] as String?,
        customerName: (map['customer'] as Map<String, dynamic>?)?['name'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, saleId, documentNumber, subClientName, customerId, amount, notes];
}
