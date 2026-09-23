import 'package:pdf/pdf.dart';

/// Alignement horizontal d'un champ imprimé.
enum FieldAlign { left, center, right }

/// Décrit un seul champ variable à imprimer sur le formulaire pré-imprimé
/// de la Lettre de Change / Bill of Exchange tunisienne (voir §1.13-1.14
/// du cahier des charges).
///
/// Toutes les coordonnées sont exprimées en millimètres depuis le coin
/// SUPÉRIEUR GAUCHE de la feuille (plus intuitif pour le calibrage que le
/// repère PDF natif, qui part du coin inférieur gauche — la conversion est
/// faite automatiquement par [BillOfExchangePdfTemplate.buildOverlay]).
class BillField {
  final String name;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double fontSize;
  final FieldAlign align;
  final bool bold;

  const BillField({
    required this.name,
    required this.xMm,
    required this.yMm,
    this.widthMm = 60,
    this.fontSize = 9,
    this.align = FieldAlign.left,
    this.bold = false,
  });
}

/// Configuration centralisée des coordonnées d'impression pour le
/// formulaire pré-imprimé de Lettre de Change tunisienne.
///
/// IMPORTANT : ces coordonnées sont des valeurs par défaut approximatives
/// basées sur la disposition visuelle du formulaire fourni en référence.
/// Elles sont volontairement regroupées ici (et non éparpillées dans le
/// code) pour pouvoir être ajustées facilement si l'alignement d'impression
/// doit être recalibré sur une imprimante réelle.
class BillOfExchangePdfTemplate {
  BillOfExchangePdfTemplate._();

  /// Format physique standard de la Lettre de Change tunisienne
  /// (176 x 115 mm).
  static const double pageWidthMm = 176;
  static const double pageHeightMm = 115;

  static PdfPageFormat get pageFormat => PdfPageFormat(
        pageWidthMm * PdfPageFormat.mm,
        pageHeightMm * PdfPageFormat.mm,
        marginAll: 0,
      );

  /// Champs alimentés automatiquement par l'ERP (voir §1.8-A) : ne
  /// nécessitent jamais de saisie manuelle.
  static const Map<String, BillField> autoFields = {
    // Top section: N° ordre de paiement (top-right)
    'ordre_paiement_no': BillField(name: 'ordre_paiement_no', xMm: 130, yMm: 8, widthMm: 42, align: FieldAlign.left, fontSize: 7),
    // Échéance (top-center-left)
    'echeance': BillField(name: 'echeance', xMm: 38, yMm: 14, widthMm: 30, fontSize: 8, bold: true),
    // Date de création ("Le" field, top-center)
    'date_creation_header': BillField(name: 'date_creation_header', xMm: 82, yMm: 14, widthMm: 30, fontSize: 8),
    // Montant chiffres 1 (top-right)
    'montant_chiffres_1': BillField(name: 'montant_chiffres_1', xMm: 138, yMm: 18, widthMm: 35, fontSize: 9, bold: true, align: FieldAlign.right),
    // RIB du tiré (row 2)
    'rib_code_banque': BillField(name: 'rib_code_banque', xMm: 8, yMm: 26, widthMm: 10, fontSize: 8, align: FieldAlign.center),
    'rib_code_agence': BillField(name: 'rib_code_agence', xMm: 20, yMm: 26, widthMm: 12, fontSize: 8, align: FieldAlign.center),
    'rib_compte': BillField(name: 'rib_compte', xMm: 34, yMm: 26, widthMm: 38, fontSize: 8, align: FieldAlign.center),
    'rib_cle': BillField(name: 'rib_cle', xMm: 74, yMm: 26, widthMm: 8, fontSize: 8, align: FieldAlign.center),
    // Montant chiffres 2 (row 2 right)
    'montant_chiffres_2': BillField(name: 'montant_chiffres_2', xMm: 138, yMm: 36, widthMm: 35, fontSize: 9, bold: true, align: FieldAlign.right),
    // Bénéficiaire / payez à l'ordre de (row 3)
    'nom_beneficiaire': BillField(name: 'nom_beneficiaire', xMm: 48, yMm: 35, widthMm: 80, fontSize: 7),
    // Tireur (Société A) - row 4 left
    'nom_tireur': BillField(name: 'nom_tireur', xMm: 4, yMm: 43, widthMm: 70, fontSize: 8, bold: true),
    // Montant en lettres
    'montant_lettres': BillField(name: 'montant_lettres', xMm: 4, yMm: 53, widthMm: 120, fontSize: 8),
    // Bottom section: Lieu de création
    'lieu_creation': BillField(name: 'lieu_creation', xMm: 4, yMm: 65, widthMm: 30, fontSize: 7),
    // Date de création (bottom)
    'date_creation': BillField(name: 'date_creation', xMm: 38, yMm: 65, widthMm: 26, fontSize: 7),
    // Échéance 2 (bottom)
    'echeance_2': BillField(name: 'echeance_2', xMm: 68, yMm: 65, widthMm: 26, fontSize: 7),
    // Lieu de paiement
    'lieu_paiement': BillField(name: 'lieu_paiement', xMm: 82, yMm: 14, widthMm: 20, fontSize: 7),
    // RIB du tiré (bottom section)
    'rib_code_banque_2': BillField(name: 'rib_code_banque_2', xMm: 8, yMm: 80, widthMm: 10, fontSize: 8, align: FieldAlign.center),
    'rib_code_agence_2': BillField(name: 'rib_code_agence_2', xMm: 20, yMm: 80, widthMm: 12, fontSize: 8, align: FieldAlign.center),
    'rib_compte_2': BillField(name: 'rib_compte_2', xMm: 34, yMm: 80, widthMm: 38, fontSize: 8, align: FieldAlign.center),
    'rib_cle_2': BillField(name: 'rib_cle_2', xMm: 74, yMm: 80, widthMm: 8, fontSize: 8, align: FieldAlign.center),
    // Nom et adresse du Tiré (bottom-right)
    'nom_adresse_tire': BillField(name: 'nom_adresse_tire', xMm: 95, yMm: 78, widthMm: 48, fontSize: 7),
    // Domiciliation (bottom far-right)
    'domiciliation': BillField(name: 'domiciliation', xMm: 138, yMm: 78, widthMm: 35, fontSize: 7),
    // Aval info
    'aval_info': BillField(name: 'aval_info', xMm: 45, yMm: 98, widthMm: 35, fontSize: 7),
  };

  /// Champs qui doivent rester manuels/physiques et ne sont JAMAIS
  /// imprimés automatiquement (§1.14) : signature, cachet, acceptation,
  /// aval, sauf si un mécanisme numérique légitime existe déjà — ce qui
  /// n'est pas le cas ici.
  static const List<String> manualOnlyFields = [
    'signature_tire',
    'cachet_tireur',
    'acceptation',
    'aval_signature',
  ];
}
