import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';
import 'package:dairy_farm_app/features/dashboard/data/models/activity_log_model.dart';
import 'package:dairy_farm_app/features/dashboard/data/repositories/activity_log_repository.dart';

class MockActivityLogRepository implements ActivityLogRepository {
  final List<ActivityLogModel> loggedActivities = [];

  @override
  Future<void> logActivity(ActivityLogModel activity) async {
    loggedActivities.insert(0, activity);
  }

  @override
  Future<List<ActivityLogModel>> getActivities(int userId) async {
    return loggedActivities.where((a) => a.userId == userId).toList();
  }
}

void main() {
  group('Sprint 1 - ActivityLogProvider Data Sanitization Tests', () {
    late MockActivityLogRepository repository;
    late ActivityLogProvider provider;

    setUp(() {
      repository = MockActivityLogRepository();
      provider = ActivityLogProvider(repository: repository);
    });

    test('logCowMilkRecorded with null cowName does NOT produce literal "null" in subtitle', () async {
      await provider.logCowMilkRecorded(
        userId: 1,
        tagNumber: '101',
        cowName: null,
        totalKg: 14.5,
        sessionStr: 'Morning',
        date: '2026-09-12',
      );

      expect(provider.activities.length, 1);
      final activity = provider.activities.first;
      expect(activity.subtitle.contains('null'), isFalse);
      expect(activity.subtitle, 'Added entry for Cow #101');
      expect(activity.metadata?['name'], isNull);
      expect(activity.metadata?['tag'], '101');
    });

    test('logCowMilkRecorded with empty/whitespace cowName falls back cleanly', () async {
      await provider.logCowMilkRecorded(
        userId: 1,
        tagNumber: '102',
        cowName: '   ',
        totalKg: 10.0,
        sessionStr: 'Evening',
        date: '2026-09-12',
      );

      final activity = provider.activities.first;
      expect(activity.subtitle.contains('null'), isFalse);
      expect(activity.subtitle, 'Added entry for Cow #102');
    });

    test('logCowMilkRecorded with valid cowName formats title and metadata correctly', () async {
      await provider.logCowMilkRecorded(
        userId: 1,
        tagNumber: '103',
        cowName: 'Gauri',
        totalKg: 12.0,
        sessionStr: 'Morning',
        date: '2026-09-12',
      );

      final activity = provider.activities.first;
      expect(activity.subtitle, 'Added entry for Cow: Gauri (#103)');
      expect(activity.metadata?['name'], 'Gauri');
      expect(activity.metadata?['tag'], '103');
    });
  });
}
