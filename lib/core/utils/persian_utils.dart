import 'package:shamsi_date/shamsi_date.dart';

/// ابزارهای تبدیل ارقام و قالب‌بندی تاریخ/ساعت فارسی.
///
/// فونت IRANYekan هر دو مجموعه ارقام لاتین و فارسی را دارد؛ اما برای
/// یکدستی کامل رابط کاربری، همهٔ ارقام نمایش‌داده‌شده به فارسی تبدیل می‌شوند.
class PersianUtils {
  PersianUtils._();

  static const String _latinDigits = '0123456789';
  static const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// تبدیل همهٔ ارقام لاتین یک رشته به ارقام فارسی.
  static String toPersianDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final index = _latinDigits.indexOf(String.fromCharCode(rune));
      buffer.write(index == -1 ? String.fromCharCode(rune) : _persianDigits[index]);
    }
    return buffer.toString();
  }

  /// قالب «۰۸:۳۰» برای زمان ۲۴ ساعته از [DateTime].
  static String formatTime(DateTime time) => toPersianDigits(timeKey(time));

  /// کلید ذخیره‌سازی ساعت به وقت محلی: «HH:mm» (لاتین).
  static String timeKey(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// قالب «۰۸:۳۰» از رشتهٔ ذخیره‌شدهٔ «HH:mm».
  static String formatTimeString(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return toPersianDigits(hhmm);
    final hh = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    return toPersianDigits('$hh:$mm');
  }

  /// «۱۴۰۴/۰۷/۱۱»
  static String formatJalaliDate(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final f = j.formatter;
    return toPersianDigits('${f.yyyy}${f.sep}${f.mm}${f.sep}${f.dd}');
  }

  /// «۱۴۰۴/۰۷/۱۱» از رشتهٔ ذخیره‌شدهٔ «yyyy-MM-dd» میلادی.
  static String formatJalaliFromDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return formatJalaliDate(date);
  }

  /// نام روز هفتهٔ شمسی: «یک شنبه»
  static String jalaliWeekday(DateTime date) {
    return Jalali.fromDateTime(date).formatter.wN;
  }

  /// «۱۱ مهر ۱۴۰۴»
  static String formatJalaliLong(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final f = j.formatter;
    return toPersianDigits('${f.d} ${f.mN} ${f.yyyy}');
  }

  /// کلید ذخیره‌سازی تاریخ در پایگاه‌داده: «yyyy-MM-dd» به وقت محلی دستگاه.
  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// ترکیب کلید تاریخ «HH:mm» و ساعت «HH:mm» به یک [DateTime] کامل.
  static DateTime dateTimeFromKey(String dateKey, String timeKey) {
    final dateParts = dateKey.split('-');
    final timeParts = timeKey.split(':');
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }
}
