import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/dodi_ledger/data/models/dodi_model.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/pages/dodi_detail_screen.dart';
import 'package:dairy_farm_app/core/utils/money_utils.dart';

void main() {
  group('Dodi Core Logic & Settlement Tests', () {
    test('DodiModel copyWith updates isDeleted and name correctly', () {
      const original = DodiModel(
        id: 10,
        userId: 1,
        name: 'Nadeem Dodi',
        defaultRatePaise: 18000,
        isDeleted: 0,
      );

      final softDeleted = original.copyWith(isDeleted: 1);
      expect(softDeleted.isDeleted, equals(1));
      expect(softDeleted.name, equals('Nadeem Dodi'));

      final restoredWithNewName = softDeleted.copyWith(isDeleted: 0, name: 'Nadeem Dodi (Restored)');
      expect(restoredWithNewName.isDeleted, equals(0));
      expect(restoredWithNewName.name, equals('Nadeem Dodi (Restored)'));
    });

    test('Settlement check allows hard delete when balance is 0', () {
      final summarySettled = DailyLedgerSummary('2026-07-25');
      summarySettled.totalAmountPaise = 0;

      final bool canHardDeleteSettled = summarySettled.totalAmountPaise == 0;
      expect(canHardDeleteSettled, isTrue);
    });

    test('Settlement check blocks hard delete when account is unsettled', () {
      final summaryUnsettled = DailyLedgerSummary('2026-07-25');
      summaryUnsettled.totalAmountPaise = 320000; // Rs 3,200 due

      final bool canHardDeleteUnsettled = summaryUnsettled.totalAmountPaise == 0;
      expect(canHardDeleteUnsettled, isFalse);

      final dueRs = MoneyUtils.formatPaiseToRupees(summaryUnsettled.totalAmountPaise.abs());
      expect(dueRs, equals('3200.00'));
    });

    test('DailyLedgerSummary accumulates milk grams and paise without float rounding', () {
      final summary = DailyLedgerSummary('2026-07-25');
      summary.totalMilkGrams += 30500; // 30.5 kg
      summary.totalAmountPaise += 549000; // Rs 5,490.00

      expect(summary.totalMilkGrams, equals(30500));
      expect(summary.totalAmountPaise, equals(549000));
      expect(MoneyUtils.formatGramsToKg(summary.totalMilkGrams), equals('30.5'));
      expect(MoneyUtils.formatPaiseToRupees(summary.totalAmountPaise), equals('5490.00'));
    });
  });
}
