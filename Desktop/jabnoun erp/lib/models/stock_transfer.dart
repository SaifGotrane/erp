import 'package:equatable/equatable.dart';

class StockTransferLine extends Equatable {
  final String id;
  final String transferId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double quantity;

  const StockTransferLine({
    required this.id,
    required this.transferId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.quantity,
  });

  factory StockTransferLine.fromMap(Map<String, dynamic> map) => StockTransferLine(
        id: map['id'] as String,
        transferId: map['transfer_id'] as String,
        articleId: map['article_id'] as String,
        articleReference: (map['article'] as Map<String, dynamic>?)?['reference'] as String? ?? '',
        articleDesignation: (map['article'] as Map<String, dynamic>?)?['designation'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsertMap() => {
        'transfer_id': transferId,
        'article_id': articleId,
        'quantity': quantity,
      };

  @override
  List<Object?> get props => [id, transferId, articleId, quantity];
}

class StockTransfer extends Equatable {
  final String id;
  final String documentNumber;
  final String? sourceDepotId;
  final String? sourceShowroomId;
  final String sourceLabel;
  final String? destinationDepotId;
  final String? destinationShowroomId;
  final String destinationLabel;
  final DateTime transferDate;
  final String status;
  final String? vehicleId;
  final String? driverId;
  final String? notes;
  final List<StockTransferLine> lines;

  const StockTransfer({
    required this.id,
    required this.documentNumber,
    this.sourceDepotId,
    this.sourceShowroomId,
    this.sourceLabel = '',
    this.destinationDepotId,
    this.destinationShowroomId,
    this.destinationLabel = '',
    required this.transferDate,
    required this.status,
    this.vehicleId,
    this.driverId,
    this.notes,
    this.lines = const [],
  });

  factory StockTransfer.fromMap(Map<String, dynamic> map) => StockTransfer(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        sourceDepotId: map['source_depot_id'] as String?,
        sourceShowroomId: map['source_showroom_id'] as String?,
        sourceLabel: (map['source_depot'] as Map<String, dynamic>?)?['name'] as String? ??
            (map['source_showroom'] as Map<String, dynamic>?)?['name'] as String? ??
            '',
        destinationDepotId: map['destination_depot_id'] as String?,
        destinationShowroomId: map['destination_showroom_id'] as String?,
        destinationLabel: (map['destination_depot'] as Map<String, dynamic>?)?['name'] as String? ??
            (map['destination_showroom'] as Map<String, dynamic>?)?['name'] as String? ??
            '',
        transferDate: DateTime.parse(map['transfer_date'] as String),
        status: map['status'] as String,
        vehicleId: map['vehicle_id'] as String?,
        driverId: map['driver_id'] as String?,
        notes: map['notes'] as String?,
        lines: (map['stock_transfer_lines'] as List?)
                ?.map((e) => StockTransferLine.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props => [id, documentNumber, status];
}
