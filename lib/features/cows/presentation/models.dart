// ---------------------------------------------------------------------------
// Cows Feature — UI-layer models
// ---------------------------------------------------------------------------
// Pure data-carrier classes consumed by the cows screen and its widgets.
// No database logic, no ORM mapping.
// ---------------------------------------------------------------------------

/// Status of a cow in the herd.
enum CowStatus {
  milking,
  pregnant,
  dry,
  heifer,
  bredHeifer,
}

extension CowStatusLabel on CowStatus {
  String get label => switch (this) {
        CowStatus.milking => 'Milking',
        CowStatus.pregnant => 'Pregnant',
        CowStatus.dry => 'Dry',
        CowStatus.heifer => 'Heifer',
        CowStatus.bredHeifer => 'Bred Heifer',
      };
}

/// Represents a single cow shown in the herd tracker screen.
class CowModel {
  /// Unique identifier — used in tap / navigation callbacks.
  final String id;

  /// Display label, e.g. "Cow #402 - 'Laxmi'".
  final String name;

  /// Current health/production status.
  final CowStatus status;

  // ── Milking-specific fields ──────────────────────────────────────────────

  /// Daily yield string, e.g. "14L/day". Null if not milking.
  final String? yieldPerDay;

  /// Lactation number, e.g. 3. Null if not milking.
  final int? lactationNumber;

  /// Health score between 0.0 (critical) and 1.0 (optimal).
  /// Used to draw the health progress bar for milking cows.
  final double? healthScore;

  // ── Pregnancy-specific fields ────────────────────────────────────────────
  
  final String? peakMorningYield;
  final String? peakEveningYield;
  final String? lowestMorningYield;
  final String? lowestEveningYield;

  /// Month of pregnancy (1–9). Null if not pregnant.
  final int? pregnancyMonth;

  /// Bull semen used, e.g. "Gir-Alpha". Null if not pregnant.
  final String? bullName;

  /// AI (Artificial Insemination) date string, e.g. "Aug 15".
  /// Null if not pregnant.
  final String? aiDate;

  /// Number of days since mating.
  /// Null if not pregnant or no mating date recorded.
  final int? daysSinceMating;

  final String tagNumber;

  /// True if the cow has at least one recorded milking season.
  final bool hasLactated;

  /// The estimated birth date ISO-8601 string used for age calculation.
  final String? estimatedBirthDate;

  /// The advancing age string calculated from estimatedBirthDate.
  final String? displayAge;

  const CowModel({
    required this.id,
    required this.tagNumber,
    required this.name,
    required this.status,
    this.hasLactated = false,
    // milking
    this.yieldPerDay,
    this.lactationNumber,
    this.healthScore,
    this.peakMorningYield,
    this.peakEveningYield,
    this.lowestMorningYield,
    this.lowestEveningYield,
    // pregnancy
    this.pregnancyMonth,
    this.bullName,
    this.aiDate,
    this.daysSinceMating,
    // age
    this.estimatedBirthDate,
    this.displayAge,
  });

  /// Convenience: pregnancy progress as a 0.0–1.0 fraction.
  double get pregnancyFraction =>
      daysSinceMating != null ? (daysSinceMating! / 283.0).clamp(0.0, 1.0) : 0.0;

  /// True when the cow is in day 211+ and needs to start dry period.
  bool get needsSpecialCare =>
      daysSinceMating != null && daysSinceMating! >= 211;

  /// True when the cow is in the overdue grace period.
  bool get isOverdue =>
      daysSinceMating != null && daysSinceMating! > 282 && daysSinceMating! <= 295;

  /// True when the pregnancy data appears to be invalid or unrecorded.
  bool get isInvalidPregnancy =>
      daysSinceMating != null && daysSinceMating! > 295;

  /// True when the cow is due any day now.
  bool get isDueSoon =>
      daysSinceMating != null && daysSinceMating! >= 261 && daysSinceMating! <= 282;

  /// A short farmer-friendly tag for the current stage of pregnancy.
  String get pregnancyStageTag {
    if (daysSinceMating == null) return "Unknown Stage";
    final days = daysSinceMating!;
    if (isInvalidPregnancy) return "Data Error";
    if (isOverdue) return "Overdue";
    if (days <= 90) return "Early Stage";
    if (days <= 180) return "Mid Stage";
    if (days <= 210) return "Late Stage";
    if (days <= 260) return "Start Dry Period";
    return "Due Soon";
  }

  /// A full sentence farmer-friendly message explaining the current stage.
  String get pregnancyStageMessage {
    if (daysSinceMating == null) return "Mating date not recorded. Please update cow details.";
    final days = daysSinceMating!;
    if (isInvalidPregnancy) return "This pregnancy date looks incorrect - please review or update this cow's record.";
    if (isOverdue) return "Due now / overdue - check on her.";
    if (days <= 30) return "Just confirmed - early days, keep her calm and stress-free.";
    if (days <= 90) return "Calf is forming - main body parts developing.";
    if (days <= 180) return "Calf growing steadily - safest phase of pregnancy.";
    if (days <= 210) return "Calf growing fast - still milking, keep an eye on feed.";
    if (days <= 260) return "Time to stop milking - cow needs rest before calving.";
    return "Due any day now - watch for signs of labor.";
  }
}
