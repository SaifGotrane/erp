import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/bill_of_exchange.dart';
import 'bill_of_exchange_template.dart';
import 'number_to_words_fr.dart';

/// Imprime les informations variables d'une (ou plusieurs) lettre(s) de
/// change sur le formulaire pré-imprimé physique (§1.7-1.16). Ce service ne
/// génère PAS un nouveau design de traite : il produit un calque de texte
/// destiné à être imprimé directement sur le papier pré-imprimé existant
/// (voir [BillOfExchangePdfTemplate] pour les coordonnées, ajustables).
class BillOfExchangePdfService {
  final _money = NumberFormat('#,##0.000', 'fr_FR');

  Future<void> printBatch(List<BillOfExchange> bills, {required String tireurAddress, required String tireAddress}) async {
    final document = pw.Document();
    for (final bill in bills) {
      document.addPage(_buildPage(bill, tireurAddress: tireurAddress, tireAddress: tireAddress));
    }
    final bytes = await document.save();
    final ref = bills.length == 1 ? bills.first.billNumber : bills.first.settlementId;
    await FileSaver.instance.saveFile(
      name: 'LETTRES_DE_CHANGE_${ref.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}',
      bytes: Uint8List.fromList(bytes),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  pw.Page _buildPage(BillOfExchange bill, {required String tireurAddress, required String tireAddress}) {
    final fields = BillOfExchangePdfTemplate.autoFields;
    final dateFmt = DateFormat('dd/MM/yyyy');

    final values = <String, String>{
      'ordre_paiement_no': bill.billNumber,
      'echeance': dateFmt.format(bill.dueDate),
      'echeance_2': dateFmt.format(bill.dueDate),
      'lieu_paiement': bill.billPlace ?? '',
      'montant_chiffres_1': '${_money.format(bill.amount)} DT',
      'montant_chiffres_2': '${_money.format(bill.amount)} DT',
      'rib_code_banque': bill.ribCodeBanque ?? '',
      'rib_code_agence': bill.ribCodeAgence ?? '',
      'rib_compte': bill.ribCompte ?? '',
      'rib_cle': bill.ribCle ?? '',
      'rib_code_banque_2': bill.ribCodeBanque ?? '',
      'rib_code_agence_2': bill.ribCodeAgence ?? '',
      'rib_compte_2': bill.ribCompte ?? '',
      'rib_cle_2': bill.ribCle ?? '',
      'nom_beneficiaire': bill.supplierName,
      'nom_tireur': bill.supplierName,
      'nom_adresse_tire': tireAddress,
      'montant_lettres': amountToFrenchWords(bill.amount),
      'lieu_creation': bill.billPlace ?? '',
      'date_creation': dateFmt.format(bill.creationDate),
      'domiciliation': '${bill.bankName ?? ''}\n${bill.bankAgency ?? ''}',
    };

    return pw.Page(
      pageFormat: BillOfExchangePdfTemplate.pageFormat,
      build: (context) {
        final pageHeightMm = BillOfExchangePdfTemplate.pageHeightMm;
        return pw.Stack(
          children: [
            for (final entry in fields.entries)
              if ((values[entry.key] ?? '').isNotEmpty)
                pw.Positioned(
                  left: entry.value.xMm * PdfPageFormat.mm,
                  // PDF widgets' Positioned uses top-left origin already
                  // (unlike raw pdf.Rect), matching our mm-from-top convention.
                  top: entry.value.yMm * PdfPageFormat.mm,
                  child: pw.Container(
                    width: entry.value.widthMm * PdfPageFormat.mm,
                    child: pw.Text(
                      values[entry.key] ?? '',
                      style: pw.TextStyle(
                        fontSize: entry.value.fontSize,
                        fontWeight: entry.value.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                      textAlign: entry.value.align == FieldAlign.center
                          ? pw.TextAlign.center
                          : entry.value.align == FieldAlign.right
                              ? pw.TextAlign.right
                              : pw.TextAlign.left,
                    ),
                  ),
                ),
            pw.Positioned(
              left: 2 * PdfPageFormat.mm,
              top: (pageHeightMm - 6) * PdfPageFormat.mm,
              child: pw.Text(
                'Tireur: $tireurAddress',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
              ),
            ),
          ],
        );
      },
    );
  }
}
