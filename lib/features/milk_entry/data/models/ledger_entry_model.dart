/// Discriminated union of ledger entry types.
///
/// Sign convention for [LedgerEntryModel.amountPaise]:
///   • [milkSold]          → POSITIVE  (money owed TO the farmer)
///   • [paymentReceived]   → NEGATIVE  (farmer received cash; reduces balance)
///   • [advanceTaken]      → NEGATIVE  (dodi took an advance; reduces balance)
enum LedgerEntryType {
  milkSold,
  paymentReceived,
  advanceTaken;

  /// Converts to the exact string stored in the database `type` column.
  String get dbValue {
    switch (this) {
      case LedgerEntryType.milkSold:
        return 'MILK_SOLD';
      case LedgerEntryType.paymentReceived:
        return 'PAYMENT_RECEIVED';
      case LedgerEntryType.advanceTaken:
        return 'ADVANCE_TAKEN';
    }
  }

  /// Parses the `type` column string back into the enum.
  ///
  /// Throws [ArgumentError] on an unrecognised value — this signals a data
  /// integrity problem that should never be silently swallowed.
  static LedgerEntryType fromDbValue(String value) {
    switch (value) {
      case 'MILK_SOLD':
        return LedgerEntryType.milkSold;
      case 'PAYMENT_RECEIVED':
        return LedgerEntryType.paymentReceived;
      case 'ADVANCE_TAKEN':
        return LedgerEntryType.advanceTaken;
      default:
        throw ArgumentError('Unknown LedgerEntryType db value: "$value"');
    }
  }
}

/// Data model for the `ledger` table.
///
/// ALL numeric quantities are integers — no floats anywhere:
///   • [quantityGrams]  — milk volume in grams
///   • [ratePaise]      — per-litre price in paise
///   • [amountPaise]    — transaction value in paise (signed per type)
class LedgerEntryModel {
  final int? id;

  /// FK → dodis.id
  final int dodiId;

  final LedgerEntryType type;

  /// ISO-8601 date string (e.g. "2026-07-09").
  final String date;

  /// Milking session, e.g. "MORNING" or "EVENING".  Null for financial entries.
  final String? session;

  /// Load tag / entry label (e.g. "Load 1", "Load 2", "Tanker A").
  final String? loadTag;

  /// Milk collected in GRAMS.  Null for financial entries.
  /// 30.5 kg → 30 500 g.
  final int? quantityGrams;

  /// Price per litre in PAISE.  Null for financial entries.
  /// ₹5.50 → 550 paise.
  final int? ratePaise;

  /// Signed transaction value in PAISE.
  /// Positive for MILK_SOLD, negative for PAYMENT_RECEIVED / ADVANCE_TAKEN.
  final int amountPaise;

  const LedgerEntryModel({
    this.id,
    required this.dodiId,
    required this.type,
    required this.date,
    this.session,
    this.loadTag,
    this.quantityGrams,
    this.ratePaise,
    required this.amountPaise,
  });

  // ── Persistence helpers ────────────────────────────────────────────────

  factory LedgerEntryModel.fromMap(Map<String, dynamic> map) {
    return LedgerEntryModel(
      id: map['id'] as int?,
      dodiId: map['dodi_id'] as int,
      type: LedgerEntryType.fromDbValue(map['type'] as String),
      date: map['date'] as String,
      session: map['session'] as String?,
      loadTag: map['load_tag'] as String?,
      quantityGrams: map['quantity_grams'] as int?,
      ratePaise: map['rate_paise'] as int?,
      amountPaise: map['amount_paise'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'dodi_id': dodiId,
      'type': type.dbValue,
      'date': date,
      'session': session,
      if (loadTag != null) 'load_tag': loadTag,
      'quantity_grams': quantityGrams,
      'rate_paise': ratePaise,
      'amount_paise': amountPaise,
    };
  }

  @override
  String toString() =>
      'LedgerEntryModel(id: $id, type: ${type.dbValue}, '
      'loadTag: $loadTag, amountPaise: $amountPaise)';
}
