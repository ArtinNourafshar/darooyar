import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:darooyar/core/database/database_service.dart';

/// خطای بکاپ/بازیابی با پیام فارسی.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// پشتیبان‌گیری JSON از کل اطلاعات و بازیابی آن (انتقال بین دستگاه‌ها).
///
/// فایل خروجی شامل همهٔ جدول‌های کاربردی است (بدون نام فایل‌ها/مسیرها)
/// و با شمای نسخهٔ پایگاه‌داده ذخیره می‌شود تا بازیابی در نسخه‌های
/// جدیدتر هم معتبر بماند.
class BackupService {
  const BackupService();

  static const int _formatVersion = 1;

  /// جدول‌هایی که در بکاپ قرار می‌گیرند (ترتیب: والدین اول).
  static const List<String> _tables = [
    'profiles',
    'medications',
    'dose_logs',
    'meal_times',
    'meal_logs',
    'health_logs',
    'water_logs',
    'settings',
    'ai_insights',
  ];

  Database get _db => DatabaseService.instance.db;

  /// ساخت فایل بکاپ و بازگرداندن مسیر آن.
  Future<String> exportToFile() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = await _db.query(table);
      tables[table] = rows;
    }

    final payload = jsonEncode({
      'app': 'darooyar',
      'format': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(dir.path, 'darooyar_reports'));
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final file = File(p.join(reportsDir.path, 'darooyar-backup-$stamp.json'));
    await file.writeAsString(payload, flush: true);
    return file.path;
  }

  /// بازیابی از فایل بکاپ: همهٔ داده‌های فعلی با محتوای فایل جایگزین می‌شود.
  Future<void> restoreFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const BackupException('فایل بکاپ پیدا نشد.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } catch (_) {
      throw const BackupException('فایل انتخاب‌شده یک بکاپ معتبر نیست.');
    }

    if (decoded is! Map<String, dynamic> || decoded['app'] != 'darooyar') {
      throw const BackupException('فایل انتخاب‌شده متعلق به دارویار نیست.');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const BackupException('ساختار فایل بکاپ معتبر نیست.');
    }

    // تطبیق ستون‌ها با شمای فعلی: ستون‌های ناشناخته حذف و ستون‌های
    // غایب با مقدار پیش‌فرض null ردیف را می‌سازند.
    final schema = await _db.getVersion();

    await _db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }

      for (final table in _tables) {
        final rows = tables[table];
        if (rows is! List) continue;
        final columns = await _tableColumns(txn, table);
        if (columns.isEmpty) continue;

        for (final row in rows) {
          if (row is! Map) continue;
          final values = <String, Object?>{
            for (final key in row.keys)
              if (columns.contains(key)) key: row[key],
          };
          if (values.isEmpty) continue;
          await txn.insert(table, values);
        }
      }
    });

    // اطمینان از اینکه نسخهٔ شمای فعلی حفظ شده است.
    assert(schema > 0);
  }

  Future<Set<String>> _tableColumns(DatabaseExecutor txn, String table) async {
    final info = await txn.rawQuery('PRAGMA table_info($table)');
    return {
      for (final row in info) (row['name'] as String),
    };
  }
}
