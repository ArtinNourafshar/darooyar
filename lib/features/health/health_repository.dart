import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/features/health/health_metric.dart';

/// دسترسی داده‌ای شاخص‌های سلامت.
class HealthRepository {
  const HealthRepository();

  Database get _db => DatabaseService.instance.db;

  Future<void> add(HealthLog log) async {
    await _db.insert('health_logs', log.toMap());
  }

  Future<void> delete(int id) async {
    await _db.delete('health_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// تاریخچهٔ یک شاخص برای یک فرد در بازه (مرتب از قدیم به جدید).
  Future<List<HealthLog>> history({
    required int profileId,
    required String metric,
    required String fromKey,
    required String toKey,
  }) async {
    final rows = await _db.query(
      'health_logs',
      where: 'profile_id = ? AND metric = ? AND log_date >= ? AND log_date <= ?',
      whereArgs: [profileId, metric, fromKey, toKey],
      orderBy: 'log_date ASC, log_time ASC',
    );
    return rows.map(HealthLog.fromMap).toList(growable: false);
  }

  /// همهٔ ثبت‌های یک فرد در بازه (برای خلاصهٔ AI و فعالیت‌ها).
  Future<List<HealthLog>> allInRange({
    required int profileId,
    required String fromKey,
    required String toKey,
  }) async {
    final rows = await _db.query(
      'health_logs',
      where: 'profile_id = ? AND log_date >= ? AND log_date <= ?',
      whereArgs: [profileId, fromKey, toKey],
      orderBy: 'log_date DESC, log_time DESC',
    );
    return rows.map(HealthLog.fromMap).toList(growable: false);
  }

  /// همهٔ ثبت‌های همهٔ افراد در بازه (برای لاگ فعالیت گزارش‌ها).
  Future<List<HealthLog>> allInRangeAllProfiles({
    required String fromKey,
    required String toKey,
  }) async {
    final rows = await _db.query(
      'health_logs',
      where: 'log_date >= ? AND log_date <= ?',
      whereArgs: [fromKey, toKey],
      orderBy: 'log_date DESC, log_time DESC',
    );
    return rows.map(HealthLog.fromMap).toList(growable: false);
  }

  /// آخرین مقدار هر شاخص برای یک فرد.
  Future<Map<String, HealthLog>> latestPerMetric(int profileId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT h.* FROM health_logs h
      JOIN (
        SELECT metric, MAX(log_date || ' ' || log_time) AS stamp
        FROM health_logs WHERE profile_id = ?
        GROUP BY metric
      ) last ON last.metric = h.metric
        AND (h.log_date || ' ' || h.log_time) = last.stamp
      WHERE h.profile_id = ?
      ''',
      [profileId, profileId],
    );
    return {
      for (final row in rows)
        (row['metric'] as String): HealthLog.fromMap(row),
    };
  }

  /// قد ذخیره‌شدهٔ فرد (برای BMI)؛ null یعنی هنوز ثبت نشده.
  Future<double?> heightOf(int profileId) async {
    final rows = await _db.query(
      'profiles',
      columns: ['height_cm'],
      where: 'id = ?',
      whereArgs: [profileId],
    );
    if (rows.isEmpty) return null;
    return (rows.first['height_cm'] as num?)?.toDouble();
  }

  Future<void> setHeight(int profileId, double heightCm) async {
    await _db.update(
      'profiles',
      {'height_cm': heightCm},
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }
}
