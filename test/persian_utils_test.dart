import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/core/utils/persian_utils.dart';

void main() {
  group('PersianUtils.toPersianDigits', () {
    test('همهٔ ارقام لاتین به فارسی تبدیل می‌شوند', () {
      expect(PersianUtils.toPersianDigits('0123456789'), '۰۱۲۳۴۵۶۷۸۹');
      expect(PersianUtils.toPersianDigits('2026-10-02'), '۲۰۲۶-۱۰-۰۲');
    });

    test('حروف و نویسه‌های غیر رقمی دست نمی‌خورند', () {
      expect(PersianUtils.toPersianDigits('دوز: 5 میلی‌لیتر'),
          'دوز: ۵ میلی‌لیتر');
      expect(PersianUtils.toPersianDigits('ABC'), 'ABC');
      expect(PersianUtils.toPersianDigits(''), '');
    });

    test('ارقام فارسی موجود تغییر نمی‌کنند', () {
      expect(PersianUtils.toPersianDigits('۱۲۳'), '۱۲۳');
    });
  });

  group('PersianUtils.formatTimeString', () {
    test('ساعت و دقیقه صفر جلو و به فارسی', () {
      expect(PersianUtils.formatTimeString('08:00'), '۰۸:۰۰');
      expect(PersianUtils.formatTimeString('23:09'), '۲۳:۰۹');
    });

    test('تک‌رقمی بدون صفر جلو هم پر می‌شود', () {
      expect(PersianUtils.formatTimeString('9:5'), '۰۹:۰۵');
    });

    test('رشتهٔ خراب بدون متن دو نقطه همان‌طور تبدیل می‌شود', () {
      expect(PersianUtils.formatTimeString('0830'), '۰۸۳۰');
    });
  });

  group('PersianUtils — تاریخ', () {
    test('dateKey و dateTimeFromKey وارونهٔ هم‌اند', () {
      final key = PersianUtils.dateKey(DateTime(2026, 3, 7));
      expect(key, '2026-03-07');

      final dt = PersianUtils.dateTimeFromKey(key, '21:45');
      expect(dt, DateTime(2026, 3, 7, 21, 45));
    });

    test('فرمت تاریخ شمسی از کلید میلادی', () {
      // ۲ اکتبر ۲۰۲۵ میلادی = ۱۰ مهر ۱۴۰۴ شمسی.
      expect(PersianUtils.formatJalaliFromDateKey('2025-10-02'), '۱۴۰۴/۰۷/۱۰');
    });

    test('فرمت بلند شمسی شامل نام ماه و ارقام فارسی است', () {
      expect(
        PersianUtils.formatJalaliLong(DateTime(2025, 10, 2)),
        '۱۰ مهر ۱۴۰۴',
      );
    });
  });
}
