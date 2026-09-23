import 'package:equatable/equatable.dart';

class PurchaseLine extends Equatable {
  final String id;
  final String purchaseId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double quantity;
  final double unitPriceHt;
  final double taxRatePercent;
  final double discountPercent;
  final double lineTotalHt;
  final double lineTotalTva;
  final double lineTotalTtc;

  const PurchaseLine({
    required this.id,
    required this.purchaseId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    this.discountPercent = 0,
    required this.lineTotalHt,
    required this.lineTotalTva,
    required this.lineTotalTtc,
  });

  factory PurchaseLine.fromMap(Map<String, dynamic> map) => PurchaseLine(
        id: map['id'] as String,
        purchaseId: map['purchase_id'] as String,
        articleId: map['article_id'] as String,
        articleReference: (map['article'] as Map<String, dynamic>?)?['reference'] as String? ?? '',
        articleDesignation: (map['article'] as Map<String, dynamic>?)?['designation'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        unitPriceHt: (map['unit_price_ht'] as num?)?.toDouble() ?? 0,
        taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        lineTotalHt: (map['line_total_ht'] as num?)?.toDouble() ?? 0,
        lineTotalTva: (map['line_total_tva'] as num?)?.toDouble() ?? 0,
        lineTotalTtc: (map['line_total_ttc'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsertMap() => {
        'purchase_id': purchaseId,
        'article_id': articleId,
        'quantity': quantity,
        'unit_price_ht': unitPriceHt,
        'tax_rate_percent': taxRatePercent,
        'discount_percent': discountPercent,
        'line_total_ht': lineTotalHt,
        'line_total_tva': lineTotalTva,
        'line_total_ttc': lineTotalTtc,
      };

  @override
  List<Object?> get props => [id, purchaseId, articleId, quantity];
}

class Purchase extends Equatable {
  final String id;
  final String documentNumber;
  final String supplierId;
  final String supplierName;
  final String depotId;
  final String depotName;
  final DateTime purchaseDate;
  final String status;
  final String? paymentMethodId;
  final String? supplierDocumentRef;
  final double discountPercent;
  final double discountAmount;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final double amountPaid;
  final String? notes;
  final List<PurchaseLine> lines;

  const Purchase({
    required this.id,
    required this.documentNumber,
    required this.supplierId,
    this.supplierName = '',
    required this.depotId,
    this.depotName = '',
    required this.purchaseDate,
    required this.status,
    this.paymentMethodId,
    this.supplierDocumentRef,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.amountPaid = 0,
    this.notes,
    this.lines = const [],
  });

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        supplierId: map['supplier_id'] as String,
        supplierName: (map['supplier'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        depotId: map['depot_id'] as String,
        depotName: (map['depot'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        purchaseDate: DateTime.parse(map['purchase_date'] as String),
        status: map['status'] as String,
        paymentMethodId: map['payment_method_id'] as String?,
        supplierDocumentRef: map['supplier_document_ref'] as String?,
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
        discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
        totalHt: (map['total_ht'] as num?)?.toDouble() ?? 0,
        totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
        totalTtc: (map['total_ttc'] as num?)?.toDouble() ?? 0,
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        lines: (map['purchase_lines'] as List?)
            ?.map((e) => PurchaseLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
            [],
      );

  @override
  List<Object?> get props => [id, documentNumber, status];
}
