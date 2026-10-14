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

  bool get isOpen => _db != null;

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
          version: 1,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
        ),
      );
    } else {
      final support = await getApplicationSupportDirectory();
      _db = await openDatabase(
        p.join(support.path, 'darooyar.db'),
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
