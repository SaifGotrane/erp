import 'package:equatable/equatable.dart';

class SaleSubInvoiceLine extends Equatable {
  final String id;
  final String subInvoiceId;
  final String saleLineId;
  final String articleId;
  final int quantity;
  final double unitPriceHt;
  final double taxRatePercent;
  final double lineTotalHt;
  final double lineTotalTva;
  final double lineTotalTtc;
  final String? articleReference;
  final String? articleDesignation;

  const SaleSubInvoiceLine({
    required this.id,
    required this.subInvoiceId,
    required this.saleLineId,
    required this.articleId,
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    required this.lineTotalHt,
    required this.lineTotalTva,
    required this.lineTotalTtc,
    this.articleReference,
    this.articleDesignation,
  });

  factory SaleSubInvoiceLine.fromMap(Map<String, dynamic> map) =>
      SaleSubInvoiceLine(
        id: map['id'] as String,
        subInvoiceId: map['sub_invoice_id'] as String,
        saleLineId: map['sale_line_id'] as String,
        articleId: map['article_id'] as String,
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        unitPriceHt: (map['unit_price_ht'] as num?)?.toDouble() ?? 0,
        taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
        lineTotalHt: (map['line_total_ht'] as num?)?.toDouble() ?? 0,
        lineTotalTva: (map['line_total_tva'] as num?)?.toDouble() ?? 0,
        lineTotalTtc: (map['line_total_ttc'] as num?)?.toDouble() ?? 0,
        articleReference:
            (map['article'] as Map<String, dynamic>?)?['reference'] as String?,
        articleDesignation:
            (map['article'] as Map<String, dynamic>?)?['designation'] as String?,
      );

  @override
  List<Object?> get props => [id, subInvoiceId, saleLineId, articleId, quantity];
}

class SaleSubInvoice extends Equatable {
  final String id;
  final String saleId;
  final String documentNumber;
  final String subClientName;
  final String? subClientId;
  final String? customerId;
  final String? customerName;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final List<SaleSubInvoiceLine> lines;

  const SaleSubInvoice({
    required this.id,
    required this.saleId,
    required this.documentNumber,
    required this.subClientName,
    this.subClientId,
    this.customerId,
    this.customerName,
    required this.amount,
    this.notes,
    required this.createdAt,
    this.lines = const [],
  });

  factory SaleSubInvoice.fromMap(Map<String, dynamic> map) => SaleSubInvoice(
        id: map['id'] as String,
        saleId: map['sale_id'] as String,
        documentNumber: map['document_number'] as String,
        subClientName: map['sub_client_name'] as String,
        subClientId: map['sub_client_id'] as String?,
        customerId: map['customer_id'] as String?,
        customerName:
            (map['customer'] as Map<String, dynamic>?)?['name'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        lines: (map['sale_sub_invoice_lines'] as List?)
                ?.map((e) =>
                    SaleSubInvoiceLine.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props => [
        id,
        saleId,
        documentNumber,
        subClientName,
        subClientId,
        customerId,
        amount,
        notes,
        lines,
      ];
}
