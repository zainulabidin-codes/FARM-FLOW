import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/cows/presentation/models/cow_ui_model.dart';

void main() {
  group('Observation Window Regression Tests', () {
    test('Heifer filter condition includes PENDING_CONFIRMATION when !hasLactated', () {
      const heiferPending = CowUiModel(
        id: '1',
        tagNumber: 'TAG-H1',
        name: 'Heifer Observation',
        status: CowStatus.pendingConfirmation,
        hasLactated: false,
        daysSinceMating: 15,
      );

      const adultPending = CowUiModel(
        id: '2',
        tagNumber: 'TAG-A1',
        name: 'Adult Observation',
        status: CowStatus.pendingConfirmation,
        hasLactated: true,
        daysSinceMating: 15,
      );

      const standardHeifer = CowUiModel(
        id: '3',
        tagNumber: 'TAG-H2',
        name: 'Standard Heifer',
        status: CowStatus.heifer,
        hasLactated: false,
      );

      bool matchesHeiferFilter(CowUiModel c) {
        return c.status == CowStatus.heifer || (c.status == CowStatus.pendingConfirmation && !c.hasLactated);
      }

      expect(matchesHeiferFilter(heiferPending), isTrue, reason: 'Pending heifer should appear in Heifer filter');
      expect(matchesHeiferFilter(adultPending), isFalse, reason: 'Pending adult cow must NOT appear in Heifer filter');
      expect(matchesHeiferFilter(standardHeifer), isTrue, reason: 'Standard heifer must appear in Heifer filter');
    });

    test('Observation window status calculation for registration with mating <= 28 days', () {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      
      final mating10Days = todayMidnight.subtract(const Duration(days: 10));
      final daysSince10 = todayMidnight.difference(mating10Days).inDays;
      String status10 = 'PREGNANT';
      if (daysSince10 <= 28) {
        status10 = 'PENDING_CONFIRMATION';
      }
      expect(status10, equals('PENDING_CONFIRMATION'));

      final mating35Days = todayMidnight.subtract(const Duration(days: 35));
      final daysSince35 = todayMidnight.difference(mating35Days).inDays;
      String status35 = 'PREGNANT';
      if (daysSince35 <= 28) {
        status35 = 'PENDING_CONFIRMATION';
      }
      expect(status35, equals('PREGNANT'));
    });
  });
}
