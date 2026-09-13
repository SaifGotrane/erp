import 'package:equatable/equatable.dart';

const List<String> billStatuses = ['non_payee', 'payee', 'annulee'];

String billStatusLabel(String status) {
  switch (status) {
    case 'non_payee':
      return 'Non payée';
    case 'payee':
      return 'Payée';
    case 'annulee':
      return 'Annulée';
    default:
      return status;
  }
}

class SupplierSettlement extends Equatable {
  final String id;
  final String settlementNumber;
  final String supplierId;
  final String supplierName;
  final String purchaseId;
  final String purchaseDocumentNumber;
  final double totalAmount;
  final int billsCount;
  final String? bankName;
  final String? bankAgency;
  final String? ribCodeBanque;
  final String? ribCodeAgence;
  final String? ribCompte;
  final String? ribCle;
  final String? billPlace;
  final String? avalInfo;
  final String? notes;
  final DateTime createdAt;

  const SupplierSettlement({
    required this.id,
    required this.settlementNumber,
    required this.supplierId,
    this.supplierName = '',
    required this.purchaseId,
    this.purchaseDocumentNumber = '',
    required this.totalAmount,
    required this.billsCount,
    this.bankName,
    this.bankAgency,
    this.ribCodeBanque,
    this.ribCodeAgence,
    this.ribCompte,
    this.ribCle,
    this.billPlace,
    this.avalInfo,
    this.notes,
    required this.createdAt,
  });

  factory SupplierSettlement.fromMap(Map<String, dynamic> map) => SupplierSettlement(
        id: map['id'] as String,
        settlementNumber: map['settlement_number'] as String,
        supplierId: map['supplier_id'] as String,
        supplierName: (map['supplier'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        purchaseId: map['purchase_id'] as String,
        purchaseDocumentNumber: (map['purchase'] as Map<String, dynamic>?)?['document_number'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
        billsCount: map['bills_count'] as int? ?? 0,
        bankName: map['bank_name'] as String?,
        bankAgency: map['bank_agency'] as String?,
        ribCodeBanque: map['rib_code_banque'] as String?,
        ribCodeAgence: map['rib_code_agence'] as String?,
        ribCompte: map['rib_compte'] as String?,
        ribCle: map['rib_cle'] as String?,
        billPlace: map['bill_place'] as String?,
        avalInfo: map['aval_info'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, settlementNumber, supplierId, purchaseId, totalAmount, billsCount];
}

class BillOfExchange extends Equatable {
  final String id;
  final String settlementId;
  final String billNumber;
  final int sequenceNo;
  final String supplierId;
  final String supplierName;
  final String? supplierAddress;
  final String purchaseId;
  final String purchaseDocumentNumber;
  final double amount;
  final DateTime creationDate;
  final DateTime dueDate;
  final String status;
  final DateTime? paymentDate;
  final String? notes;
  final String? bankName;
  final String? bankAgency;
  final String? ribCodeBanque;
  final String? ribCodeAgence;
  final String? ribCompte;
  final String? ribCle;
  final String? billPlace;
  final String? avalInfo;

  const BillOfExchange({
    required this.id,
    required this.settlementId,
    required this.billNumber,
    required this.sequenceNo,
    required this.supplierId,
    this.supplierName = '',
    this.supplierAddress,
    required this.purchaseId,
    this.purchaseDocumentNumber = '',
    required this.amount,
    required this.creationDate,
    required this.dueDate,
    required this.status,
    this.paymentDate,
    this.notes,
    this.bankName,
    this.bankAgency,
    this.ribCodeBanque,
    this.ribCodeAgence,
    this.ribCompte,
    this.ribCle,
    this.billPlace,
    this.avalInfo,
  });

  bool get isOverdue => status == 'non_payee' && dueDate.isBefore(DateTime.now());

  factory BillOfExchange.fromMap(Map<String, dynamic> map) {
    final settlement = map['settlement'] as Map<String, dynamic>?;
    return BillOfExchange(
      id: map['id'] as String,
      settlementId: map['settlement_id'] as String,
      billNumber: map['bill_number'] as String,
      sequenceNo: map['sequence_no'] as int? ?? 0,
      supplierId: map['supplier_id'] as String,
      // Nom/adresse figés à la création de la lettre (document négociable déjà
      // en circulation) ; on ne retombe sur la fiche fournisseur actuelle que
      // pour les lettres créées avant l'ajout de ce snapshot.
      supplierName: map['supplier_name_snapshot'] as String? ??
          (map['supplier'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      supplierAddress: map['supplier_address_snapshot'] as String? ??
          (map['supplier'] as Map<String, dynamic>?)?['address'] as String?,
      purchaseId: map['purchase_id'] as String,
      purchaseDocumentNumber: map['purchase_document_number_snapshot'] as String? ??
          (map['purchase'] as Map<String, dynamic>?)?['document_number'] as String? ??
          '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      creationDate: DateTime.parse(map['creation_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      status: map['status'] as String,
      paymentDate: map['payment_date'] != null ? DateTime.parse(map['payment_date'] as String) : null,
      notes: map['notes'] as String?,
      bankName: settlement?['bank_name'] as String?,
      bankAgency: settlement?['bank_agency'] as String?,
      ribCodeBanque: settlement?['rib_code_banque'] as String?,
      ribCodeAgence: settlement?['rib_code_agence'] as String?,
      ribCompte: settlement?['rib_compte'] as String?,
      ribCle: settlement?['rib_cle'] as String?,
      billPlace: settlement?['bill_place'] as String?,
      avalInfo: settlement?['aval_info'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, settlementId, billNumber, amount, dueDate, status];
}
