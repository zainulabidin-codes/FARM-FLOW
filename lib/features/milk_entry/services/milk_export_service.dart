import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/milk_history_models.dart';

/// Service responsible for generating multi-format export documents (PDF, Excel, PNG)
/// and handling native sharing and file persistence.
class MilkExportService {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat _numberFormat = NumberFormat('#,##0.0');

  /// Normalizes smart typography and non-standard symbols to ASCII equivalents
  /// so standard Type 1 fonts (Helvetica) render cleanly without font warnings or missing glyphs.
  String _sanitizePdfText(String text) {
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('•', '-')
        .replaceAll('™', '(TM)')
        .replaceAll('®', '(R)')
        .replaceAll('©', '(C)')
        .replaceAll('\u00A0', ' ');
  }

  /// Generates a multi-page tabular PDF document conforming to R3.
  Future<Uint8List> generatePdf({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    final pdf = pw.Document();
    final daysSpan = endDate.difference(startDate).inDays.abs() + 1;
    final sanitizedFarm = _sanitizePdfText(farmName.toUpperCase());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sanitizedFarm,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Milk History & Production Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF00522A),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date Range: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$daysSpan Days Span',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          );
        },
        build: (pw.Context context) => [
          // Summary overview card
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF3F5F4),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfSummaryItem(
                  'Total Milk',
                  '${_numberFormat.format(summary.totalQuantity)} Kg',
                ),
                _buildPdfSummaryItem(
                  'Gross Earnings',
                  'PKR ${_numberFormat.format(summary.grossRevenue)}',
                ),
                _buildPdfSummaryItem(
                  'Morning Qty',
                  '${_numberFormat.format(summary.morningQuantity)} Kg',
                ),
                _buildPdfSummaryItem(
                  'Evening Qty',
                  '${_numberFormat.format(summary.eveningQuantity)} Kg',
                ),
                _buildPdfSummaryItem(
                  'Daily Average',
                  '${_numberFormat.format(summary.dailyAvg)} Kg/day',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Daily breakdown title
          pw.Text(
            'Daily Breakdown (${logs.length} Line Items)',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1B2420),
            ),
          ),
          pw.SizedBox(height: 10),

          // Tabular line items
          pw.TableHelper.fromTextArray(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF00522A),
              fontSize: 9,
            ),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F2EC),
            ),
            cellHeight: 24,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: const ['Date', 'Morning (Kg)', 'Evening (Kg)', 'Total (Kg)', 'Amount (PKR)'],
            data: logs.map((log) => [
              _dateFormat.format(log.date),
              _numberFormat.format(log.morningQty),
              _numberFormat.format(log.eveningQty),
              _numberFormat.format(log.totalQty),
              'PKR ${_numberFormat.format(log.amount)}',
            ]).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF00522A),
          ),
        ),
      ],
    );
  }

  /// Generates a formatted binary Excel workbook (.xlsx) conforming to R3.
  Future<List<int>> generateExcel({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    final excel = Excel.createExcel();
    const String sheetName = 'Milk History';
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // Header metadata
    sheet.appendRow([TextCellValue(farmName.toUpperCase())]);
    sheet.appendRow([TextCellValue('Milk History & Production Report')]);
    sheet.appendRow([
      TextCellValue(
        'Date Range: ${_dateFormat.format(startDate)} – ${_dateFormat.format(endDate)}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Summary block
    sheet.appendRow([
      TextCellValue('Total Quantity (Kg)'),
      DoubleCellValue(summary.totalQuantity),
      TextCellValue('Gross Revenue (PKR)'),
      DoubleCellValue(summary.grossRevenue),
      TextCellValue('Morning (Kg)'),
      DoubleCellValue(summary.morningQuantity),
      TextCellValue('Evening (Kg)'),
      DoubleCellValue(summary.eveningQuantity),
      TextCellValue('Daily Avg (Kg/day)'),
      DoubleCellValue(summary.dailyAvg),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Line items table header
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Morning (Kg)'),
      TextCellValue('Evening (Kg)'),
      TextCellValue('Total (Kg)'),
      TextCellValue('Amount (PKR)'),
    ]);

    // Line items
    for (final log in logs) {
      sheet.appendRow([
        TextCellValue(_isoDateFormat.format(log.date)),
        DoubleCellValue(log.morningQty),
        DoubleCellValue(log.eveningQty),
        DoubleCellValue(log.totalQty),
        DoubleCellValue(log.amount),
      ]);
    }

    final bytes = excel.save();
    return bytes ?? <int>[];
  }

  /// Captures a RenderRepaintBoundary as a high-resolution PNG at the specified pixelRatio (default 3.0x).
  Future<Uint8List> captureBoundaryImage(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode RenderRepaintBoundary to PNG bytes.');
    }
    return byteData.buffer.asUint8List();
  }

  /// High-resolution rendered image fallback / direct generator using Flutter Canvas at 3.0x equivalent scale.
  Future<Uint8List> generateImageReport({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    const double width = 1080.0;
    final double headerHeight = 320.0;
    final double rowHeight = 60.0;
    final double totalHeight = headerHeight + (logs.length * rowHeight) + 120.0;

    // Background
    final bgPaint = ui.Paint()..color = const ui.Color(0xFFFBF9F4);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, totalHeight), bgPaint);

    // Header Card
    final cardPaint = ui.Paint()..color = const ui.Color(0xFF00522A);
    final cardRRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(40, 40, width - 80, 240),
      const ui.Radius.circular(24),
    );
    canvas.drawRRect(cardRRect, cardPaint);

    void drawText(String text, double x, double y,
        {double fontSize = 24,
        ui.Color color = const ui.Color(0xFFFFFFFF),
        ui.FontWeight fontWeight = ui.FontWeight.normal}) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: fontSize, fontWeight: fontWeight),
      )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(text);
      final p = pb.build()..layout(const ui.ParagraphConstraints(width: width - 100));
      canvas.drawParagraph(p, ui.Offset(x, y));
    }

    drawText(farmName.toUpperCase(), 70, 65,
        fontSize: 20, color: const ui.Color(0xFFA2D4B6), fontWeight: ui.FontWeight.bold);
    drawText('Milk Export Report', 70, 95,
        fontSize: 34, color: const ui.Color(0xFFFFFFFF), fontWeight: ui.FontWeight.bold);
    drawText(
      '${_dateFormat.format(startDate)} – ${_dateFormat.format(endDate)}',
      70,
      145,
      fontSize: 20,
      color: const ui.Color(0xFFE0E0E0),
    );
    drawText(
      'Total Milk: ${_numberFormat.format(summary.totalQuantity)} Kg   |   Gross: PKR ${_numberFormat.format(summary.grossRevenue)}',
      70,
      180,
      fontSize: 22,
      color: const ui.Color(0xFFA2D4B6),
      fontWeight: ui.FontWeight.w700,
    );
    drawText(
      'Morning: ${_numberFormat.format(summary.morningQuantity)} Kg   •   Evening: ${_numberFormat.format(summary.eveningQuantity)} Kg   •   Daily Avg: ${_numberFormat.format(summary.dailyAvg)} Kg/day',
      70,
      220,
      fontSize: 18,
      color: const ui.Color(0xFFE0E0E0),
    );

    // Table Header
    double currentY = 320;
    final thPaint = ui.Paint()..color = const ui.Color(0xFFE8ECE9);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(40, currentY, width - 80, 50),
        const ui.Radius.circular(12),
      ),
      thPaint,
    );
    drawText('Date', 60, currentY + 12,
        fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);
    drawText('Morning (Kg)', 270, currentY + 12,
        fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);
    drawText('Evening (Kg)', 470, currentY + 12,
        fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);
    drawText('Total (Kg)', 670, currentY + 12,
        fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);
    drawText('Amount (PKR)', 860, currentY + 12,
        fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);

    currentY += 60;
    final rowLinePaint = ui.Paint()
      ..color = const ui.Color(0xFFE0E0E0)
      ..strokeWidth = 1.0;

    for (final log in logs) {
      drawText(_dateFormat.format(log.date), 60, currentY + 14,
          fontSize: 18, color: const ui.Color(0xFF1B2420), fontWeight: ui.FontWeight.w600);
      drawText(_numberFormat.format(log.morningQty), 270, currentY + 14,
          fontSize: 18, color: const ui.Color(0xFF4A5568));
      drawText(_numberFormat.format(log.eveningQty), 470, currentY + 14,
          fontSize: 18, color: const ui.Color(0xFF4A5568));
      drawText(_numberFormat.format(log.totalQty), 670, currentY + 14,
          fontSize: 19, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.bold);
      drawText('PKR ${_numberFormat.format(log.amount)}', 860, currentY + 14,
          fontSize: 18, color: const ui.Color(0xFF00522A), fontWeight: ui.FontWeight.w700);

      canvas.drawLine(
        ui.Offset(40, currentY + rowHeight - 2),
        ui.Offset(width - 40, currentY + rowHeight - 2),
        rowLinePaint,
      );
      currentY += rowHeight;
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  /// Persists exported file to device storage.
  /// On Android:
  /// - Images are saved to MediaStore Pictures/FarmFlow so they immediately appear in the Gallery.
  /// - PDFs and Spreadsheets are saved to MediaStore Downloads/FarmFlow.
  /// On desktop / other platforms, saves to Downloads or Documents directory.
  Future<File> saveFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final lower = fileName.toLowerCase();
    final mimeType = getMimeType(fileName);

    if (Platform.isAndroid) {
      const MethodChannel channel = MethodChannel('com.dairyfarm.app/media_saver');
      try {
        if (lower.endsWith('.png')) {
          final String? savedPath = await channel.invokeMethod<String>(
            'saveImageToGallery',
            {
              'bytes': Uint8List.fromList(bytes),
              'fileName': fileName,
            },
          );
          if (savedPath != null && savedPath.isNotEmpty) {
            return File(savedPath);
          }
        } else {
          final String? savedPath = await channel.invokeMethod<String>(
            'saveFileToDownloads',
            {
              'bytes': Uint8List.fromList(bytes),
              'fileName': fileName,
              'mimeType': mimeType,
            },
          );
          if (savedPath != null && savedPath.isNotEmpty) {
            return File(savedPath);
          }
        }
      } catch (_) {
        // Fall back to path_provider if MethodChannel is not registered (e.g. in test env)
      }
    }

    Directory? directory;
    try {
      directory = await getDownloadsDirectory();
    } catch (_) {}
    directory ??= await getApplicationDocumentsDirectory();

    final File file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Helper to deduce standard MIME types for shared files.
  String getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return 'application/octet-stream';
  }

  /// Shares exported document via native platform share dialog.
  Future<void> shareFile({
    required String fileName,
    required List<int> bytes,
    required String subject,
    String? mimeType,
    ui.Rect? sharePositionOrigin,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final resolvedMimeType = mimeType ?? getMimeType(fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: resolvedMimeType)],
        subject: subject,
        text: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
