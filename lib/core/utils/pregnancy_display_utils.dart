/// Utility functions for computing pregnancy progress display values.
///
/// Extracted from _PregnancyDetailsState.build so the math can be
/// unit-tested independently of Flutter widget infrastructure.
library;

/// Holds the decomposed pregnancy duration for display.
class PregnancyDisplayValues {
  /// The 1-indexed current pregnancy month (ordinal).
  /// Month 1 = days 0–30, Month 2 = days 31–60, …
  /// Used for the progress bar badge ("Month X of 9").
  final int pregnancyMonth;

  /// Number of fully completed calendar months elapsed since mating.
  /// This is pregnancyMonth - 1, i.e., the cardinal elapsed count.
  /// Day 6 → 0, Day 35 → 1, Day 0 → 0.
  final int completedMonths;

  /// Days elapsed within the current (incomplete) month.
  /// Day 6 → 6, Day 35 → ~5, Day 0 → 0.
  final int remainingDays;

  const PregnancyDisplayValues({
    required this.pregnancyMonth,
    required this.completedMonths,
    required this.remainingDays,
  });
}

/// Computes pregnancy display values from [daysSinceMating] and an optional
/// cached [pregnancyMonthOrdinal] (the 1-indexed month, e.g. from
/// CowProvider.getPregnancyMonth or CowRepository.getCurrentPregnancyMonth).
///
/// If [pregnancyMonthOrdinal] is null, the ordinal is computed from
/// [daysSinceMating] using the same formula as the provider/repository:
///   ordinal = (daysSinceMating / 30.44).floor() + 1, clamped 1–9.
///
/// When [daysSinceMating] is 0 or null, returns all-zero values.
PregnancyDisplayValues computePregnancyDisplay({
  required int daysSinceMating,
  int? pregnancyMonthOrdinal,
}) {
  if (daysSinceMating <= 0) {
    return const PregnancyDisplayValues(
      pregnancyMonth: 0,
      completedMonths: 0,
      remainingDays: 0,
    );
  }

  final int ordinal = pregnancyMonthOrdinal ??
      ((daysSinceMating / 30.44).floor() + 1).clamp(1, 9);

  final int completed = ordinal > 0 ? ordinal - 1 : 0;
  final int remaining =
      (daysSinceMating - (completed * 30.44)).round().clamp(0, 30);

  return PregnancyDisplayValues(
    pregnancyMonth: ordinal,
    completedMonths: completed,
    remainingDays: remaining,
  );
}
