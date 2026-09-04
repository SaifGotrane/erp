import 'package:equatable/equatable.dart';

class SaleLine extends Equatable {
  final String id;
  final String saleId;
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

  const SaleLine({
    required this.id,
    required this.saleId,
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

  factory SaleLine.fromMap(Map<String, dynamic> map) => SaleLine(
    id: map['id'] as String,
    saleId: map['sale_id'] as String,
    articleId: map['article_id'] as String,
    articleReference:
        (map['article'] as Map<String, dynamic>?)?['reference'] as String? ??
        '',
    articleDesignation:
        (map['article'] as Map<String, dynamic>?)?['designation'] as String? ??
        '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    unitPriceHt: (map['unit_price_ht'] as num?)?.toDouble() ?? 0,
    taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
    discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
    lineTotalHt: (map['line_total_ht'] as num?)?.toDouble() ?? 0,
    lineTotalTva: (map['line_total_tva'] as num?)?.toDouble() ?? 0,
    lineTotalTtc: (map['line_total_ttc'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    saleId,
    articleId,
    articleReference,
    articleDesignation,
    quantity,
    unitPriceHt,
    taxRatePercent,
    discountPercent,
    lineTotalHt,
    lineTotalTva,
    lineTotalTtc,
  ];
}

class Sale extends Equatable {
  final String id;
  final String documentNumber;
  final String customerId;
  final String customerName;
  final String? depotId;
  final String? showroomId;
  final String locationLabel;
  final DateTime saleDate;
  final String status;
  final String? paymentMethodId;
  final double discountPercent;
  final double discountAmount;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final double amountPaid;
  final bool isPos;
  final String? notes;
  final double stampDutyAmount;
  final String? customerDisplayName;
  final List<SaleLine> lines;

  const Sale({
    required this.id,
    required this.documentNumber,
    required this.customerId,
    this.customerName = '',
    this.depotId,
    this.showroomId,
    this.locationLabel = '',
    required this.saleDate,
    required this.status,
    this.paymentMethodId,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.amountPaid = 0,
    this.isPos = false,
    this.notes,
    this.stampDutyAmount = 1,
    this.customerDisplayName,
    this.lines = const [],
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    customerId: map['customer_id'] as String,
    customerName:
        (map['customer'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    depotId: map['depot_id'] as String?,
    showroomId: map['showroom_id'] as String?,
    locationLabel:
        (map['depot'] as Map<String, dynamic>?)?['name'] as String? ??
        (map['showroom'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    saleDate: DateTime.parse(map['sale_date'] as String),
    status: map['status'] as String,
    paymentMethodId: map['payment_method_id'] as String?,
    discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
    discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
    totalHt: (map['total_ht'] as num?)?.toDouble() ?? 0,
    totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
    totalTtc: (map['total_ttc'] as num?)?.toDouble() ?? 0,
    amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
    isPos: map['is_pos'] as bool? ?? false,
    notes: map['notes'] as String?,
    stampDutyAmount: (map['stamp_duty_amount'] as num?)?.toDouble() ?? 1,
    customerDisplayName: map['customer_display_name'] as String?,
    lines:
        (map['sale_lines'] as List?)
            ?.map((e) => SaleLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    customerId,
    customerName,
    depotId,
    showroomId,
    locationLabel,
    saleDate,
    status,
    paymentMethodId,
    discountPercent,
    discountAmount,
    totalHt,
    totalTva,
    totalTtc,
    amountPaid,
    isPos,
    notes,
    stampDutyAmount,
    customerDisplayName,
    lines,
  ];
}
