import '../../../../core/utils/money_utils.dart';

/// Aggregated financial summary for a single Dodi (milk-buyer).
///
/// All raw values are stored as INTEGER to honour the no-float rule.
/// The `...Kg` and `...Rupees` getters perform the divide-by-100 conversion
/// ONLY for UI display — they must never be persisted or used in calculations.
class DodiDashboardSummary {
  /// Total milk supplied by this dodi, in GRAMS (integer).
  final int totalMilkGrams;

  /// Total value of all milk supplied, in PAISE (integer, positive).
  final int grandTotalPaise;

  /// Total cash already received from the dodi, in PAISE (integer, positive).
  /// Derived from ABS(amount_paise) of PAYMENT_RECEIVED rows.
  final int amountTakenPaise;

  /// Net outstanding balance in PAISE (integer, signed).
  /// Positive → dodi still owes money.
  /// Negative → farmer has over-received (edge case, not expected normally).
  /// Derived from SUM(amount_paise) across ALL ledger types, respecting signs.
  final int amountDuePaise;

  const DodiDashboardSummary({
    required this.totalMilkGrams,
    required this.grandTotalPaise,
    required this.amountTakenPaise,
    required this.amountDuePaise,
  });

  // ── UI-only display getters ────────────────────────────────────────────────
  // These are the ONLY place division occurs. Never store or compare these.

  /// Total milk in kilograms — for display only.
  double get totalMilkKg => MoneyUtils.gramsToKg(totalMilkGrams);

  /// Grand total in rupees — for display only.
  double get grandTotalRupees => MoneyUtils.paiseToRupees(grandTotalPaise);

  /// Amount already received in rupees — for display only.
  double get amountTakenRupees => MoneyUtils.paiseToRupees(amountTakenPaise);

  /// Net amount still due in rupees — for display only.
  double get amountDueRupees => MoneyUtils.paiseToRupees(amountDuePaise);

  /// An empty summary — used as the initial state before the query completes.
  static const DodiDashboardSummary empty = DodiDashboardSummary(
    totalMilkGrams: 0,
    grandTotalPaise: 0,
    amountTakenPaise: 0,
    amountDuePaise: 0,
  );

  @override
  String toString() =>
      'DodiDashboardSummary('
      'totalMilkGrams: $totalMilkGrams, '
      'grandTotalPaise: $grandTotalPaise, '
      'amountTakenPaise: $amountTakenPaise, '
      'amountDuePaise: $amountDuePaise)';
}
