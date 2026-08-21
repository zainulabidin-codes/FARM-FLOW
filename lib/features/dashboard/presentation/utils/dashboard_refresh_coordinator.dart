import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../milk_entry/presentation/providers/milk_entry_provider.dart';
import '../../../cows/presentation/providers/cow_provider.dart';
import '../providers/activity_log_provider.dart';

/// Centralized coordinator orchestrating all dashboard pull-to-refresh data fetching.
///
/// Serves as the single entry point for dashboard refresh behavior across providers.
class DashboardRefreshCoordinator {
  final BuildContext context;

  const DashboardRefreshCoordinator(this.context);

  /// Triggers parallel data re-fetching across all dashboard data sources.
  Future<void> refreshAll(int userId) async {
    final milkProvider = Provider.of<MilkEntryProvider>(context, listen: false);
    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    final activityProvider = Provider.of<ActivityLogProvider>(context, listen: false);

    await Future.wait([
      milkProvider.fetchTodaysTotalMilk(),
      cowProvider.loadCows(userId),
      activityProvider.loadActivities(userId),
    ]);
  }
}
