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
  /// (proche de 235 x 105 mm).
  static const double pageWidthMm = 235;
  static const double pageHeightMm = 105;

  static PdfPageFormat get pageFormat => PdfPageFormat(
        pageWidthMm * PdfPageFormat.mm,
        pageHeightMm * PdfPageFormat.mm,
        marginAll: 0,
      );

  /// Champs alimentés automatiquement par l'ERP (voir §1.8-A) : ne
  /// nécessitent jamais de saisie manuelle.
  static const Map<String, BillField> autoFields = {
    'ordre_paiement_no': BillField(name: 'ordre_paiement_no', xMm: 190, yMm: 12, widthMm: 40, align: FieldAlign.left, fontSize: 8),
    'echeance': BillField(name: 'echeance', xMm: 60, yMm: 12, widthMm: 35, fontSize: 10, bold: true),
    'lieu_paiement': BillField(name: 'lieu_paiement', xMm: 105, yMm: 12, widthMm: 30, fontSize: 8),
    'montant_chiffres_1': BillField(name: 'montant_chiffres_1', xMm: 195, yMm: 22, widthMm: 38, fontSize: 10, bold: true, align: FieldAlign.right),
    'montant_chiffres_2': BillField(name: 'montant_chiffres_2', xMm: 195, yMm: 40, widthMm: 38, fontSize: 10, bold: true, align: FieldAlign.right),
    'rib_code_banque': BillField(name: 'rib_code_banque', xMm: 12, yMm: 24, widthMm: 12, fontSize: 9, align: FieldAlign.center),
    'rib_code_agence': BillField(name: 'rib_code_agence', xMm: 26, yMm: 24, widthMm: 14, fontSize: 9, align: FieldAlign.center),
    'rib_compte': BillField(name: 'rib_compte', xMm: 42, yMm: 24, widthMm: 45, fontSize: 9, align: FieldAlign.center),
    'rib_cle': BillField(name: 'rib_cle', xMm: 90, yMm: 24, widthMm: 10, fontSize: 9, align: FieldAlign.center),
    'nom_beneficiaire': BillField(name: 'nom_beneficiaire', xMm: 60, yMm: 33, widthMm: 100, fontSize: 8),
    'nom_tireur': BillField(name: 'nom_tireur', xMm: 5, yMm: 45, widthMm: 90, fontSize: 9, bold: true),
    'montant_lettres': BillField(name: 'montant_lettres', xMm: 5, yMm: 58, widthMm: 150, fontSize: 9),
    'lieu_creation': BillField(name: 'lieu_creation', xMm: 5, yMm: 68, widthMm: 45, fontSize: 9),
    'date_creation': BillField(name: 'date_creation', xMm: 55, yMm: 68, widthMm: 35, fontSize: 9),
    'echeance_2': BillField(name: 'echeance_2', xMm: 95, yMm: 68, widthMm: 35, fontSize: 9),
    'rib_code_banque_2': BillField(name: 'rib_code_banque_2', xMm: 12, yMm: 78, widthMm: 12, fontSize: 9, align: FieldAlign.center),
    'rib_code_agence_2': BillField(name: 'rib_code_agence_2', xMm: 26, yMm: 78, widthMm: 14, fontSize: 9, align: FieldAlign.center),
    'rib_compte_2': BillField(name: 'rib_compte_2', xMm: 42, yMm: 78, widthMm: 45, fontSize: 9, align: FieldAlign.center),
    'rib_cle_2': BillField(name: 'rib_cle_2', xMm: 90, yMm: 78, widthMm: 10, fontSize: 9, align: FieldAlign.center),
    'nom_adresse_tire': BillField(name: 'nom_adresse_tire', xMm: 130, yMm: 74, widthMm: 60, fontSize: 8),
    'domiciliation': BillField(name: 'domiciliation', xMm: 195, yMm: 78, widthMm: 38, fontSize: 8),
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
