import 'package:flutter/material.dart';

import 'package:darooyar/core/utils/persian_utils.dart';

/// سازندهٔ پرامپت‌های فارسی بخش هوش مصنوعی — توابع خالص و قابل تست.
///
/// فقط خلاصه‌های آماری (نه دادهٔ خامِ کامل) به مدل ارسال می‌شود و
/// همهٔ متن‌ها فارسی‌اند تا پاسخ مدل هم فارسی روان باشد.
abstract final class AiPrompts {
  /// دستور سیستم مشترک: محدودهٔ پزشکی/تغذیه‌ای دستیار.
  static const String systemInstruction = '''
شما «دستیار سلامت دارویار» هستید؛ دستیار تغذیه و سلامت خانواده در یک اپلیکیشن یادآور دارو.
قواعد:
- حتماً به زبان فارسی روان، مختصر و دوستانه پاسخ بده (حداکثر ۸ خط مگر درخواست شود).
- فقط توصیهٔ عمومی تغذیه‌ای و سبک زندگی بده؛ هرگز دارو تجویز یا دوز تغییر نده.
- اگر نشانهٔ خطرناک یا مقدار غیرعادی دیدی، صریح بگو فوراً با پزشک مشورت شود.
- اعداد را با توجه به داده‌های ارسالی تحلیل کن و اگر داده‌ای نیست، از کاربر بپرس.
- به‌جای فهرست‌های طولانی، اول نتیجهٔ کلی بعد توصیه‌ها را بنویس.
''';

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

  /// پرامپت چت (با پیوست خلاصهٔ وضعیت به‌عنوان زمینه).
  static String chatPrompt({
    required String snapshot,
    required String userMessage,
  }) {
    return '''
$snapshot

پیام کاربر:
$userMessage
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
