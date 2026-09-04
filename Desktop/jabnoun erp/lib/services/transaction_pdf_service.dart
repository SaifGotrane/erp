import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/supabase/supabase_client_provider.dart';

class TransactionPdfService {
  final _client = SupabaseService.client;

  Future<void> saleDocuments(String id) => _documents(id, sale: true);
  Future<void> purchaseDocuments(String id) => _documents(id, sale: false);
  Future<void> deliveryNoteDocument(String id) async {
    final data = await _client.from('delivery_notes').select('*, customer:customers(*), depot:depots(*), showroom:showrooms(*), vehicle:vehicles(*), driver:drivers(*), delivery_note_lines(*, article:articles(reference,designation,unit:units(name,symbol)))').eq('id', id).single();
    final company = await _client.from('company_settings').select().limit(1).maybeSingle();
    final bytes = await _buildDelivery(data, company ?? const {});
    final reference = (data['document_number'] ?? id).toString().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await FileSaver.instance.saveFile(name: 'BON_LIVRAISON_$reference', bytes: Uint8List.fromList(bytes), ext: 'pdf', mimeType: MimeType.pdf);
  }

  Future<void> _documents(String id, {required bool sale}) async {
    final table = sale ? 'sales' : 'purchases';
    final partner = sale ? 'customer:customers(*)' : 'supplier:suppliers(*)';
    final lines = sale
        ? 'sale_lines(*, article:articles(reference,designation,unit:units(name,symbol)))'
        : 'purchase_lines(*, article:articles(reference,designation,unit:units(name,symbol)))';
    final location = sale ? 'depot:depots(*), showroom:showrooms(*)' : 'depot:depots(*)';
    final data = await _client.from(table).select('*, $partner, $location, payment_method:payment_methods(name), $lines').eq('id', id).single();
    final company = await _client.from('company_settings').select().limit(1).maybeSingle();
    final types = sale ? const [('BON_LIVRAISON', 'Bon de Livraison'), ('FACTURE', 'Facture')] : const [('BON_SORTIE', 'Bon de Sortie'), ('FACTURE', 'Facture')];
    final reference = (data['document_number'] ?? id).toString().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    for (final type in types) {
      final bytes = await _build(data, company ?? const {}, type.$2, sale);
      await FileSaver.instance.saveFile(name: '${sale ? 'VENTE' : 'ACHAT'}_${type.$1}_$reference', bytes: Uint8List.fromList(bytes), ext: 'pdf', mimeType: MimeType.pdf);
    }
  }

