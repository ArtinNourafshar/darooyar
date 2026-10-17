import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';

/// ذخیرهٔ تنظیمات کلید-مقدار در پایگاه‌دادهٔ محلی.
///
/// کلیدها:
/// - `ai_api_key` — کلید Gemini کاربر (فقط محلی، هرگز بدون اجازه ارسال نمی‌شود)
/// - `ai_model` — شناسهٔ مدل
/// - `ai_enabled` — «1» یعنی کاربر بخش AI را فعال کرده (opt-in)
/// - `ai_daily_check` — «1» یعنی بررسی روزانهٔ خودکار فعال است
/// - `ai_last_check_day` — آخرین روزِ اجرای بررسی روزانه (yyyy-MM-dd)
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
  static const String aiApiKey = 'ai_api_key';
  static const String aiModel = 'ai_model';
  static const String aiEnabled = 'ai_enabled';
  static const String aiDailyCheck = 'ai_daily_check';
  static const String aiLastCheckDay = 'ai_last_check_day';
}
