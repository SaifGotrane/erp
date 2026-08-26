import 'package:equatable/equatable.dart';

class InventoryLine extends Equatable {
  final String id;
  final String inventoryId;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final double theoreticalQuantity;
  final double realQuantity;
  final double gap;

  const InventoryLine({
    required this.id,
    required this.inventoryId,
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    required this.theoreticalQuantity,
    required this.realQuantity,
    required this.gap,
  });

  factory InventoryLine.fromMap(Map<String, dynamic> map) => InventoryLine(
        id: map['id'] as String,
        inventoryId: map['inventory_id'] as String,
        articleId: map['article_id'] as String,
        articleReference: (map['article'] as Map<String, dynamic>?)?['reference'] as String? ?? '',
        articleDesignation: (map['article'] as Map<String, dynamic>?)?['designation'] as String? ?? '',
        theoreticalQuantity: (map['theoretical_quantity'] as num?)?.toDouble() ?? 0,
        realQuantity: (map['real_quantity'] as num?)?.toDouble() ?? 0,
        gap: (map['gap'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsertMap() => {
        'inventory_id': inventoryId,
        'article_id': articleId,
        'theoretical_quantity': theoreticalQuantity,
        'real_quantity': realQuantity,
        'gap': gap,
      };

  @override
  List<Object?> get props => [id, inventoryId, articleId, realQuantity];
}

class Inventory extends Equatable {
  final String id;
  final String documentNumber;
  final String? depotId;
  final String? showroomId;
  final String locationLabel;
  final DateTime inventoryDate;
  final String status;
  final String? notes;
  final List<InventoryLine> lines;

  const Inventory({
    required this.id,
    required this.documentNumber,
    this.depotId,
    this.showroomId,
    this.locationLabel = '',
    required this.inventoryDate,
    required this.status,
    this.notes,
    this.lines = const [],
  });

  factory Inventory.fromMap(Map<String, dynamic> map) => Inventory(
        id: map['id'] as String,
        documentNumber: map['document_number'] as String,
        depotId: map['depot_id'] as String?,
        showroomId: map['showroom_id'] as String?,
        locationLabel: (map['depot'] as Map<String, dynamic>?)?['name'] as String? ??
            (map['showroom'] as Map<String, dynamic>?)?['name'] as String? ??
            '',
        inventoryDate: DateTime.parse(map['inventory_date'] as String),
        status: map['status'] as String,
        notes: map['notes'] as String?,
        lines: (map['inventory_lines'] as List?)
                ?.map((e) => InventoryLine.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props => [id, documentNumber, status];
}
