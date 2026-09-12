import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/core/utils/activity_display_formatter.dart';

void main() {
  group('Sprint 2 - ActivityDisplayFormatter Tests', () {
    test('Unnamed cow displays clean "Cow #101" instead of null or duplicate tags', () {
      final topRight = ActivityDisplayFormatter.getTopRightText(
        title: 'New Cow Added',
        subtitle: 'Tag: 101',
        value: 'MILKING',
        metadata: {'name': null, 'tag': '101'},
      );
      final leftDetails = ActivityDisplayFormatter.getLeftDetails(
        title: 'New Cow Added',
        subtitle: 'Tag: 101',
        value: 'MILKING',
        metadata: {'name': null, 'tag': '101'},
      );

      expect(topRight, 'MILKING');
      expect(leftDetails, ['Cow #101']);
      expect(leftDetails.first.contains('null'), isFalse);
      expect(leftDetails.first.contains('(101)'), isFalse);
    });

    test('Named cow formats cleanly as "Gauri (#101)"', () {
      final leftDetails = ActivityDisplayFormatter.getLeftDetails(
        title: 'Cow Updated',
        subtitle: 'Gauri',
        value: 'PREGNANT',
        metadata: {'name': 'Gauri', 'tag': '101'},
      );

      expect(leftDetails, ['Gauri (#101)']);
    });

    test('Payment Received does NOT duplicate buyer name on top right', () {
      final topRight = ActivityDisplayFormatter.getTopRightText(
        title: 'Payment Received',
        subtitle: 'Ramesh',
        value: 'Rs 500',
        metadata: {'name': 'Ramesh'},
      );
      final leftDetails = ActivityDisplayFormatter.getLeftDetails(
        title: 'Payment Received',
        subtitle: 'Ramesh',
        value: 'Rs 500',
        metadata: {'name': 'Ramesh'},
      );

      expect(topRight, 'Rs 500');
      expect(leftDetails, ['Ramesh']);
    });

    test('Buyer Added shows Phone and Rate on left, Rate/Value on top right', () {
      final topRight = ActivityDisplayFormatter.getTopRightText(
        title: 'Buyer Added',
        subtitle: 'Suresh',
        value: 'Rate: Rs 60.00/Kg',
        metadata: {'phone': '9876543210'},
      );
      final leftDetails = ActivityDisplayFormatter.getLeftDetails(
        title: 'Buyer Added',
        subtitle: 'Suresh',
        value: 'Rate: Rs 60.00/Kg',
        metadata: {'phone': '9876543210'},
      );

      expect(topRight, 'Rate: Rs 60.00/Kg');
      expect(leftDetails, ['Phone: 9876543210', 'Suresh']);
    });

    test('Pregnancy Confirmed shows target status/method on top right and cow label on left', () {
      final topRight = ActivityDisplayFormatter.getTopRightText(
        title: 'Pregnancy Confirmed',
        subtitle: 'Tag: 105 — Confirmed by VET',
        value: 'PREGNANT (VET)',
        metadata: {'name': 'Lakshmi', 'tag': '105', 'method': 'VET'},
      );
      final leftDetails = ActivityDisplayFormatter.getLeftDetails(
        title: 'Pregnancy Confirmed',
        subtitle: 'Tag: 105 — Confirmed by VET',
        value: 'PREGNANT (VET)',
        metadata: {'name': 'Lakshmi', 'tag': '105', 'method': 'VET'},
      );

      expect(topRight, 'PREGNANT (VET)');
      expect(leftDetails, ['Lakshmi (#105)']);
    });
  });
}