  Future<List<int>> _build(Map<String, dynamic> d, Map<String, dynamic> c, String title, bool sale) async {
    final document = pw.Document(); final money = NumberFormat('#,##0.000', 'fr_FR');
    final isFacture = title == 'Facture';
    final partner = (d[sale ? 'customer' : 'supplier'] as Map?)?.cast<String, dynamic>() ?? {};
    final location = ((d['depot'] ?? d['showroom']) as Map?)?.cast<String, dynamic>() ?? {};
    final lineRows = (d[sale ? 'sale_lines' : 'purchase_lines'] as List? ?? []).cast<Map>();
    final displayName = (d['customer_display_name'] as String?)?.trim();
    final stampDuty = sale ? (d['stamp_duty_amount'] as num?)?.toDouble() ?? 0 : 0;
    String text(Map x, String key) => x[key]?.toString() ?? '';
    pw.Widget info(String heading, Map x, {String? nameOverride}) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(heading, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text((nameOverride != null && nameOverride.isNotEmpty) ? nameOverride : (text(x,'company_name').isNotEmpty ? text(x,'company_name') : text(x,'name'))), if(text(x,'address').isNotEmpty) pw.Text(text(x,'address')), if(text(x,'phone').isNotEmpty || text(x,'email').isNotEmpty) pw.Text('${text(x,'phone')} ${text(x,'email')}'), if(text(x,'tax_id').isNotEmpty) pw.Text('MF: ${text(x,'tax_id')}')]);
    document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (_) => [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [info('ÉMETTEUR', c), pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text(title.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)), pw.Text('N° ${text(d,'document_number')}'), pw.Text('Date: ${text(d, sale ? 'sale_date' : 'purchase_date')}'), pw.Text('Statut: ${text(d,'status')}')])]),
      pw.SizedBox(height: 18), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [info(sale ? 'CLIENT' : 'FOURNISSEUR', partner, nameOverride: sale ? displayName : null), info(sale ? 'DÉPÔT / SHOWROOM' : 'DÉPÔT', location)]), pw.SizedBox(height: 18),
      pw.Table.fromTextArray(headers: const ['Référence','Désignation','Qté','Unité','PU HT','Remise','TVA','Total TTC'], data: lineRows.map((raw) { final l=raw.cast<String,dynamic>(); final a=(l['article'] as Map?)?.cast<String,dynamic>()??{}; final u=(a['unit'] as Map?)?.cast<String,dynamic>()??{}; return [text(a,'reference'),text(a,'designation'),money.format(l['quantity']??0),text(u,'symbol').isNotEmpty?text(u,'symbol'):text(u,'name'),money.format(l['unit_price_ht']??0),'${l['discount_percent']??0}%', '${l['tax_rate_percent']??0}%',money.format(l['line_total_ttc']??0)]; }).toList(), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 8)),
      pw.SizedBox(height: 16), pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Total HT: ${money.format(d['total_ht']??0)}'),pw.Text('TVA: ${money.format(d['total_tva']??0)}'), if(sale && stampDuty > 0) pw.Text('Droit de timbre: ${money.format(stampDuty)}'), pw.Text('Total TTC: ${money.format(d['total_ttc']??0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),pw.Text('Payé: ${money.format(d['amount_paid']??0)}'), if(!isFacture && text(d,'payment_method').isNotEmpty) pw.Text('Paiement: ${text((d['payment_method'] as Map?)?.cast<String,dynamic>()??{},'name')}') ])), if(text(d,'notes').isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 16), child: pw.Text('Notes: ${text(d,'notes')}')),
    ], footer: (_) => pw.Align(alignment: pw.Alignment.center, child: pw.Text('${text(c,'company_name')} • Document généré automatiquement', style: const pw.TextStyle(fontSize: 8)))));
    return document.save();
  }

  Future<List<int>> _buildDelivery(Map<String, dynamic> d, Map<String, dynamic> c) async {
    final document = pw.Document();
    final customer = (d['customer'] as Map?)?.cast<String, dynamic>() ?? {};
    final location = ((d['depot'] ?? d['showroom']) as Map?)?.cast<String, dynamic>() ?? {};
    final lines = (d['delivery_note_lines'] as List? ?? []).cast<Map>();
    String value(Map map, String key) => map[key]?.toString() ?? '';
    document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (_) => [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(value(c, 'company_name'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)), pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text('BON DE LIVRAISON', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)), pw.Text('N° ${value(d, 'document_number')}'), pw.Text('Date: ${value(d, 'delivery_date')}')])]),
      pw.SizedBox(height: 16), pw.Text('Client: ${value(customer, 'name')}'), if (value(customer, 'address').isNotEmpty) pw.Text(value(customer, 'address')), pw.Text('Emplacement: ${value(location, 'name')}'),
      pw.SizedBox(height: 16), pw.Table.fromTextArray(headers: const ['Référence', 'Désignation', 'Qté', 'Unité'], data: lines.map((raw) { final line = raw.cast<String, dynamic>(); final article = (line['article'] as Map?)?.cast<String, dynamic>() ?? {}; final unit = (article['unit'] as Map?)?.cast<String, dynamic>() ?? {}; return [value(article, 'reference'), value(article, 'designation'), value(line, 'quantity'), value(unit, 'symbol').isNotEmpty ? value(unit, 'symbol') : value(unit, 'name')]; }).toList()),
      if (d['vehicle'] != null || d['driver'] != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 16), child: pw.Text('Véhicule: ${value((d['vehicle'] as Map?)?.cast<String, dynamic>() ?? {}, 'registration_number')}  Chauffeur: ${value((d['driver'] as Map?)?.cast<String, dynamic>() ?? {}, 'full_name')}')),
    ]));
    return document.save();
  }
}
