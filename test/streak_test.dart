import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/features/schedule/streak.dart';

/// محاسبهٔ «روزهای پیاپی مصرف کامل» — قاعده‌های استریک.
void main() {
  const today = '2026-10-17';

  DayCompliance full({int taken = 2}) => DayCompliance(taken: taken, broken: false);
  const broken = DayCompliance(taken: 0, broken: true);

  group('استریک پایه', () {
    test('بدون ثبت، صفر است', () {
      expect(
        StreakCalculator.compute(todayKey: today, days: const {}),
        0,
      );
    });

    test('فقط امروز کامل: ۱ روز', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {today: full()},
        ),
        1,
      );
    });

    test('سه روز پیاپی کامل: ۳ روز', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            '2026-10-17': full(),
            '2026-10-16': full(),
            '2026-10-15': full(),
          },
        ),
        3,
      );
    });

    test('امروز هنوز مصرف نشده (بدون ثبت امروز): روزهای قبل شمرده می‌شوند', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            '2026-10-16': full(),
            '2026-10-15': full(),
          },
        ),
        2,
      );
    });

    test('امروز مصرف ناقص دارد: استریک صفر می‌شود', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            today: broken,
            '2026-10-16': full(),
            '2026-10-15': full(),
          },
        ),
        0,
      );
    });
  });

  group('قطع شدن استریک', () {
    test('روز «نخوردم» (broken) وسط کار استریک را قطع می‌کند', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            today: full(),
            '2026-10-16': broken,
            '2026-10-15': full(),
            '2026-10-14': full(),
          },
        ),
        1,
      );
    });

    test('روز مصرف‌نشده در دیروز، امروز را نمی‌شمارد', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            today: full(),
            '2026-10-16': broken,
          },
        ),
        1,
      );
    });

    test('شکست دیروز، روزهای پیش از آن را نمی‌شمارد', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            today: full(),
            '2026-10-16': broken,
            '2026-10-15': full(),
          },
        ),
        1,
      );
    });
  });

  group('روزهای بدون نوبت', () {
    test('شکاف بدون ثبت (مثل قبل از ثبت دارو) استریک را نمی‌شکند', () {
      expect(
        StreakCalculator.compute(
          todayKey: today,
          days: {
            today: full(),
            '2026-10-14': full(),
            '2026-10-13': full(),
          },
        ),
        3,
      );
    });

    test('همهٔ روزها خالی: صفر', () {
      expect(
        StreakCalculator.compute(todayKey: today, days: const {}),
        0,
      );
    });
  });

  group('مرز ماه و سال', () {
    test('عبور از مرز ماه ادامه می‌یابد', () {
      expect(
        StreakCalculator.compute(
          todayKey: '2026-11-01',
          days: {
            '2026-11-01': full(),
            '2026-10-31': full(),
            '2026-10-30': full(),
          },
        ),
        3,
      );
    });

    test('عبور از مرز سال ادامه می‌یابد', () {
      expect(
        StreakCalculator.compute(
          todayKey: '2027-01-01',
          days: {
            '2027-01-01': full(),
            '2026-12-31': full(),
          },
        ),
        2,
      );
    });
  });
}
