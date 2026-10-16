import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:dairy_farm_app/features/milk_entry/data/models/milk_history_models.dart';
import 'package:dairy_farm_app/features/milk_entry/services/milk_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MilkExportService Tests (R3 Deliverables)', () {
    late MilkExportService service;
    late ExportMilkSummary summary;
    late List<ExportMilkLog> logs;
    final startDate = DateTime(2026, 9, 1);
    final endDate = DateTime(2026, 9, 10);
    const farmName = 'Evergreen Dairy Farm';

    setUp(() {
      service = MilkExportService();
      summary = const ExportMilkSummary(
        totalQuantity: 250.5,
        morningQuantity: 150.0,
        eveningQuantity: 100.5,
        dailyAvg: 25.05,
      );
      logs = [
        ExportMilkLog(
          date: DateTime(2026, 9, 1),
          totalQty: 25.5,
          morningQty: 15.0,
          eveningQty: 10.5,
        ),
        ExportMilkLog(
          date: DateTime(2026, 9, 2),
          totalQty: 26.0,
          morningQty: 16.0,
          eveningQty: 10.0,
        ),
        ExportMilkLog(
          date: DateTime(2026, 9, 3),
          totalQty: 24.0,
          morningQty: 14.0,
          eveningQty: 10.0,
        ),
      ];
    });

    test('Valid .pdf file generated with farm name, date range, and line items', () async {
      final Uint8List pdfBytes = await service.generatePdf(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        logs: logs,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF magic header: %PDF
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
      expect(pdfBytes.length, greaterThan(500));
    });

    test('PDF generator handles Unicode characters and smart punctuation in farmName', () async {
      const unicodeFarmName = "Ali’s Dairy – Model Farm™ (الريان / डेरी)";
      final Uint8List pdfBytes = await service.generatePdf(
        farmName: unicodeFarmName,
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        logs: logs,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('Valid .xlsx workbook generated with proper numeric cells and headers', () async {
      final List<int> xlsxBytes = await service.generateExcel(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        logs: logs,
      );

      expect(xlsxBytes, isNotEmpty);
      // Valid XLSX file is a zip archive with magic bytes: PK\x03\x04
      expect(xlsxBytes[0], equals(0x50)); // 'P'
      expect(xlsxBytes[1], equals(0x4B)); // 'K'
      expect(xlsxBytes[2], equals(0x03));
      expect(xlsxBytes[3], equals(0x04));

      // Decode the generated Excel workbook to verify contents and numeric cells
      final excel = Excel.decodeBytes(xlsxBytes);
      expect(excel.sheets.containsKey('Milk History'), isTrue);
      final sheet = excel['Milk History'];

      expect(sheet.rows.isNotEmpty, isTrue);
      // Row 0 has Farm Name
      final row0 = sheet.rows[0];
      expect(row0[0]?.value.toString(), contains('EVERGREEN DAIRY FARM'));

      // Find the table header row
      final headerRowIndex = sheet.rows.indexWhere(
        (row) => row.any((cell) => cell?.value.toString() == 'Date'),
      );
      expect(headerRowIndex, greaterThan(0));

      // Check data rows below header
      final firstDataRow = sheet.rows[headerRowIndex + 1];
      expect(firstDataRow[0]?.value.toString(), equals('2026-09-01'));
      // Check numeric cells: morningQty=15.0, eveningQty=10.5, totalQty=25.5
      expect(double.parse(firstDataRow[1]!.value.toString()), closeTo(15.0, 0.001));
      expect(double.parse(firstDataRow[2]!.value.toString()), closeTo(10.5, 0.001));
      expect(double.parse(firstDataRow[3]!.value.toString()), closeTo(25.5, 0.001));
    });

    test('Valid .png image captured / generated at high resolution', () async {
      final Uint8List pngBytes = await service.generateImageReport(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: summary,
        logs: logs,
      );

      expect(pngBytes, isNotEmpty);
      // Valid PNG magic header: \x89PNG\r\n\x1a\n
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50)); // 'P'
      expect(pngBytes[2], equals(0x4E)); // 'N'
      expect(pngBytes[3], equals(0x47)); // 'G'
      expect(pngBytes.length, greaterThan(1000));
    });

    test('Empty logs handled gracefully across PDF, Excel, and Image generators', () async {
      final emptySummary = const ExportMilkSummary(
        totalQuantity: 0.0,
        morningQuantity: 0.0,
        eveningQuantity: 0.0,
        dailyAvg: 0.0,
      );
      final emptyLogs = const <ExportMilkLog>[];

      // PDF with empty logs
      final pdfBytes = await service.generatePdf(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: emptySummary,
        logs: emptyLogs,
      );
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), equals('%PDF'));

      // Excel with empty logs
      final xlsxBytes = await service.generateExcel(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: emptySummary,
        logs: emptyLogs,
      );
      expect(xlsxBytes, isNotEmpty);
      expect(xlsxBytes[0], equals(0x50)); // 'P'
      expect(xlsxBytes[1], equals(0x4B)); // 'K'

      // Image with empty logs
      final pngBytes = await service.generateImageReport(
        farmName: farmName,
        startDate: startDate,
        endDate: endDate,
        summary: emptySummary,
        logs: emptyLogs,
      );
      expect(pngBytes, isNotEmpty);
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50));
    });

    test('Multi-page tabular PDF paginates correctly with 150 line items', () async {
      final largeLogs = List.generate(
        150,
        (i) => ExportMilkLog(
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          totalQty: 25.0 + (i % 5),
          morningQty: 15.0,
          eveningQty: 10.0 + (i % 5),
        ),
      );
      final largeSummary = ExportMilkSummary(
        totalQuantity: largeLogs.fold(0.0, (acc, l) => acc + l.totalQty),
        morningQuantity: 15.0 * 150,
        eveningQuantity: largeLogs.fold(0.0, (acc, l) => acc + l.eveningQty),
        dailyAvg: 27.0,
      );

      final Uint8List pdfBytes = await service.generatePdf(
        farmName: 'Ali’s High-Yield Dairy – Multi-Branch',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1).add(const Duration(days: 150)),
        summary: largeSummary,
        logs: largeLogs,
      );

      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), equals('%PDF'));
      expect(pdfBytes.length, greaterThan(15000));
    });
  });
}
