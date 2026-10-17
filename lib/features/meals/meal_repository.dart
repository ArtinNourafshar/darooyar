import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/meals/meal.dart';

/// دسترسی داده‌ای برنامهٔ غذایی.
class MealRepository {
  const MealRepository();

  Database get _db => DatabaseService.instance.db;

  /// وعده‌های فعال برای نمایش/زمان‌بندی.
  Future<List<MealTime>> getAll({bool onlyEnabled = false}) async {
    final rows = await _db.query(
      'meal_times',
      where: onlyEnabled ? 'enabled = 1' : null,
      orderBy: 'time ASC, id ASC',
    );
    return rows.map(MealTime.fromMap).toList(growable: false);
  }

  /// درج اولین وعده‌های پیش‌فرض (فقط یک بار و فقط اگر جدول خالی باشد).
  Future<void> ensureDefaults() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM meal_times'),
    );
    if (count != null && count > 0) return;

    final today = PersianUtils.dateKey(DateTime.now());
    for (final (name, time) in [
      ('صبحانه', '08:00'),
      ('ناهار', '13:00'),
      ('شام', '19:30'),
    ]) {
      await _db.insert('meal_times', {
        'name': name,
        'time': time,
        'enabled': 1,
        'created_at': today,
        'created_time': '00:00',
      });
    }
  }

  Future<MealTime> insert(MealTime meal) async {
    final id = await _db.insert('meal_times', meal.toMap());
    return meal.copyWith(id: id);
  }

  Future<void> update(MealTime meal) async {
    await _db.update(
      'meal_times',
      meal.toMap(),
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('meal_times', where: 'id = ?', whereArgs: [id]);
  }

  /// ثبت وضعیت یک وعده در یک روز (upsert).
  Future<void> confirm({
    required int mealTimeId,
    required String dateKey,
    required String status,
    required String confirmedAt,
  }) async {
    await _db.insert(
      'meal_logs',
      {
        'meal_time_id': mealTimeId,
        'log_date': dateKey,
        'status': status,
        'confirmed_at': confirmedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// حذف ثبت یک وعده (بازگشت به «بدون تأیید»).
  Future<void> clear({required int mealTimeId, required String dateKey}) async {
    await _db.delete(
      'meal_logs',
      where: 'meal_time_id = ? AND log_date = ?',
      whereArgs: [mealTimeId, dateKey],
    );
  }

  /// همهٔ ثبت‌های یک روز، کلیدشان شناسهٔ وعده.
  Future<Map<int, MealLog>> logsForDate(String dateKey) async {
    final rows = await _db.query(
      'meal_logs',
      where: 'log_date = ?',
      whereArgs: [dateKey],
    );
    return {
      for (final row in rows)
        (row['meal_time_id'] as int): MealLog.fromMap(row),
    };
  }

  /// همهٔ ثبت‌های یک بازه (برای گزارش/فعالیت).
  Future<List<MealLog>> range(String fromKey, String toKey) async {
    final rows = await _db.query(
      'meal_logs',
      where: 'log_date >= ? AND log_date <= ?',
      whereArgs: [fromKey, toKey],
      orderBy: 'log_date ASC, confirmed_at ASC',
    );
    return rows.map(MealLog.fromMap).toList(growable: false);
  }
}
