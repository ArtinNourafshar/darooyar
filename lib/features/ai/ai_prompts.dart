import 'package:flutter/material.dart';

import 'package:darooyar/core/utils/persian_utils.dart';

/// سازندهٔ پرامپت‌های فارسی بخش هوش مصنوعی — توابع خالص و قابل تست.
///
/// زمینهٔ کامل «اطلاعات کاربر» (ساخته‌شده تا `ai_context_builder.dart`)
/// با هر درخواست به مدل می‌رود تا پاسخ دقیقاً برای همان کاربر شخصی‌سازی شود.
abstract final class AiPrompts {
  /// عنوان بخش زمینه که در دستور سیستم و پرامپت روزانه تکرار می‌شود؛
  /// دستور پزشک به این عنوان استناد می‌کند.
  static const String contextHeader = '=== اطلاعات کاربر ===';

  /// پایان بخش زمینه.
  static const String contextFooter = '=== پایان اطلاعات کاربر ===';

  /// افزودن زمینهٔ «اطلاعات کاربر» به دستور سیستم (یک‌بار در هر درخواست،
  /// به‌جای تکرار زمینه در متن هر پیام چت).
  ///
  /// اگر [snapshot] خودش سرور «اطلاعات کاربر» داشته باشد همان‌طور ضمیمه
  /// می‌شود تا عنوان تکراری ساخته نشود.
  static String withSnapshot(String system, String snapshot) {
    final body = snapshot.trim();
    if (body.isEmpty) return system;
    if (body.contains(contextHeader)) return '$system\n\n$body';
    return '$system\n\n$contextHeader\n$body\n$contextFooter';
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

  /// پرامپت بررسی روزانهٔ خودکار — با همان زمینهٔ غنیِ چت.
  ///
  /// [snapshot] متن کامل «اطلاعات کاربر» است (اگر سرور نداشته باشد
  /// همین‌جا اضافه می‌شود).
  static String dailyCheckPrompt(String snapshot) {
    final body = snapshot.trim();
    final contextBlock = body.contains(contextHeader)
        ? body
        : '$contextHeader\n$body\n$contextFooter';

    return '''
$contextBlock

بر اساس بخش «اطلاعات کاربر» بالا و **شخصی‌سازی‌شده برای همین کاربر**، «بررسی روزانهٔ سلامت» را بنویس دقیقاً با این ساختار:
۱) وضعیت کلی (یک خط)
۲) داروها و پایبندی (یک خط؛ نوبت مصرف‌نشده یا داروی رو به اتمام را اگر هست صریح بگو)
۳) تغذیه و آب (دو توصیهٔ کوتاه و عملی بر اساس وضعیت امروز)
۴) خواب و انرژی (یک خط)
۵) هشدار (فقط اگر لازم است؛ وگرنه «نکتهٔ مهمی نیست»)
جداکنندهٔ بخش‌ها را «—» بگذار و در پایان اگر مقدار غیرعادی دیدی یک جملهٔ ارجاع به پزشک بنویس.
''';
  }

  /// پرامپت تحلیل سریع (دکمه‌های آماده) برای یک موضوع.
  static String quickAnalysisPrompt({
    required String snapshot,
    required String topic,
  }) {
    final body = snapshot.trim();
    final contextBlock = body.contains(contextHeader)
        ? body
        : '$contextHeader\n$body\n$contextFooter';

    return '''
$contextBlock

موضوع تحلیل: $topic
بر اساس بخش «اطلاعات کاربر» بالا تحلیل کوتاه و کاربردی بنویس (حداکثر ۶ خط).
''';
  }

  /// موضوع‌های آمادهٔ تحلیل سریع در بخش دستیار.
  ///
  /// - [label] روی چیپ نمایش داده می‌شود و به‌عنوان پیام کاربر در چت می‌ماند.
  /// - [prompt] متنی است که واقعاً برای مدل فرستاده می‌شود (دقیق‌تر و کامل‌تر).
  static const List<({String key, String label, String prompt, IconData icon})>
      quickTopics = [
    (
      key: 'full',
      label: 'تحلیل کامل من',
      prompt:
          'تحلیل کامل من: بر اساس بخش «اطلاعات کاربر»، همهٔ وضعیت مرا شخصی تحلیل کن — '
          'افراد و داروها، نوبت‌های مصرف‌نشده، داروی رو به اتمام، شاخص‌های سلامت و روند وزن و BMI، '
          'آب، تغذیه و خواب. مسائل را به‌ترتیب اولویت (فوری، مهم، پیشنهادی) فهرست کن و برای هرکدام '
          'یک اقدام عملی، کوتاه و مهربان بگو؛ در پایان یادآوری کن جایگزین پزشک نیست.',
      icon: Icons.auto_awesome_outlined,
    ),
    (
      key: 'meds',
      label: 'بررسی داروهایم',
      prompt:
          'بر اساس بخش «اطلاعات کاربر»، وضعیت داروهای مرا بررسی کن: نوبت‌های مصرف‌نشدهٔ امروز، '
          'داروی رو به اتمام، نکتهٔ مهم دربارهٔ زمان مصرف و اولین کاری که باید بکنم.',
      icon: Icons.medication_outlined,
    ),
    (
      key: 'today',
      label: 'برنامهٔ امروز',
      prompt:
          'بر اساس بخش «اطلاعات کاربر»، برنامهٔ امروز مرا مرور کن: چه نوبت‌هایی خورده شده، '
          'چه چیزی مانده و تا چه ساعتی وقت دارم؛ وعده‌های غذایی و لیوان آب امروزم را هم بگو.',
      icon: Icons.today_outlined,
    ),
    (
      key: 'sleep',
      label: 'تحلیل خواب و سلامت',
      prompt:
          'بر اساس بخش «اطلاعات کاربر» (خواب، فشار، قند، وزن و BMI)، وضعیت خواب و سلامت '
          'عمومی‌ام را تحلیل کن و دو توصیهٔ عملی بده.',
      icon: Icons.bedtime_outlined,
    ),
    (
      key: 'nutrition',
      label: 'تغذیه و آب',
      prompt:
          'بر اساس بخش «اطلاعات کاربر» (وعده‌های غذایی و لیوان آب)، تغذیه و آب‌رسانی امروزم را '
          'بررسی کن و دو توصیهٔ کوتاه و عملی بده.',
      icon: Icons.restaurant_menu_outlined,
    ),
    (
      key: 'weight',
      label: 'وزن و BMI',
      prompt:
          'بر اساس بخش «اطلاعات کاربر» (وزن ثبت‌شده، قد و BMI)، روند وزنم را تحلیل کن، '
          'دستهٔ BMI و یک برنامهٔ عملی واقع‌بینانه بگو.',
      icon: Icons.monitor_weight_outlined,
    ),
  ];
}
