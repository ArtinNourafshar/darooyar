import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/features/schedule/dose_log.dart';

/// دسترسی داده‌ای سابقهٔ مصرف.
class DoseRepository {
  const DoseRepository();

  Database get _db => DatabaseService.instance.db;

  /// همهٔ ثبت‌های یک روز خاص، کلیدشان «medicationId|logTime».
  Future<Map<String, DoseLog>> forDate(String dateKey) async {
    final rows = await _db.query(
      'dose_logs',
      where: 'log_date = ?',
      whereArgs: [dateKey],
    );
    return {
      for (final row in rows)
        '${row['medication_id']}|${row['log_time']}': DoseLog.fromMap(row),
    };
  }

  /// همهٔ ثبت‌های یک بازهٔ زمانی (برای گزارش).
  Future<List<DoseLog>> range(String fromKey, String toKey) async {
    final rows = await _db.query(
      'dose_logs',
      where: 'log_date >= ? AND log_date <= ?',
      whereArgs: [fromKey, toKey],
      orderBy: 'log_date ASC, log_time ASC',
    );
    return rows.map(DoseLog.fromMap).toList(growable: false);
  }

  /// ثبت وضعیت یک نوبت (جایگزین در صورت وجود قبلی).
  Future<void> upsert({
    required int medicationId,
    required String logDate,
    required String logTime,
    required String status,
    required String confirmedAt,
  }) async {
    await _db.insert(
      'dose_logs',
      {
        'medication_id': medicationId,
        'log_date': logDate,
        'log_time': logTime,
        'status': status,
        'confirmed_at': confirmedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// بازگرداندن نوبت به حالت «بدون تأیید».
  Future<void> clear({
    required int medicationId,
    required String logDate,
    required String logTime,
  }) async {
    await _db.delete(
      'dose_logs',
      where: 'medication_id = ? AND log_date = ? AND log_time = ?',
      whereArgs: [medicationId, logDate, logTime],
    );
  }
}
