import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/meals/meal_slot.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';

/// سازندهٔ بخش «اطلاعات کاربر» — زمینهٔ غنی و ساختاریافته که با هر درخواست
/// چت یا بررسی روزانه در اختیار مدل قرار می‌گیرد تا پاسخ **شخصی** باشد.
///
/// - همهٔ توابع از [profilesSection] تا [assemble] خالص‌اند (فهرست مدل می‌گیرند
///   و رشتهٔ فارسی برمی‌گردانند) تا با تست واحد پوشش داده شوند.
/// - فقط [fromContext] به `BuildContext` وصل است و هر بخش را جداگانه
///   محافظت می‌کند؛ اگر پرووایدری در دسترس نباشد همان بخش حذف می‌شود و
///   چت هرگز نمی‌شکند.
///
/// فقط داده‌هایی که واقعاً در مدل‌های اپ وجود دارند نوشته می‌شود؛ فیلدی
/// اختراع نمی‌شود (مثلاً مدل «فرد» فقط نام، رنگ و تاریخ ثبت دارد).
abstract final class AiContextBuilder {
  // ── ساخت از BuildContext (با محافظت هر بخش) ───────────────────────

  /// متن کامل «اطلاعات کاربر» از داده‌های زندهٔ اپ.
  static String fromContext(BuildContext context) {
    final dateLabel = AiPrompts.todayLabel();

    final profilesText = _guard(() {
      final provider = context.read<ProfileProvider>();
      return profilesSection(
        profiles: provider.profiles,
        medicationCounts: provider.medicationCounts,
      );
    });

    final medicationsText = _guard(() {
      final provider = context.read<MedicationProvider>();
      final nameById = {
        for (final p in context.read<ProfileProvider>().profiles) p.id: p.name,
      };
      return medicationsSection(
        medications: provider.medications,
        profileName: (id) => nameById[id] ?? 'نامشخص',
      );
    });

    final scheduleText = _guard(() {
      final provider = context.read<ScheduleProvider>();
      return scheduleSection(
        slots: provider.slots,
        streakDays: provider.streakDays,
      );
    });

    final healthText = _guard(() {
      return healthSection(summary: context.read<HealthProvider>().aiSummary());
    });

    final waterText = _guard(() {
      final provider = context.read<HealthProvider>();
      return waterSection(
        cupsToday: provider.waterCupsToday,
        target: provider.waterTarget,
        week: provider.waterWeek,
      );
    });

    final mealsText = _guard(() {
      return mealsSection(slots: context.read<MealProvider>().slots);
    });

    final insightText = _guard(() {
      return insightSection(context.read<AiProvider>().dailyInsight);
    });

    return assemble(
      dateLabel: dateLabel,
      profiles: profilesText,
      medications: medicationsText,
      schedule: scheduleText,
      health: healthText,
      water: waterText,
      meals: mealsText,
      insight: insightText,
    );
  }

  /// اجرای یک بخش؛ خطا یا پرووایدرِ ناموجود یعنی بخش حذف می‌شود.
  static String _guard(String Function() build) {
    try {
      return build();
    } catch (e) {
      debugPrint('AiContextBuilder: $e');
      return '';
    }
  }

  // ── بخش‌های خالص (قابل تست) ───────────────────────────────────────

  /// بخش «افراد (تو اینفو)»: نام، تاریخ ثبت و تعداد داروی هر فرد.
  static String profilesSection({
    required List<Profile> profiles,
    required Map<int, int> medicationCounts,
  }) {
    if (profiles.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < profiles.length; i++) {
      final profile = profiles[i];
      final meds = medicationCounts[profile.id] ?? 0;
      final created = PersianUtils.formatJalaliFromDateKey(profile.createdAt);
      buffer.writeln(
        '${_p('${i + 1}')}) ${profile.name} — تاریخ ثبت: $created — '
        '${_p('$meds')} داروی ثبت‌شده',
      );
    }
    return buffer.toString().trimRight();
  }

