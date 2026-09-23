import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/supabase/supabase_client_provider.dart';
import '../models/employee.dart';
import '../models/payslip.dart';

class PayrollPdfService {
  final _client = SupabaseService.client;

  Future<void> generatePayslip(Payslip payslip, Employee employee) async {
    final company = await _client.from('company_settings').select().limit(1).maybeSingle();
    final bytes = await _build(payslip, employee, company ?? const {});
    final month = '${payslip.periodMonth.month.toString().padLeft(2, '0')}_${payslip.periodMonth.year}';
    final name = 'FICHE_PAIE_${employee.fullName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_$month';
    await FileSaver.instance.saveFile(name: name, bytes: Uint8List.fromList(bytes), ext: 'pdf', mimeType: MimeType.pdf);
  }

  Future<pw.ThemeData> _loadTheme() async {
    final regular = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  Future<List<int>> _build(Payslip p, Employee e, Map<String, dynamic> company) async {
    final theme = await _loadTheme();
    final document = pw.Document(theme: theme);
    final money = NumberFormat('#,##0.000', 'fr_FR');
    String text(Map x, String key) => x[key]?.toString() ?? '';
    final month = '${p.periodMonth.month.toString().padLeft(2, '0')}/${p.periodMonth.year}';

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(text(company, 'company_name'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    if (text(company, 'address').isNotEmpty) pw.Text(text(company, 'address')),
                    if (text(company, 'tax_id').isNotEmpty) pw.Text('MF: ${text(company, 'tax_id')}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FICHE DE PAIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                    pw.Text('Période : $month'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text('Employé : ${e.fullName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (e.cnssNumber?.isNotEmpty == true) pw.Text('N° CNSS : ${e.cnssNumber}'),
            pw.SizedBox(height: 16),
            _section('Éléments de salaire'),
            _row('Salaire de base', p.baseSalary, money),
            _row('Primes', p.bonuses, money),
            _row('Indemnité transport', p.transportAllowance, money),
            _row('Autres avantages', p.otherAllowances, money),
            pw.Divider(),
            _row('Salaire brut', p.grossSalary, money, bold: true),
            pw.SizedBox(height: 12),
            _section('Retenues'),
            _row('CNSS salarié (9.18%)', p.cnssEmployee, money),
            _row('CSS (1%)', p.css, money),
            _row('Base imposable', p.taxableBase, money),
            _row('IRPP', p.irpp, money),
            if (p.otherDeductions > 0) _row('Autres retenues', p.otherDeductions, money),
            pw.Divider(),
            _row('Net à payer', p.netSalary, money, bold: true),
            if (p.notes?.isNotEmpty == true)
              pw.Padding(padding: const pw.EdgeInsets.only(top: 16), child: pw.Text('Notes : ${p.notes}')),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text('Document généré automatiquement', style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _section(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  pw.Widget _row(String label, double value, NumberFormat money, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('${money.format(value)} TND', style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
