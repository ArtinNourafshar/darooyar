import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';

/// یک لیوان ثبت‌شدهٔ آب.
class WaterLog {
  const WaterLog({
    this.id,
    required this.logDate,
    required this.logTime,
  });

  final int? id;

  /// کلید تاریخ «yyyy-MM-dd».
  final String logDate;

  /// ساعت ثبت «HH:mm».
  final String logTime;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'log_date': logDate,
        'log_time': logTime,
      };

  factory WaterLog.fromMap(Map<String, Object?> map) => WaterLog(
        id: map['id'] as int?,
        logDate: map['log_date'] as String,
        logTime: map['log_time'] as String,
      );
}

/// دسترسی داده‌ای لیوان‌های آب.
class WaterRepository {
  const WaterRepository();

  Database get _db => DatabaseService.instance.db;

  Future<void> add(WaterLog log) async {
    await _db.insert('water_logs', log.toMap());
  }

  Future<void> delete(int id) async {
    await _db.delete('water_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// لیوان‌های یک روز (مرتب از قدیم به جدید).
  Future<List<WaterLog>> forDate(String dateKey) async {
    final rows = await _db.query(
      'water_logs',
      where: 'log_date = ?',
      whereArgs: [dateKey],
      orderBy: 'log_time ASC, id ASC',
    );
    return rows.map(WaterLog.fromMap).toList(growable: false);
  }

  /// شمارش لیوان‌های هر روز در یک بازه (برای نمودار).
  Future<Map<String, int>> countByDay(String fromKey, String toKey) async {
    final rows = await _db.rawQuery(
      'SELECT log_date, COUNT(*) AS c FROM water_logs '
      'WHERE log_date >= ? AND log_date <= ? GROUP BY log_date',
      [fromKey, toKey],
    );
    return {
      for (final row in rows)
        (row['log_date'] as String): (row['c'] as int? ?? 0),
    };
  }
}
