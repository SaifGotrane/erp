import 'package:equatable/equatable.dart';

const List<String> savStatuses = ['ouvert', 'en_cours', 'en_attente_fournisseur', 'resolu', 'termine'];
const List<String> savResolutionTypes = ['remplacement', 'reparation', 'autre'];

String savStatusLabel(String status) {
  switch (status) {
    case 'ouvert':
      return 'Ouvert';
    case 'en_cours':
      return 'En cours';
    case 'en_attente_fournisseur':
      return 'En attente fournisseur';
    case 'resolu':
      return 'Résolu';
    case 'termine':
      return 'Terminé';
    default:
      return status;
  }
}

String savResolutionLabel(String type) {
  switch (type) {
    case 'remplacement':
      return 'Remplacement';
    case 'reparation':
      return 'Réparation';
    case 'autre':
      return 'Autre';
    default:
      return type;
  }
}

class SavTicketNote extends Equatable {
  final String id;
  final String ticketId;
  final String note;
  final String? authorName;
  final DateTime createdAt;

  const SavTicketNote({
    required this.id,
    required this.ticketId,
    required this.note,
    this.authorName,
    required this.createdAt,
  });

  factory SavTicketNote.fromMap(Map<String, dynamic> map) => SavTicketNote(
        id: map['id'] as String,
        ticketId: map['ticket_id'] as String,
        note: map['note'] as String,
        authorName: (map['author'] as Map<String, dynamic>?)?['full_name'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, ticketId, note, createdAt];
}

class SavTicket extends Equatable {
  final String id;
  final String ticketNumber;
  final String customerId;
  final String customerName;
  final String articleId;
  final String articleReference;
  final String articleDesignation;
  final String? supplierId;
  final String? supplierName;
  final String issueDescription;
  final DateTime reclamationDate;
  final String status;
  final String? resolutionType;
  final String? resolutionNotes;
  final DateTime? resolutionDate;
  final DateTime createdAt;

  const SavTicket({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    this.customerName = '',
    required this.articleId,
    this.articleReference = '',
    this.articleDesignation = '',
    this.supplierId,
    this.supplierName,
    required this.issueDescription,
    required this.reclamationDate,
    required this.status,
    this.resolutionType,
    this.resolutionNotes,
    this.resolutionDate,
    required this.createdAt,
  });

  factory SavTicket.fromMap(Map<String, dynamic> map) => SavTicket(
        id: map['id'] as String,
        ticketNumber: map['ticket_number'] as String,
        customerId: map['customer_id'] as String,
        customerName: (map['customer'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        articleId: map['article_id'] as String,
        articleReference: (map['article'] as Map<String, dynamic>?)?['reference'] as String? ?? '',
        articleDesignation: (map['article'] as Map<String, dynamic>?)?['designation'] as String? ?? '',
        supplierId: map['supplier_id'] as String?,
        supplierName: (map['supplier'] as Map<String, dynamic>?)?['name'] as String?,
        issueDescription: map['issue_description'] as String,
        reclamationDate: DateTime.parse(map['reclamation_date'] as String),
        status: map['status'] as String,
        resolutionType: map['resolution_type'] as String?,
        resolutionNotes: map['resolution_notes'] as String?,
        resolutionDate: map['resolution_date'] != null ? DateTime.parse(map['resolution_date'] as String) : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, ticketNumber, status, resolutionType];
}
