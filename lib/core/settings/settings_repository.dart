import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';

/// ذخیرهٔ تنظیمات کلید-مقدار در پایگاه‌دادهٔ محلی.
///
/// کلیدها:
/// - `ai_api_key` / `ai_model` — میراث نسخه‌های قبلی (بدون استفاده؛ کلید
///   هوش مصنوعی اکنون در `ai_config.dart` سازنده ثبت می‌شود)
/// - `ai_enabled` — «1» یعنی کاربر بخش دستیار را فعال کرده (opt-in)
/// - `ai_daily_check` — «1» یعنی بررسی روزانهٔ خودکار فعال است
/// - `ai_last_check_day` — آخرین روزِ اجرای بررسی روزانه (yyyy-MM-dd)
/// - `alarm_sound` — شمارهٔ صدای زنگ انتخابی (۱ تا ۳)
/// - `water_reminder_enabled` / `water_reminder_interval` / `water_target` —
///   یادآوری و هدف نوشیدن آب
class SettingsRepository {
  const SettingsRepository();

  Database get _db => DatabaseService.instance.db;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'settings',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['v'] as String;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(
      'settings',
      {'k': key, 'v': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {bool orElse = false}) async {
    final value = await get(key);
    if (value == null) return orElse;
    return value == '1';
  }

  Future<void> setBool(String key, bool value) =>
      set(key, value ? '1' : '0');

  Future<void> remove(String key) async {
    await _db.delete('settings', where: 'k = ?', whereArgs: [key]);
  }
}

/// کلیدهای شناخته‌شدهٔ تنظیمات.
abstract final class SettingKeys {
  static const String aiApiKey = 'ai_api_key'; // میراث نسخهٔ قبلی؛ بلااستفاده
  static const String aiModel = 'ai_model';
  static const String aiEnabled = 'ai_enabled';
  static const String aiDailyCheck = 'ai_daily_check';
  static const String aiLastCheckDay = 'ai_last_check_day';

  /// شمارهٔ صدای زنگ (۱ تا ۳).
  static const String alarmSound = 'alarm_sound';

  /// یادآوری نوشیدن آب.
  static const String waterReminderEnabled = 'water_reminder_enabled';
  static const String waterReminderInterval = 'water_reminder_interval';
  static const String waterTarget = 'water_target';
}
