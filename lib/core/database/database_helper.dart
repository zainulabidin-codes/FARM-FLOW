import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Singleton wrapper around the SQLite database.
///
/// Supports three engine modes:
///   • Web (Chrome/Edge)          → sqflite_common_ffi_web  (IndexedDB)
///   • Desktop (Windows/Linux/macOS) → sqflite_common_ffi   (native SQLite)
///   • Mobile (Android/iOS)        → standard sqflite plugin
class DatabaseHelper {
  DatabaseHelper._internal();

  /// The single shared instance.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _databaseName = 'dairy_farm.db';
  static const int _databaseVersion = 12;

  Database? _database;

  // ── Platform bootstrap ────────────────────────────────────────────────────

  /// Call once from [main] before any DB access.
  ///
  /// On web, switches to the WASM/IndexedDB engine.
  /// On desktop, switches to the native FFI engine.
  /// On mobile, the default sqflite plugin is already correct — no-op.
  static void initForPlatform() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android / iOS: sqflite default — nothing to do.
  }

  // ── Database access ───────────────────────────────────────────────────────

  /// Returns the open [Database], initialising it on first access.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // On web, getDatabasesPath() returns '/' — sqflite_ffi_web handles this.
    final databasesPath = await getDatabasesPath();
    final path = kIsWeb ? _databaseName : join(databasesPath, _databaseName);

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _ensureDefensiveColumns(db);
    return db;
  }

  /// Guarantees critical columns exist regardless of upgrade path history.
  Future<void> _ensureDefensiveColumns(Database db) async {
    try {
      final dodisColumns = await db.rawQuery("PRAGMA table_info(dodis)");
      final hasIsDeleted = dodisColumns.any((col) => col['name'] == 'is_deleted');
      if (!hasIsDeleted) {
        await db.execute('ALTER TABLE dodis ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      }
    } catch (e) {
      debugPrint('Defensive column check on dodis: $e');
    }

    try {
      final ledgerColumns = await db.rawQuery("PRAGMA table_info(ledger)");
      final hasLoadTag = ledgerColumns.any((col) => col['name'] == 'load_tag');
      if (!hasLoadTag) {
        await db.execute('ALTER TABLE ledger ADD COLUMN load_tag TEXT');
      }
    } catch (e) {
      debugPrint('Defensive column check on ledger: $e');
    }
  }

  // ── Schema ────────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE activity_log (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id        INTEGER NOT NULL,
          title          TEXT    NOT NULL,
          subtitle       TEXT    NOT NULL,
          value          TEXT    NOT NULL,
          time_unix      INTEGER NOT NULL,
          icon_code      INTEGER NOT NULL,
          is_positive    INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE cows ADD COLUMN is_deleted INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE cows ADD COLUMN deleted_reason TEXT');
      await db.execute('ALTER TABLE cows ADD COLUMN deleted_date TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE milking_seasons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cow_id INTEGER NOT NULL,
          season_start_date TEXT NOT NULL,
          season_end_date TEXT,
          season_highest_grams INTEGER,
          season_highest_date TEXT,
          season_highest_session TEXT,
          season_lowest_grams INTEGER,
          season_lowest_date TEXT,
          season_lowest_session TEXT,
          FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE cow_milk_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cow_id INTEGER NOT NULL,
          season_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          session TEXT NOT NULL,
          quantity_grams INTEGER NOT NULL,
          FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE,
          FOREIGN KEY (season_id) REFERENCES milking_seasons(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE cow_milk_monthly_summary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cow_id INTEGER NOT NULL,
          season_id INTEGER NOT NULL,
          year_month TEXT NOT NULL,
          highest_grams INTEGER NOT NULL,
          highest_date TEXT NOT NULL,
          highest_session TEXT NOT NULL,
          lowest_grams INTEGER NOT NULL,
          lowest_date TEXT NOT NULL,
          lowest_session TEXT NOT NULL,
          FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE,
          FOREIGN KEY (season_id) REFERENCES milking_seasons(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE cows ADD COLUMN is_deleted INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE cows ADD COLUMN deleted_reason TEXT');
        await db.execute('ALTER TABLE cows ADD COLUMN deleted_date TEXT');
      } catch (_) {
        // Ignore if already exists
      }
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE activity_log ADD COLUMN metadata TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE cows ADD COLUMN has_lactated_before INTEGER DEFAULT 0');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE cows ADD COLUMN estimated_birth_date TEXT');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE cow_milk_monthly_summary ADD COLUMN rolled_up_at TEXT');
    }
    if (oldVersion < 10) {
      // ── Indexes on all foreign-key columns ──────────────────────────────────
      // These were missing from the original schema. Without them, every
      // JOIN and WHERE on these columns triggers a full table scan, which
      // is the primary cause of the 1-3 second DB open penalty on low-end
      // devices with large tables.
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_dodi_id ON ledger(dodi_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_sessions_cow_id ON cow_milk_sessions(cow_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_sessions_season_id ON cow_milk_sessions(season_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON activity_log(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_dodis_user_id ON dodis(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cows_user_id ON cows(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_seasons_cow_id ON milking_seasons(cow_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_monthly_summary_cow_id ON cow_milk_monthly_summary(cow_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_monthly_summary_season_id ON cow_milk_monthly_summary(season_id)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_cows_active_tag ON cows(user_id, LOWER(tag_number)) WHERE is_deleted = 0');
      await db.execute("UPDATE cows SET status = 'BRED_HEIFER' WHERE status = 'BRED HEIFER' OR status = 'BRED_HEIFER_DRY'");
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE dodis ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE ledger ADD COLUMN load_tag TEXT');
    }
  }

  /// Creates all tables on first run.
  ///
  /// IMPORTANT — integer-only storage rules:
  ///   • Milk quantities  → INTEGER grams  (30.5 kg = 30 500 g)
  ///   • Money amounts    → INTEGER paise   (₹50.00  = 5 000 paise)
  /// No REAL / FLOAT columns are used anywhere.
  Future<void> _onCreate(Database db, int version) async {
    // ── Users ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT    UNIQUE NOT NULL,
        password_hash TEXT    NOT NULL,
        farm_name     TEXT,
        farmer_name   TEXT
      )
    ''');

    // ── Milking Tables ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE milking_seasons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cow_id INTEGER NOT NULL,
        season_start_date TEXT NOT NULL,
        season_end_date TEXT,
        season_highest_grams INTEGER,
        season_highest_date TEXT,
        season_highest_session TEXT,
        season_lowest_grams INTEGER,
        season_lowest_date TEXT,
        season_lowest_session TEXT,
        FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cow_milk_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cow_id INTEGER NOT NULL,
        season_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        quantity_grams INTEGER NOT NULL,
        FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE,
        FOREIGN KEY (season_id) REFERENCES milking_seasons(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cow_milk_monthly_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cow_id INTEGER NOT NULL,
        season_id INTEGER NOT NULL,
        year_month TEXT NOT NULL,
        highest_grams INTEGER NOT NULL,
        highest_date TEXT NOT NULL,
        highest_session TEXT NOT NULL,
        lowest_grams INTEGER NOT NULL,
        lowest_date TEXT NOT NULL,
        lowest_session TEXT NOT NULL,
        rolled_up_at TEXT,
        FOREIGN KEY (cow_id) REFERENCES cows(id) ON DELETE CASCADE,
        FOREIGN KEY (season_id) REFERENCES milking_seasons(id) ON DELETE CASCADE
      )
    ''');

    // ── Dodis (milk-buyers / customers) ────────────────────────────────────
    await db.execute('''
      CREATE TABLE dodis (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id            INTEGER NOT NULL,
        name               TEXT    NOT NULL,
        phone              TEXT,
        default_rate_paise INTEGER NOT NULL,
        is_deleted         INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // ── Cows ───────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE cows (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        tag_number    TEXT    NOT NULL,
        name          TEXT,
        status        TEXT    DEFAULT 'MILKING',
        mating_date   TEXT,
        delivery_date TEXT,
        is_deleted    INTEGER DEFAULT 0,
        deleted_reason TEXT,
        deleted_date  TEXT,
        has_lactated_before INTEGER DEFAULT 0,
        estimated_birth_date TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // ── Ledger ─────────────────────────────────────────────────────────────
    // amount_paise sign convention:
    //   MILK_SOLD        → POSITIVE  (+paise)
    //   PAYMENT_RECEIVED → NEGATIVE  (-paise)
    //   ADVANCE_TAKEN    → NEGATIVE  (-paise)
    await db.execute('''
      CREATE TABLE ledger (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        dodi_id        INTEGER NOT NULL,
        type           TEXT    NOT NULL,
        date           TEXT    NOT NULL,
        session        TEXT,
        load_tag       TEXT,
        quantity_grams INTEGER,
        rate_paise     INTEGER,
        amount_paise   INTEGER NOT NULL,
        FOREIGN KEY (dodi_id) REFERENCES dodis(id)
      )
    ''');

    // ── Activity Log ───────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE activity_log (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        INTEGER NOT NULL,
        title          TEXT    NOT NULL,
        subtitle       TEXT    NOT NULL,
        value          TEXT    NOT NULL,
        time_unix      INTEGER NOT NULL,
        icon_code      INTEGER NOT NULL,
        is_positive    INTEGER NOT NULL,
        metadata       TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // ── Indexes on all foreign-key columns (fresh installs) ───────────────
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_dodi_id ON ledger(dodi_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_sessions_cow_id ON cow_milk_sessions(cow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_sessions_season_id ON cow_milk_sessions(season_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON activity_log(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dodis_user_id ON dodis(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cows_user_id ON cows(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_seasons_cow_id ON milking_seasons(cow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_monthly_summary_cow_id ON cow_milk_monthly_summary(cow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cow_milk_monthly_summary_season_id ON cow_milk_monthly_summary(season_id)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_cows_active_tag ON cows(user_id, LOWER(tag_number)) WHERE is_deleted = 0');
  }
}
