import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// بازهٔ زمانی گزارش.
enum ReportRange {
  /// امروز.
  today,

  /// هفتگی (۷ روز اخیر شامل امروز).
  last7,

  /// ماهیانه (۳۰ روز اخیر شامل امروز).
  last30,

  /// سالیانه (حداکثر ۳۶۵ روز اخیر).
  all,
}

extension ReportRangeX on ReportRange {
  String get label => switch (this) {
        ReportRange.today => 'امروز',
        ReportRange.last7 => 'هفتگی',
        ReportRange.last30 => 'ماهیانه',
        ReportRange.all => 'سالیانه',
      };

  /// کلیدهای تاریخ شروع/پایان نسبت به امروز.
  ///
  /// برای [ReportRange.all] مقدار شروع `null` است و پرووایدر آن را از
  /// روی اولین تاریخ ثبت داروها تعیین می‌کند (حداکثر ۳۶۵ روز اخیر).
  (String? startKey, String endKey) resolve(DateTime now) {
    // محاسبهٔ روزمحور (نه ساعت‌محور) تا در مناطق زمانی با DST و اوایل بامداد
    // کلید شروع یک روز جابه‌جا نشود.
    final today = DateTime(now.year, now.month, now.day);
    final endKey = PersianUtils.dateKey(today);
    switch (this) {
      case ReportRange.today:
        return (endKey, endKey);
      case ReportRange.last7:
        return (PersianUtils.dateKey(today.subtract(const Duration(days: 6))),
            endKey);
      case ReportRange.last30:
        return (PersianUtils.dateKey(today.subtract(const Duration(days: 29))),
            endKey);
      case ReportRange.all:
        return (null, endKey);
    }
  }
}

/// آمار گزارش مصرف در یک بازه.
class ReportStats {
  const ReportStats({
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.upcoming,
  });

  final int taken;
  final int skipped;
  final int missed;

  /// نوبت‌های امروز که هنوز زمانشان نرسیده — در محاسبهٔ پایبندی جزو
  /// نوبت‌های گذشته حساب نمی‌شوند.
  final int upcoming;

  /// نوبت‌های گذشته (خورده + نخورده + مصرف‌نشده).
  int get decided => taken + skipped + missed;

  /// مجموع همهٔ نوبت‌ها.
  int get total => decided + upcoming;

  /// درصد پایبندی به مصرف (نوبت‌های خورده‌شده از میان نوبت‌های گذشته).
  double get adherencePercent =>
      decided == 0 ? 0 : (taken / decided) * 100.0;

  static const empty = ReportStats(
    taken: 0,
    skipped: 0,
    missed: 0,
    upcoming: 0,
  );
}

/// یک ستون نمودار مصرف: خورده‌شده در برابر نخورده/مصرف‌نشده.
class ReportBar {
  const ReportBar({
    required this.label,
    required this.taken,
    required this.notTaken,
  });

  /// برچسب فارسی محور افقی (ساعت / روز / ماه شمسی).
  final String label;

  final int taken;

  /// نخوردم + مصرف نشده.
  final int notTaken;

  int get total => taken + notTaken;
}

/// نوع فعالیت در جریان یکپارچهٔ گزارش.
enum ActivityKind { dose, meal, health }

/// یک ردیف از جریان فعالیت (نوبت دارو / وعدهٔ غذایی / ثبت سلامت).
class ActivityEntry {
  const ActivityEntry({
    required this.dateKey,
    required this.timeKey,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.status,
    this.profileColorValue,
  });

  /// کلید روز «yyyy-MM-dd».
  final String dateKey;

  /// ساعت «HH:mm» (لاتین) برای مرتب‌سازی.
  final String timeKey;

  final ActivityKind kind;

  /// نام دارو / وعده / شاخص.
  final String title;

  /// زیرنویس: فرد — دوز / وضعیت / مقدار.
  final String subtitle;

  /// برای دارو و وعده؛ برای ثبت سلامت null.
  final DoseStatus? status;

  /// رنگ نشان فرد (فقط نوبت‌های دارو).
  final int? profileColorValue;
}

