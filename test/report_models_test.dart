import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/features/reports/report_models.dart';

void main() {
  final now = DateTime(2025, 10, 2, 10, 0);

  group('ReportRange.resolve', () {
    test('امروز: شروع و پایان یکسان', () {
      final (start, end) = ReportRange.today.resolve(now);
      expect(start, '2025-10-02');
      expect(end, '2025-10-02');
    });

    test('۷ روز اخیر: شش روز قبل از امروز', () {
      final (start, end) = ReportRange.last7.resolve(now);
      expect(start, '2025-09-26');
      expect(end, '2025-10-02');
    });

    test('۳۰ روز اخیر: ۲۹ روز قبل از امروز', () {
      final (start, end) = ReportRange.last30.resolve(now);
      expect(start, '2025-09-03');
      expect(end, '2025-10-02');
    });

    test('همهٔ تاریخچه: شروع null برای تعیین توسط پرووایدر', () {
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
      expect(ReportRange.last7.label, '۷ روز اخیر');
      expect(ReportRange.last30.label, '۳۰ روز اخیر');
      expect(ReportRange.all.label, 'همهٔ تاریخچه');
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
}
