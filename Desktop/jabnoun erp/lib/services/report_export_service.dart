import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

class ReportExportService {
  static Future<void> exportXlsx({required String filename, required String sheetName, required List<String> headers, required List<List<Object?>> rows}) async {
    final workbook = Excel.createExcel();
    final sheet = workbook[sheetName];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((value) => TextCellValue(value?.toString() ?? '')).toList());
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Export vide.');
    await FileSaver.instance.saveFile(name: filename, bytes: Uint8List.fromList(bytes), mimeType: MimeType.microsoftExcel);
  }
}
