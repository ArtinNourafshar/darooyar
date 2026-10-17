import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// ساخت یک نوبت آزمایشی برای تست نمودار.
DoseSlot _slot({
  required String dateKey,
  required String timeKey,
  required DoseStatus status,
}) {
  final parts = dateKey.split('-');
  final timeParts = timeKey.split(':');
  return DoseSlot(
    medicationId: 1,
    profileId: 1,
    medicationName: 'دارو',
    dose: '۱',
    profileName: 'الف',
    profileColorValue: 0xFF000000,
    dateKey: dateKey,
    timeKey: timeKey,
    scheduledAt: DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    ),
    status: status,
  );
}

void main() {
  final now = DateTime(2025, 10, 2, 10, 0);

  group('ReportRange.resolve', () {
    test('امروز: شروع و پایان یکسان', () {
      final (start, end) = ReportRange.today.resolve(now);
      expect(start, '2025-10-02');
      expect(end, '2025-10-02');
    });

    test('هفتگی: شش روز قبل از امروز', () {
      final (start, end) = ReportRange.last7.resolve(now);
      expect(start, '2025-09-26');
      expect(end, '2025-10-02');
    });

    test('ماهیانه: ۲۹ روز قبل از امروز', () {
      final (start, end) = ReportRange.last30.resolve(now);
      expect(start, '2025-09-03');
      expect(end, '2025-10-02');
    });

    test('سالیانه: شروع null برای تعیین توسط پرووایدر', () {
      final (start, end) = ReportRange.all.resolve(now);
      expect(start, isNull);
      expect(end, '2025-10-02');
    });

    test('اوایل بامداد یک روز جابه‌جا نمی‌شود (محاسبهٔ روزمحور)', () {
      final earlyMorning = DateTime(2025, 10, 2, 0, 30);
      final (start7, end7) = ReportRange.last7.resolve(earlyMorning);
      expect(start7, '2025-09-26');
      expect(end7, '2025-10-02');

      final (start30, end30) = ReportRange.last30.resolve(earlyMorning);
      expect(start30, '2025-09-03');
      expect(end30, '2025-10-02');
    });
  });

  group('ReportRange.label', () {
    test('برچسب فارسی هر بازه', () {
      expect(ReportRange.today.label, 'امروز');
      expect(ReportRange.last7.label, 'هفتگی');
      expect(ReportRange.last30.label, 'ماهیانه');
      expect(ReportRange.all.label, 'سالیانه');
    });
  });

  group('ReportStats', () {
    test('پایبندی فقط نوبت‌های گذشته را می‌شمارد', () {
      const stats = ReportStats(
        taken: 5,
        skipped: 1,
        missed: 1,
        upcoming: 3,
      );
      expect(stats.decided, 7);
      expect(stats.total, 10);
      expect(stats.adherencePercent, moreOrLessEquals(5 / 7 * 100));
    });

    test('بدون نوبت گذشته، پایبندی صفر است (تقسیم بر صفر ندارد)', () {
      const stats = ReportStats(
        taken: 0,
        skipped: 0,
        missed: 0,
        upcoming: 4,
      );
      expect(stats.decided, 0);
      expect(stats.adherencePercent, 0);
    });

    test('آمار خالی', () {
      expect(ReportStats.empty.total, 0);
      expect(ReportStats.empty.decided, 0);
    });
  });

  group('ReportChartBuilder', () {
    test('امروز: گروه‌بندی به تفکیک ساعت', () {
      final rows = [
        _slot(
          dateKey: '2025-10-02',
          timeKey: '08:00',
          status: DoseStatus.taken,
        ),
        _slot(
          dateKey: '2025-10-02',
          timeKey: '08:00',
          status: DoseStatus.missed,
        ),
        _slot(
          dateKey: '2025-10-02',
          timeKey: '13:00',
          status: DoseStatus.skipped,
        ),
        _slot(
          dateKey: '2025-10-02',
          timeKey: '20:00',
          status: DoseStatus.upcoming,
        ),
      ];

      final bars =
          ReportChartBuilder.build(range: ReportRange.today, rows: rows, now: now);

      // «در انتظار» در نمودار نمی‌آید؛ ساعت‌ها مرتب.
      expect(bars, hasLength(2));
      expect(bars[0].label, '۰۸:۰۰');
      expect(bars[0].taken, 1);
      expect(bars[0].notTaken, 1);
      expect(bars[1].label, '۱۳:۰۰');
      expect(bars[1].taken, 0);
      expect(bars[1].notTaken, 1);
      expect(bars[1].total, 1);
    });

    test('هفتگی: دقیقاً ۷ ستون روزانه با ستون‌های صفر', () {
      final rows = [
        _slot(
          dateKey: '2025-10-02',
          timeKey: '08:00',
          status: DoseStatus.taken,
        ),
        _slot(
          dateKey: '2025-09-26',
          timeKey: '09:00',
          status: DoseStatus.missed,
        ),
      ];

      final bars = ReportChartBuilder.build(
        range: ReportRange.last7,
        rows: rows,
        now: now,
      );

      expect(bars, hasLength(7));
      // اولین ستون: شش روز قبل (2025-09-26) با یک مصرف نشده.
      expect(bars.first.taken, 0);
      expect(bars.first.notTaken, 1);
      // آخرین ستون: امروز با یک خورده.
      expect(bars.last.taken, 1);
      expect(bars.last.notTaken, 0);
      // روزهای بدون نوبت صفر هستند.
      expect(bars[3].total, 0);
    });

    test('ماهیانه: دقیقاً ۳۰ ستون روزانه', () {
      final bars = ReportChartBuilder.build(
        range: ReportRange.last30,
        rows: const [],
        now: now,
      );
      expect(bars, hasLength(30));
      expect(bars.every((b) => b.total == 0), isTrue);
    });

    test('سالیانه: گروه‌بندی به تفکیک ماه شمسی', () {
      final rows = [
        _slot(
          dateKey: '2025-09-23',
          timeKey: '08:00',
          status: DoseStatus.taken,
        ), // مهر
        _slot(
          dateKey: '2025-09-24',
          timeKey: '08:00',
          status: DoseStatus.taken,
        ), // مهر
        _slot(
          dateKey: '2025-08-23',
          timeKey: '08:00',
          status: DoseStatus.missed,
        ), // شهریور
      ];

      final bars = ReportChartBuilder.build(
        range: ReportRange.all,
        rows: rows,
        now: now,
      );

      // دو ماه شمسی: شهریور (۰۶) و مهر (۰۷) مرتب‌شده صعودی.
      expect(bars, hasLength(2));
      expect(bars[0].label, '۰۶ ماه'); // شهریور
      expect(bars[0].taken, 0);
      expect(bars[0].notTaken, 1);
      expect(bars[1].label, '۰۷ ماه'); // مهر
      expect(bars[1].taken, 2);
      expect(bars[1].notTaken, 0);
    });

    test('بدون ردیف، هیچ ستونی ساخته نمی‌شود (امروز)', () {
      final bars = ReportChartBuilder.build(
        range: ReportRange.today,
        rows: const [],
        now: now,
      );
      expect(bars, isEmpty);
    });
  });
}