  /// بخش «داروها»: نام، دوز، ساعت‌ها، باقی‌مانده و هشدار اتمام.
  static String medicationsSection({
    required List<Medication> medications,
    required String Function(int profileId) profileName,
  }) {
    if (medications.isEmpty) return '';
    final buffer = StringBuffer();
    for (final medication in medications) {
      final times = medication.times.map(PersianUtils.formatTimeString).join('، ');
      buffer.write(
        '• ${profileName(medication.profileId)}: ${medication.name} — '
        '${medication.dose} — ساعت مصرف: $times',
      );
      final remaining = medication.remainingDoses;
      if (remaining != null) {
        buffer.write(' — باقی‌مانده: ${_p('$remaining')}');
        if (medication.isLowStock) {
          buffer.write(
            remaining == 0
                ? ' (تمام شده؛ فوراً تهیه کنید)'
                : ' (هشدار اتمام؛ به‌زودی تهیه کنید)',
          );
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// بخش «برنامهٔ امروز و پایبندی»: آمار + استریک + جزئیات نوبت‌ها.
  static String scheduleSection({
    required List<DoseSlot> slots,
    required int streakDays,
  }) {
    if (slots.isEmpty) return '';
    final total = slots.length;
    final taken = slots.where((s) => s.status == DoseStatus.taken).length;
    final missed = slots.where((s) => s.status == DoseStatus.missed).length;
    final skipped = slots.where((s) => s.status == DoseStatus.skipped).length;
    final upcoming = slots.where((s) => s.status == DoseStatus.upcoming).length;

    final buffer = StringBuffer()
      ..writeln(
        'امروز ${_p('$taken')} از ${_p('$total')} نوبت دارو خورده شده'
        '${missed > 0 ? '؛ ${_p('$missed')} نوبت مصرف نشده' : ''}'
        '${skipped > 0 ? '؛ ${_p('$skipped')} نوبت رد شده' : ''}'
        '${upcoming > 0 ? '؛ ${_p('$upcoming')} نوبت در انتظار' : ''}',
      );
    if (streakDays > 0) {
      buffer.writeln(
        'استریک مصرف کامل: ${_p('$streakDays')} روز پیاپی',
      );
    }
    buffer.writeln('جزئیات نوبت‌های امروز:');
    // حداکثر ۲۴ نوبت در روز کافی است تا زمینه بی‌جهت طولانی نشود.
    for (final slot in slots.take(24)) {
      buffer.writeln(
        '• ${slot.timeLabel} — ${slot.medicationName} (${slot.dose}) '
        'برای ${slot.profileName}: ${slot.status.label}',
      );
    }
    return buffer.toString().trimRight();
  }

  /// بخش «سلامت»: خلاصهٔ فرد انتخاب‌شده (قد، BMI، فشار، قند، خواب و…).
  ///
  /// [summary] معمولاً از `HealthProvider.aiSummary()` می‌آید.
  static String healthSection({required String summary}) => summary.trim();

  /// بخش «نوشیدن آب»: لیوان امروز نسبت به هدف + شش روز قبل.
  static String waterSection({
    required int cupsToday,
    required int target,
    required Map<String, int> week,
  }) {
    if (cupsToday == 0 && week.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln(
        'امروز ${_p('$cupsToday')} از ${_p('$target')} لیوان آب نوشیده شده',
      );
    if (week.isNotEmpty) {
      final days = week.keys.toList()..sort();
      final line = [
        for (final day in days)
          '${PersianUtils.formatJalaliFromDateKey(day)}: ${_p('${week[day]}')} لیوان',
      ].join('، ');
      buffer.writeln('لیوان شش روز اخیر: $line');
    }
    return buffer.toString().trimRight();
  }

  /// بخش «وعده‌های غذایی»: آمار امروز + وضعیت هر وعده.
  static String mealsSection({required List<MealSlot> slots}) {
    if (slots.isEmpty) return '';
    final total = slots.length;
    final eaten = slots.where((s) => s.status == DoseStatus.taken).length;
    final missed = slots.where((s) => s.status == DoseStatus.missed).length;
    final skipped = slots.where((s) => s.status == DoseStatus.skipped).length;

    final buffer = StringBuffer()
      ..writeln(
        'امروز ${_p('$eaten')} از ${_p('$total')} وعده ثبت شده'
        '${missed > 0 ? '؛ ${_p('$missed')} وعده سپری شده بدون ثبت' : ''}'
        '${skipped > 0 ? '؛ ${_p('$skipped')} وعده رد شده' : ''}',
      );
    for (final slot in slots) {
      buffer.writeln('• ${slot.timeLabel} — ${slot.name}: ${slot.status.label}');
    }
    return buffer.toString().trimRight();
  }

  /// بخش «آخرین بینش دستیار» (بررسی روزانهٔ قبلی) — بریده تا زمینه کوتاه بماند.
  static String insightSection(AiInsight? insight, {int maxChars = 700}) {
    if (insight == null || insight.text.trim().isEmpty) return '';
    final day = PersianUtils.formatJalaliFromDateKey(insight.day);
    return 'آخرین بررسی روزانهٔ دستیار ($day):\n${clip(insight.text, maxChars: maxChars)}';
  }

  /// بریدن متن بلند با نشان «…» (بدون بُرش وسط کاراکترِ فارسی مهم نیست).
  static String clip(String text, {int maxChars = 700}) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars).trimRight()}…';
  }

  /// مونتاژ نهایی: تاریخ + بخش‌های پُر، داخل سرور/پایان «اطلاعات کاربر».
  ///
  /// بخش خالی کاملاً جا می‌افتد تا مدل با متن بی‌معنا مواجه نشود.
  static String assemble({
    required String dateLabel,
    String profiles = '',
    String medications = '',
    String schedule = '',
    String health = '',
    String water = '',
    String meals = '',
    String insight = '',
  }) {
    final buffer = StringBuffer()
      ..writeln(AiPrompts.contextHeader)
      ..writeln('تاریخ امروز: $dateLabel');

    void section(String title, String body) {
      final text = body.trim();
      if (text.isEmpty) return;
      buffer
        ..writeln()
        ..writeln('— $title —')
        ..writeln(text);
    }

    section('افراد (تو اینفو)', profiles);
    section('داروها', medications);
    section('برنامهٔ امروز و پایبندی', schedule);
    section('شاخص‌های سلامت', health);
    section('نوشیدن آب', water);
    section('وعده‌های غذایی', meals);
    section('بینش‌های قبلی دستیار', insight);

    buffer.writeln();
    buffer.write(AiPrompts.contextFooter);
    return buffer.toString();
  }

  /// تبدیل هر مقداری به ارقام فارسی.
  static String _p(Object value) => PersianUtils.toPersianDigits('$value');
}
