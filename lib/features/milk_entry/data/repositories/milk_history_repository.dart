import 'package:sqflite/sqflite.dart';
import '../datasources/milk_history_local_datasource.dart';
import '../models/milk_history_models.dart';

/// Repository for milk history aggregations and export datasets.
class MilkHistoryRepository {
  final MilkHistoryLocalDatasource _datasource;

  MilkHistoryRepository({MilkHistoryLocalDatasource? datasource, Database? db})
      : _datasource = datasource ?? MilkHistoryLocalDatasource(db: db);

  /// Returns user's earliest activity date using 3-tier fallback.
  Future<DateTime> getEarliestUserActivityDate(int userId) {
    return _datasource.getEarliestUserActivityDate(userId);
  }

  /// Returns aggregated milk sales overview and logs for a selected month.
  Future<MilkHistoryOverview> getMilkHistoryForMonth({
    required int userId,
    required DateTime month,
    int? daysToShow,
  }) {
    return _datasource.getMilkHistoryForMonth(
      userId: userId,
      month: month,
      daysToShow: daysToShow,
    );
  }

  /// Returns summary and daily breakdown for the requested date range.
  Future<({ExportMilkSummary summary, List<ExportMilkLog> logs})> getExportDataForRange({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _datasource.getExportDataForRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
