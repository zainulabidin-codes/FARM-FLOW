// ---------------------------------------------------------------------------
// Dodi Ledger — presentation layer model re-export
// ---------------------------------------------------------------------------
// The original UI-only DodiModel has been superseded by the data-layer
// DodiModel in lib/features/dodi_ledger/data/models/dodi_model.dart.
//
// This file re-exports the data model under the same name so that
// DodiLedgerScreen and DodiCard continue to compile without any import
// changes — they just start using the real domain model transparently.
// ---------------------------------------------------------------------------

export '../data/models/dodi_model.dart';