/// سازندهٔ ستون‌های نمودار گزارش از روی نوبت‌های محاسبه‌شده — منطق خالص.
///
/// گروه‌بندی بر اساس بازه:
/// - امروز: به تفکیک ساعتِ نوبت‌ها.
/// - هفتگی/ماهیانه: به تفکیک روز (با ستون‌های صفر برای روزهای بدون نوبت).
/// - سالیانه: به تفکیک ماه شمسی.
abstract final class ReportChartBuilder {
  static List<ReportBar> build({
    required ReportRange range,
    required List<DoseSlot> rows,
    required DateTime now,
  }) {
    switch (range) {
      case ReportRange.today:
        return _byTime(rows);
      case ReportRange.last7:
        return _byDay(rows, now, days: 7, labelOfDay: _weekdayLabel);
      case ReportRange.last30:
        return _byDay(rows, now, days: 30, labelOfDay: _dayOfMonthLabel);
      case ReportRange.all:
        return _byMonth(rows);
    }
  }

  static List<ReportBar> _byTime(List<DoseSlot> rows) {
    final taken = <String, int>{};
    final notTaken = <String, int>{};
    for (final row in rows) {
      if (row.status == DoseStatus.taken) {
        taken[row.timeKey] = (taken[row.timeKey] ?? 0) + 1;
      } else if (row.status == DoseStatus.skipped ||
          row.status == DoseStatus.missed) {
        notTaken[row.timeKey] = (notTaken[row.timeKey] ?? 0) + 1;
      }
    }
    final keys = <String>{...taken.keys, ...notTaken.keys}.toList()..sort();
    return [
      for (final key in keys)
        ReportBar(
          label: PersianUtils.formatTimeString(key),
          taken: taken[key] ?? 0,
          notTaken: notTaken[key] ?? 0,
        ),
    ];
  }

  static List<ReportBar> _byDay(
    List<DoseSlot> rows,
    DateTime now, {
    required int days,
    required String Function(DateTime) labelOfDay,
  }) {
    final taken = <String, int>{};
    final notTaken = <String, int>{};
    for (final row in rows) {
      if (row.status == DoseStatus.taken) {
        taken[row.dateKey] = (taken[row.dateKey] ?? 0) + 1;
      } else if (row.status == DoseStatus.skipped ||
          row.status == DoseStatus.missed) {
        notTaken[row.dateKey] = (notTaken[row.dateKey] ?? 0) + 1;
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    final bars = <ReportBar>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = PersianUtils.dateKey(day);
      bars.add(ReportBar(
        label: labelOfDay(day),
        taken: taken[key] ?? 0,
        notTaken: notTaken[key] ?? 0,
      ));
    }
    return bars;
  }

  static List<ReportBar> _byMonth(List<DoseSlot> rows) {
    final taken = <String, int>{};
    final notTaken = <String, int>{};
    for (final row in rows) {
      // کلید گروه: ماه شمسیِ روز نوبت («۱۴۰۴-۰۷»).
      final key = _jalaliMonthKey(row.scheduledAt);
      if (row.status == DoseStatus.taken) {
        taken[key] = (taken[key] ?? 0) + 1;
      } else if (row.status == DoseStatus.skipped ||
          row.status == DoseStatus.missed) {
        notTaken[key] = (notTaken[key] ?? 0) + 1;
      }
    }

    final keys = <String>{...taken.keys, ...notTaken.keys}.toList()..sort();
    return [
      for (final key in keys)
        ReportBar(
          label: _jalaliMonthLabel(key),
          taken: taken[key] ?? 0,
          notTaken: notTaken[key] ?? 0,
        ),
    ];
  }

  static String _weekdayLabel(DateTime day) => PersianUtils.jalaliWeekday(day);

  static String _dayOfMonthLabel(DateTime day) {
    return PersianUtils.formatJalaliLong(day).split(' ').first;
  }

  static String _jalaliMonthKey(DateTime day) {
    final formatted = PersianUtils.formatJalaliDate(day); // ۱۴۰۴/۰۷/۱۱
    final parts = formatted.split('/');
    if (parts.length != 3) return formatted;
    return '${parts[0]}-${parts[1]}';
  }

  static String _jalaliMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    return '${PersianUtils.toPersianDigits(parts[1])} ماه';
  }
}
