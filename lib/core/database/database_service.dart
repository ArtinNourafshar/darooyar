import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// سرویس پایگاه‌دادهٔ محلی SQLite.
///
/// - اندروید: sqflite معمولی (پایگاه‌داده در مسیر پیش‌فرض سیستم)
/// - ویندوز: sqflite_common_ffi + sqlite3 همراهٔ برنامه
///
/// همهٔ داده‌ها کاملاً محلی‌اند؛ هیچ ارتباط شبکه‌ای وجود ندارد.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService.init() هنوز فراخوانی نشده است.');
    }
    return database;
  }

  /// باز کردن پایگاه‌داده (Idempotent).
  Future<void> init() async {
    if (_db != null) return;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final support = await getApplicationSupportDirectory();
      _db = await databaseFactory.openDatabase(
        p.join(support.path, 'darooyar.db'),
        options: OpenDatabaseOptions(
          version: _schemaVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } else {
      final support = await getApplicationSupportDirectory();
      _db = await openDatabase(
        p.join(support.path, 'darooyar.db'),
        version: _schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  /// نسخهٔ فعلی شمای پایگاه‌داده.
  ///
  /// - ۲: ستون `created_time` (ساعت دقیق ثبت دارو) اضافه شد تا نوبت‌های
  ///   همان روزِ ثبت که پیش از ثبت دارو بودند «مصرف نشده» حساب نشوند.
  /// - ۳: جدول‌های برنامهٔ غذایی (`meal_times`/`meal_logs`)، شاخص‌های سلامت
  ///   (`health_logs`)، تنظیمات کلید-مقدار (`settings`)، بینش‌های روزانهٔ
  ///   هوش مصنوعی (`ai_insights`) و قد فرد برای محاسبهٔ BMI.
  static const int _schemaVersion = 3;

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE medications ADD COLUMN created_time TEXT');
      // ردیف‌های قدیمی: نوبت‌های روز ثبت همگی پیش از ثبت فرض می‌شوند.
      await db.execute(
        "UPDATE medications SET created_time = '00:00' WHERE created_time IS NULL",
      );
    }
    if (from < 3) {
      await db.execute('ALTER TABLE profiles ADD COLUMN height_cm REAL');
      await _createVersion3Tables(db);
    }
  }

  /// جدول‌های نسخهٔ ۳ (مشترک بین نصب تازه و ارتقا).
  Future<void> _createVersion3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE meal_times (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        time TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_time_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        status TEXT NOT NULL,
        confirmed_at TEXT NOT NULL,
        UNIQUE (meal_time_id, log_date),
        FOREIGN KEY (meal_time_id) REFERENCES meal_times (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE health_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        metric TEXT NOT NULL,
        value1 REAL NOT NULL,
        value2 REAL,
        log_date TEXT NOT NULL,
        log_time TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_meal_logs_date ON meal_logs (log_date)',
    );
    await db.execute(
      'CREATE INDEX idx_health_logs_profile_date '
      'ON health_logs (profile_id, log_date)',
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        dose TEXT NOT NULL,
        times TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_time TEXT NOT NULL DEFAULT '00:00',
        FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE dose_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        log_time TEXT NOT NULL,
        status TEXT NOT NULL,
        confirmed_at TEXT NOT NULL,
        UNIQUE (medication_id, log_date, log_time),
        FOREIGN KEY (medication_id) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_medications_profile ON medications (profile_id)',
    );
    await db.execute(
      'CREATE INDEX idx_dose_logs_date ON dose_logs (log_date)',
    );

    // جدول‌های نسخهٔ ۳ (غذا/سلامت/تنظیمات/هوش مصنوعی).
    await _createVersion3Tables(db);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
