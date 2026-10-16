import 'package:flutter/foundation.dart';

/// Represents a single dispatch entry in the Milk History screen.
@immutable
class MilkHistoryLog {
  final String buyerName;
  final DateTime date;
  final double totalCollected;
  final double rate;
  final double morningQty;
  final double eveningQty;
  final double? totalAmount;
  final String? morningFat;
  final String? eveningFat;

  const MilkHistoryLog({
    required this.buyerName,
    required this.date,
    required this.totalCollected,
    required this.rate,
    required this.morningQty,
    required this.eveningQty,
    this.totalAmount,
    this.morningFat,
    this.eveningFat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilkHistoryLog &&
          runtimeType == other.runtimeType &&
          buyerName == other.buyerName &&
          date == other.date &&
          totalCollected == other.totalCollected &&
          rate == other.rate &&
          morningQty == other.morningQty &&
          eveningQty == other.eveningQty &&
          totalAmount == other.totalAmount;

  @override
  int get hashCode => Object.hash(
        buyerName,
        date,
        totalCollected,
        rate,
        morningQty,
        eveningQty,
        totalAmount,
      );
}

/// Aggregated summary for the Milk History screen.
@immutable
class MilkHistoryOverview {
  final double totalQuantity;
  final double avgQuantityPerDay;
  final double grossRevenue;
  final double avgRevenuePerKg;
  final DateTime earliestActivityDate;
  final bool isPreAccount;
  final List<MilkHistoryLog> logs;

  const MilkHistoryOverview({
    this.totalQuantity = 0.0,
    this.avgQuantityPerDay = 0.0,
    this.grossRevenue = 0.0,
    this.avgRevenuePerKg = 0.0,
    required this.earliestActivityDate,
    this.isPreAccount = false,
    this.logs = const [],
  });

  static MilkHistoryOverview empty({required DateTime earliestActivityDate}) {
    return MilkHistoryOverview(
      earliestActivityDate: earliestActivityDate,
      isPreAccount: false,
      logs: const [],
    );
  }
}

/// Aggregated totals for the Export Milk History screen.
@immutable
class ExportMilkSummary {
  final double totalQuantity;
  final double morningQuantity;
  final double eveningQuantity;
  final double dailyAvg;

  const ExportMilkSummary({
    this.totalQuantity = 0.0,
    this.morningQuantity = 0.0,
    this.eveningQuantity = 0.0,
    this.dailyAvg = 0.0,
  });

  static const ExportMilkSummary empty = ExportMilkSummary();
}

/// Daily breakdown entry for export documents and screen.
@immutable
class ExportMilkLog {
  final DateTime date;
  final double totalQty;
  final double morningQty;
  final double eveningQty;

  const ExportMilkLog({
    required this.date,
    required this.totalQty,
    required this.morningQty,
    required this.eveningQty,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportMilkLog &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          totalQty == other.totalQty &&
          morningQty == other.morningQty &&
          eveningQty == other.eveningQty;

  @override
  int get hashCode => Object.hash(date, totalQty, morningQty, eveningQty);
}
