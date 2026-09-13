import 'package:equatable/equatable.dart';

class SupplierReturnLine extends Equatable {
  final String id;
  final String returnId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double quantity;
  final double unitPriceHt;
  final double taxRatePercent;
  final double lineTotalHt;
  final double lineTotalTva;
  final double lineTotalTtc;

  const SupplierReturnLine({
    required this.id,
    required this.returnId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    required this.lineTotalHt,
    required this.lineTotalTva,
    required this.lineTotalTtc,
  });

  factory SupplierReturnLine.fromMap(
    Map<String, dynamic> map,
  ) => SupplierReturnLine(
    id: map['id'] as String,
    returnId: map['supplier_return_id'] as String,
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
    lineTotalHt: (map['line_total_ht'] as num?)?.toDouble() ?? 0,
    lineTotalTva: (map['line_total_tva'] as num?)?.toDouble() ?? 0,
    lineTotalTtc: (map['line_total_ttc'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    returnId,
    articleId,
    articleReference,
    articleDesignation,
    quantity,
    unitPriceHt,
    taxRatePercent,
    lineTotalHt,
    lineTotalTva,
    lineTotalTtc,
  ];
}

class SupplierReturn extends Equatable {
  final String id;
  final String documentNumber;
  final String supplierId;
  final String supplierName;
  final String? purchaseId;
  final String depotId;
  final String depotName;
  final DateTime returnDate;
  final String status;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final String? notes;
  final List<SupplierReturnLine> lines;

  const SupplierReturn({
    required this.id,
    required this.documentNumber,
    required this.supplierId,
    this.supplierName = '',
    this.purchaseId,
    required this.depotId,
    this.depotName = '',
    required this.returnDate,
    required this.status,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.notes,
    this.lines = const [],
  });

  factory SupplierReturn.fromMap(Map<String, dynamic> map) => SupplierReturn(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    supplierId: map['supplier_id'] as String,
    supplierName:
        (map['supplier'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    purchaseId: map['purchase_id'] as String?,
    depotId: map['depot_id'] as String,
    depotName:
        (map['depot'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    returnDate: DateTime.parse(map['return_date'] as String),
    status: map['status'] as String,
    totalHt: (map['total_ht'] as num?)?.toDouble() ?? 0,
    totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
    totalTtc: (map['total_ttc'] as num?)?.toDouble() ?? 0,
    notes: map['notes'] as String?,
    lines:
        (map['supplier_return_lines'] as List?)
            ?.map((e) => SupplierReturnLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    supplierId,
    supplierName,
    purchaseId,
    depotId,
    depotName,
    returnDate,
    status,
    totalHt,
    totalTva,
    totalTtc,
    notes,
    lines,
  ];
}

class CustomerReturnLine extends Equatable {
  final String id;
  final String returnId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double quantity;
  final double unitPriceHt;
  final double taxRatePercent;
  final double lineTotalHt;
  final double lineTotalTva;
  final double lineTotalTtc;

  const CustomerReturnLine({
    required this.id,
    required this.returnId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
    required this.unitPriceHt,
    required this.taxRatePercent,
    required this.lineTotalHt,
    required this.lineTotalTva,
    required this.lineTotalTtc,
  });

  factory CustomerReturnLine.fromMap(
    Map<String, dynamic> map,
  ) => CustomerReturnLine(
    id: map['id'] as String,
    returnId: map['customer_return_id'] as String,
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
    lineTotalHt: (map['line_total_ht'] as num?)?.toDouble() ?? 0,
    lineTotalTva: (map['line_total_tva'] as num?)?.toDouble() ?? 0,
    lineTotalTtc: (map['line_total_ttc'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    returnId,
    articleId,
    articleReference,
    articleDesignation,
    quantity,
    unitPriceHt,
    taxRatePercent,
    lineTotalHt,
    lineTotalTva,
    lineTotalTtc,
  ];
}

class CustomerReturn extends Equatable {
  final String id;
  final String documentNumber;
  final String customerId;
  final String customerName;
  final String? saleId;
  final String? depotId;
  final String? showroomId;
  final String locationLabel;
  final DateTime returnDate;
  final String status;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final String? notes;
  final List<CustomerReturnLine> lines;

  const CustomerReturn({
    required this.id,
    required this.documentNumber,
    required this.customerId,
    this.customerName = '',
    this.saleId,
    this.depotId,
    this.showroomId,
    this.locationLabel = '',
    required this.returnDate,
    required this.status,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.notes,
    this.lines = const [],
  });

  factory CustomerReturn.fromMap(Map<String, dynamic> map) => CustomerReturn(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    customerId: map['customer_id'] as String,
    customerName:
        (map['customer'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    saleId: map['sale_id'] as String?,
    depotId: map['depot_id'] as String?,
    showroomId: map['showroom_id'] as String?,
    locationLabel:
        (map['depot'] as Map<String, dynamic>?)?['name'] as String? ??
        (map['showroom'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    returnDate: DateTime.parse(map['return_date'] as String),
    status: map['status'] as String,
    totalHt: (map['total_ht'] as num?)?.toDouble() ?? 0,
    totalTva: (map['total_tva'] as num?)?.toDouble() ?? 0,
    totalTtc: (map['total_ttc'] as num?)?.toDouble() ?? 0,
    notes: map['notes'] as String?,
    lines:
        (map['customer_return_lines'] as List?)
            ?.map((e) => CustomerReturnLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    customerId,
    customerName,
    saleId,
    depotId,
    showroomId,
    locationLabel,
    returnDate,
    status,
    totalHt,
    totalTva,
    totalTtc,
    notes,
    lines,
  ];
}
