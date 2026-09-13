import 'package:equatable/equatable.dart';

class PosSession extends Equatable {
  final String id;
  final String sessionNumber;
  final String? showroomId;
  final String showroomName;
  final String employeeId;
  final String employeeName;
  final DateTime openingDate;
  final DateTime? closingDate;
  final String status;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? cashDifference;
  final double totalSales;
  final double totalCashSales;
  final double totalCardSales;
  final String? notes;

  const PosSession({
    required this.id,
    required this.sessionNumber,
    this.showroomId,
    this.showroomName = '',
    required this.employeeId,
    this.employeeName = '',
    required this.openingDate,
    this.closingDate,
    required this.status,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.cashDifference,
    this.totalSales = 0,
    this.totalCashSales = 0,
    this.totalCardSales = 0,
    this.notes,
  });

  factory PosSession.fromMap(Map<String, dynamic> map) => PosSession(
    id: map['id'] as String,
    sessionNumber: map['session_number'] as String,
    showroomId: map['showroom_id'] as String?,
    showroomName:
        (map['showroom'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    employeeId: map['employee_id'] as String,
    employeeName:
        (map['employee'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    openingDate: DateTime.parse(map['opening_date'] as String),
    closingDate: map['closing_date'] != null
        ? DateTime.parse(map['closing_date'] as String)
        : null,
    status: map['status'] as String,
    openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0,
    closingCash: (map['closing_cash'] as num?)?.toDouble(),
    expectedCash: (map['expected_cash'] as num?)?.toDouble(),
    cashDifference: (map['cash_difference'] as num?)?.toDouble(),
    totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0,
    totalCashSales: (map['total_cash_sales'] as num?)?.toDouble() ?? 0,
    totalCardSales: (map['total_card_sales'] as num?)?.toDouble() ?? 0,
    notes: map['notes'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    sessionNumber,
    showroomId,
    showroomName,
    employeeId,
    employeeName,
    openingDate,
    closingDate,
    status,
    openingCash,
    closingCash,
    expectedCash,
    cashDifference,
    totalSales,
    totalCashSales,
    totalCardSales,
    notes,
  ];
}

class Payment extends Equatable {
  final String id;
  final String documentNumber;
  final String paymentType;
  final String partnerType;
  final String partnerId;
  final String partnerName;
  final String? saleId;
  final String? purchaseId;
  final String? posSessionId;
  final String? paymentMethodName;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final String status;

  const Payment({
    required this.id,
    required this.documentNumber,
    required this.paymentType,
    required this.partnerType,
    required this.partnerId,
    this.partnerName = '',
    this.saleId,
    this.purchaseId,
    this.posSessionId,
    this.paymentMethodName,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.status = 'actif',
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    paymentType: map['payment_type'] as String,
    partnerType: map['partner_type'] as String,
    partnerId: map['partner_id'] as String,
    partnerName:
        map['partner_name'] as String? ??
        (map['partner'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    saleId: map['sale_id'] as String?,
    purchaseId: map['purchase_id'] as String?,
    posSessionId: map['pos_session_id'] as String?,
    paymentMethodName:
        (map['payment_method'] as Map<String, dynamic>?)?['name'] as String?,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    paymentDate: DateTime.parse(map['payment_date'] as String),
    notes: map['notes'] as String?,
    status: map['status'] as String? ?? 'actif',
  );

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    paymentType,
    partnerType,
    partnerId,
    partnerName,
    saleId,
    purchaseId,
    posSessionId,
    paymentMethodName,
    amount,
    paymentDate,
    notes,
    status,
  ];
}

class Expense extends Equatable {
  final String id;
  final String documentNumber;
  final DateTime expenseDate;
  final String? category;
  final String label;
  final double amount;
  final String? paymentMethodName;
  final String? depotId;
  final String? showroomId;
  final String? notes;

  const Expense({
    required this.id,
    required this.documentNumber,
    required this.expenseDate,
    this.category,
    required this.label,
    required this.amount,
    this.paymentMethodName,
    this.depotId,
    this.showroomId,
    this.notes,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    expenseDate: DateTime.parse(map['expense_date'] as String),
    category: map['category'] as String?,
    label: map['label'] as String,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    paymentMethodName:
        (map['payment_method'] as Map<String, dynamic>?)?['name'] as String?,
    depotId: map['depot_id'] as String?,
    showroomId: map['showroom_id'] as String?,
    notes: map['notes'] as String?,
  );

  Map<String, dynamic> toInsertMap() => {
    'document_number': documentNumber,
    'expense_date': expenseDate.toIso8601String().split('T').first,
    'category': category?.isEmpty == true ? null : category,
    'label': label,
    'amount': amount,
    'payment_method_id': null,
    'depot_id': depotId,
    'showroom_id': showroomId,
    'notes': notes?.isEmpty == true ? null : notes,
  };

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    expenseDate,
    category,
    label,
    amount,
    paymentMethodName,
    depotId,
    showroomId,
    notes,
  ];
}

class StockAdjustmentLine extends Equatable {
  final String id;
  final String adjustmentId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double currentQuantity;
  final double newQuantity;
  final double delta;

  const StockAdjustmentLine({
    required this.id,
    required this.adjustmentId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.currentQuantity,
    required this.newQuantity,
    required this.delta,
  });

  factory StockAdjustmentLine.fromMap(
    Map<String, dynamic> map,
  ) => StockAdjustmentLine(
    id: map['id'] as String,
    adjustmentId: map['adjustment_id'] as String,
    articleId: map['article_id'] as String,
    articleReference:
        (map['article'] as Map<String, dynamic>?)?['reference'] as String? ??
        '',
    articleDesignation:
        (map['article'] as Map<String, dynamic>?)?['designation'] as String? ??
        '',
    currentQuantity: (map['current_quantity'] as num?)?.toDouble() ?? 0,
    newQuantity: (map['new_quantity'] as num?)?.toDouble() ?? 0,
    delta: (map['delta'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    adjustmentId,
    articleId,
    articleReference,
    articleDesignation,
    currentQuantity,
    newQuantity,
    delta,
  ];
}

class StockAdjustment extends Equatable {
  final String id;
  final String documentNumber;
  final String? depotId;
  final String? showroomId;
  final String locationLabel;
  final DateTime adjustmentDate;
  final String status;
  final String reason;
  final String? notes;
  final List<StockAdjustmentLine> lines;

  const StockAdjustment({
    required this.id,
    required this.documentNumber,
    this.depotId,
    this.showroomId,
    this.locationLabel = '',
    required this.adjustmentDate,
    required this.status,
    required this.reason,
    this.notes,
    this.lines = const [],
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) => StockAdjustment(
    id: map['id'] as String,
    documentNumber: map['document_number'] as String,
    depotId: map['depot_id'] as String?,
    showroomId: map['showroom_id'] as String?,
    locationLabel:
        (map['depot'] as Map<String, dynamic>?)?['name'] as String? ??
        (map['showroom'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    adjustmentDate: DateTime.parse(map['adjustment_date'] as String),
    status: map['status'] as String,
    reason: map['reason'] as String,
    notes: map['notes'] as String?,
    lines:
        (map['stock_adjustment_lines'] as List?)
            ?.map((e) => StockAdjustmentLine.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  @override
  List<Object?> get props => [
    id,
    documentNumber,
    depotId,
    showroomId,
    locationLabel,
    adjustmentDate,
    status,
    reason,
    notes,
    lines,
  ];
}
