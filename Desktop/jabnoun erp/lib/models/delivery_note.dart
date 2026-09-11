import 'package:equatable/equatable.dart';

class DeliveryNoteLine extends Equatable {
  final String id;
  final String deliveryNoteId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double quantity;

  const DeliveryNoteLine({
    required this.id,
    required this.deliveryNoteId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
  });

  factory DeliveryNoteLine.fromMap(
    Map<String, dynamic> map,
  ) => DeliveryNoteLine(
    id: map['id'] as String,
    deliveryNoteId: map['delivery_note_id'] as String,
    articleId: map['article_id'] as String,
    articleReference:
        (map['article'] as Map<String, dynamic>?)?['reference'] as String? ??
        '',
    articleDesignation:
        (map['article'] as Map<String, dynamic>?)?['designation'] as String? ??
        '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    deliveryNoteId,
    articleId,
    articleReference,
    articleDesignation,
    quantity,
  ];
}

class DeliveryNote extends Equatable {
  final String id;
  final String documentNumber;
  final String customerId;
  final String customerName;
  final String? saleId;
  final String? depotId;
  final String? showroomId;
  final String locationLabel;
  final DateTime deliveryDate;
  final String status;
  final String? vehicleId;
  final String? driverId;
  final String? notes;
  final List<DeliveryNoteLine> lines;

  const DeliveryNote({
    required this.id,
    required this.documentNumber,
    required this.customerId,
    this.customerName = '',
    this.saleId,
    this.depotId,
    this.showroomId,
    this.locationLabel = '',
    required this.deliveryDate,
    required this.status,
    this.vehicleId,
    this.driverId,
    this.notes,
    this.lines = const [],
  });

  factory DeliveryNote.fromMap(Map<String, dynamic> map) => DeliveryNote(
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
    deliveryDate: DateTime.parse(map['delivery_date'] as String),
    status: map['status'] as String,
    vehicleId: map['vehicle_id'] as String?,
    driverId: map['driver_id'] as String?,
    notes: map['notes'] as String?,
    lines:
        (map['delivery_note_lines'] as List?)
            ?.map((e) => DeliveryNoteLine.fromMap(e as Map<String, dynamic>))
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
    deliveryDate,
    status,
    vehicleId,
    driverId,
    notes,
    lines,
  ];
}
