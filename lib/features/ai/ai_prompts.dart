import 'package:flutter/material.dart';

import 'package:darooyar/core/utils/persian_utils.dart';

/// سازندهٔ پرامپت‌های فارسی بخش هوش مصنوعی — توابع خالص و قابل تست.
///
/// فقط خلاصه‌های آماری (نه دادهٔ خامِ کامل) به مدل ارسال می‌شود و
/// همهٔ متن‌ها فارسی‌اند تا پاسخ مدل هم فارسی روان باشد.
abstract final class AiPrompts {
  /// افزودن زمینهٔ وضعیت کاربر به دستور سیستم (یک‌بار در هر درخواست،
  /// به‌جای تکرار خلاصه در متن هر پیام چت).
  static String withSnapshot(String system, String snapshot) {
    final context = snapshot.trim();
    if (context.isEmpty) return system;
    return '$system\n\n=== وضعیت ثبت‌شدهٔ کاربر امروز ===\n$context';
  }

  /// برچسب فارسی امروز برای پرامپت‌ها.
  static String todayLabel() {
    final now = DateTime.now();
    return '${PersianUtils.formatJalaliLong(now)} (${PersianUtils.jalaliWeekday(now)})';
  }

  /// خلاصهٔ وضعیت کاربر (سلامت + پایبندی دارو + وعده‌های غذایی).
  ///
  /// هر بخش رشتهٔ آماده است؛ بخش خالی جا می‌افتد.
  static String healthSnapshot({
    required String dateLabel,
    String? health,
    String? adherence,
    String? meals,
    String? sleepNote,
  }) {
    final buffer = StringBuffer()
      ..writeln('تاریخ امروز: $dateLabel');
    if (health != null && health.isNotEmpty) {
      buffer
        ..writeln('شاخص‌های سلامت آخرین ثبت:')
        ..writeln(health);
    }
    if (sleepNote != null && sleepNote.isNotEmpty) {
      buffer.writeln('وضعیت خواب: $sleepNote');
    }
    if (adherence != null && adherence.isNotEmpty) {
      buffer.writeln('پایبندی دارو: $adherence');
    }
    if (meals != null && meals.isNotEmpty) {
      buffer.writeln('برنامهٔ غذایی: $meals');
    }
    return buffer.toString().trim();
  }

  /// پرامپت بررسی روزانهٔ خودکار.
  static String dailyCheckPrompt(String snapshot) {
    return '''
$snapshot

بر اساس داده‌های بالا، «بررسی روزانهٔ سلامت» را بنویس دقیقاً با این ساختار:
۱) وضعیت کلی (یک خط)
۲) تغذیه (دو توصیهٔ کوتاه و عملی بر اساس وضعیت امروز)
۳) خواب و انرژی (یک خط)
۴) هشدار (فقط اگر لازم است؛ وگرنه «نکتهٔ مهمی نیست»)
جداکنندهٔ بخش‌ها را «—» بگذار و در پایان اگر مقدار غیرعادی دیدی یک جملهٔ ارجاع به پزشک بنویس.
''';
  }

  /// پرامپت تحلیل سریع (دکمه‌های آماده) برای یک موضوع.
  static String quickAnalysisPrompt({
    required String snapshot,
    required String topic,
  }) {
    return '''
$snapshot

موضوع تحلیل: $topic
بر اساس داده‌های بالا تحلیل کوتاه و کاربردی بنویس (حداکثر ۶ خط).
''';
  }

  /// موضوع‌های آمادهٔ تحلیل سریع در بخش دستیار.
  static const List<({String key, String label, IconData icon})> quickTopics = [
    (key: 'nutrition', label: 'تحلیل تغذیهٔ امروز', icon: Icons.restaurant_menu_outlined),
    (key: 'sleep', label: 'تحلیل خواب', icon: Icons.bedtime_outlined),
    (key: 'pressure', label: 'تحلیل فشار و قند', icon: Icons.favorite_outline),
    (key: 'plan', label: 'برنامهٔ غذایی فردا', icon: Icons.calendar_month_outlined),
    (key: 'meds', label: 'وضعیت مصرف داروها', icon: Icons.medication_outlined),
  ];
}
