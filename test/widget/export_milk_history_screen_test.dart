import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/milk_entry/data/models/milk_history_models.dart';
import 'package:dairy_farm_app/features/milk_entry/data/repositories/milk_history_repository.dart';
import 'package:dairy_farm_app/features/milk_entry/services/milk_export_service.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/pages/export_milk_history_screen.dart';

class FakeExportRepository implements MilkHistoryRepository {
  final ExportMilkSummary summaryToReturn;
  final List<ExportMilkLog> logsToReturn;

  FakeExportRepository({
    required this.summaryToReturn,
    required this.logsToReturn,
  });

  @override
  Future<DateTime> getEarliestUserActivityDate(int userId) async {
    return DateTime(2025, 1, 1);
  }

  @override
  Future<MilkHistoryOverview> getMilkHistoryForMonth({
    required int userId,
    required DateTime month,
    int? daysToShow,
  }) async {
    return MilkHistoryOverview.empty(earliestActivityDate: DateTime(2025, 1, 1));
  }

  @override
  Future<({ExportMilkSummary summary, List<ExportMilkLog> logs})> getExportDataForRange({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return (summary: summaryToReturn, logs: logsToReturn);
  }
}

class FakeMilkExportService extends MilkExportService {
  bool pdfCalled = false;
  bool excelCalled = false;
  bool imageCalled = false;
  bool shareCalled = false;
  bool saveCalled = false;
  String? lastSavedFileName;
  String? lastSharedFileName;

  @override
  Future<Uint8List> generatePdf({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    pdfCalled = true;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<List<int>> generateExcel({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    excelCalled = true;
    return [4, 5, 6];
  }

  @override
  Future<Uint8List> captureBoundaryImage(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    imageCalled = true;
    return Uint8List.fromList([7, 8, 9]);
  }

  @override
  Future<Uint8List> generateImageReport({
    required String farmName,
    required DateTime startDate,
    required DateTime endDate,
    required ExportMilkSummary summary,
    required List<ExportMilkLog> logs,
  }) async {
    imageCalled = true;
    return Uint8List.fromList([7, 8, 9]);
  }

  @override
  Future<File> saveFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    saveCalled = true;
    lastSavedFileName = fileName;
    return File('/dummy/documents/$fileName');
  }

  @override
  Future<void> shareFile({
    required String fileName,
    required List<int> bytes,
    required String subject,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) async {
    shareCalled = true;
    lastSharedFileName = fileName;
  }
}

void main() {
  group('ExportMilkHistoryScreen Widget Tests (R3)', () {
    testWidgets('Export triggers are disabled and validation notice shown when zero records match range', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeExportRepository(
        summaryToReturn: ExportMilkSummary.empty,
        logsToReturn: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExportMilkHistoryScreen(
            farmName: 'Sunset Dairy',
            userId: 202,
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Validation notice card is shown
      expect(find.text('No records match this date range'), findsOneWidget);

      // Generate File button is disabled
      final generateButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Generate File'),
      );
      expect(generateButton.onPressed, isNull);
    });

    testWidgets('Export triggers are enabled and logs rendered when records exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final logs = [
        ExportMilkLog(
          date: DateTime(2026, 10, 1),
          totalQty: 50.0,
          morningQty: 30.0,
          eveningQty: 20.0,
          amount: 5000.0,
        ),
        ExportMilkLog(
          date: DateTime(2026, 10, 2),
          totalQty: 55.0,
          morningQty: 32.0,
          eveningQty: 23.0,
          amount: 5500.0,
        ),
      ];
      const summary = ExportMilkSummary(
        totalQuantity: 105.0,
        morningQuantity: 62.0,
        eveningQuantity: 43.0,
        dailyAvg: 52.5,
        grossRevenue: 10500.0,
      );

      final fakeRepo = FakeExportRepository(
        summaryToReturn: summary,
        logsToReturn: logs,
      );
      final fakeExportService = FakeMilkExportService();

      await tester.pumpWidget(
        MaterialApp(
          home: ExportMilkHistoryScreen(
            farmName: 'Sunset Dairy',
            userId: 202,
            repository: fakeRepo,
            exportService: fakeExportService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Validation notice is NOT shown
      expect(find.text('No records match this date range'), findsNothing);

      // Summary quantities & PKR gross earnings rendered
      expect(find.text('105.0'), findsOneWidget);
      expect(find.text('62.0'), findsOneWidget);
      expect(find.text('43.0'), findsOneWidget);
      expect(find.text('Gross Earnings'), findsOneWidget);
      expect(find.text('PKR '), findsOneWidget);
      expect(find.text('10,500.0'), findsOneWidget);

      // Logs header count rendered
      expect(find.text('2 Logs'), findsOneWidget);

      // Single Generate File button is enabled
      final generateButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Generate File'),
      );
      expect(generateButton.onPressed, isNotNull);

      // Test format selector dropdown works
      expect(find.text('Pdf'), findsOneWidget);
      await tester.tap(find.text('Pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Excel'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);
      await tester.tap(find.text('Excel').last);
      await tester.pumpAndSettle();

      expect(find.text('Excel'), findsOneWidget);

      // Tap Generate File -> opens centered modal dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate File'));
      await tester.pumpAndSettle();

      expect(find.text('Export File Name'), findsOneWidget);
      expect(find.text('Save Report'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Tap Save Report inside modal dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Report'));
      await tester.pumpAndSettle();

      expect(fakeExportService.excelCalled, isTrue);
      expect(fakeExportService.saveCalled, isTrue);
      expect(fakeExportService.lastSavedFileName, endsWith('.xlsx'));

      // Dismiss any toasts/snackbars
      ScaffoldMessenger.of(tester.element(find.byType(ExportMilkHistoryScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Switch to Pdf
      await tester.tap(find.text('Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pdf').last);
      await tester.pumpAndSettle();

      // Tap Generate File -> dialog opens
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate File'));
      await tester.pumpAndSettle();

      // Custom file name editing test
      await tester.enterText(find.byType(TextField), 'custom_milk_october');
      await tester.pumpAndSettle();

      // Tap Share inside modal dialog
      await tester.tap(find.widgetWithText(OutlinedButton, 'Share'));
      await tester.pumpAndSettle();

      expect(fakeExportService.pdfCalled, isTrue);
      expect(fakeExportService.shareCalled, isTrue);
      expect(fakeExportService.lastSharedFileName, equals('custom_milk_october.pdf'));

      // Switch to Image
      await tester.tap(find.text('Pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image').last);
      await tester.pumpAndSettle();

      // Tap Generate File -> dialog opens
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate File'));
      await tester.pumpAndSettle();

      // Tap Save Report inside dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Report'));
      await tester.pumpAndSettle();

      expect(fakeExportService.imageCalled, isTrue);
      expect(fakeExportService.lastSavedFileName, endsWith('.png'));
    });

    testWidgets('Date picker opens safely without assertion crashes and handles boundary selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeExportRepository(
        summaryToReturn: ExportMilkSummary.empty,
        logsToReturn: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExportMilkHistoryScreen(
            farmName: 'Sunset Dairy',
            userId: 202,
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Start Date picker container
      final startDateContainer = find.text('Start Date');
      expect(startDateContainer, findsOneWidget);
      await tester.tap(startDateContainer);
      await tester.pumpAndSettle();

      // Verify showDatePicker dialog opens
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss dialog by tapping Cancel
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      }

      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });
}
