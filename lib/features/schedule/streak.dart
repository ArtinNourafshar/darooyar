/// محاسبهٔ «روزهای پیاپی مصرف کامل» (استریک) — منطق خالص و قابل تست.
///
/// قاعده (ورودی: آمار هر روز از روی نوبت‌های همان روز):
/// - یک روز «کامل» است اگر همهٔ نوبت‌های آن خورده شده باشند؛ وجود نوبت
///   «مصرف نشده» یا «نخوردم» استریک را قطع می‌کند (نوبت در انتظار مانعی
///   ندارد).
/// - روزهای بدون هیچ نوبتی (مثلاً پیش از ثبت نخستین دارو) نادیده گرفته
///   می‌شوند و استریک را نمی‌شکنند.
/// - شمارش از دیروز به عقب ادامه می‌یابد؛ امروز فقط اگر مصرف ناقصی داشته
///   باشد استریک را می‌شکند.
library;

/// آمار یک روز برای محاسبهٔ استریک (از روی نوبت‌های همان روز ساخته می‌شود).
class DayCompliance {
  const DayCompliance({required this.taken, required this.broken});

  /// تعداد نوبت‌های خورده‌شده.
  final int taken;

  /// آیا نوبتی مصرف‌نشده یا «نخوردم» دارد؟
  final bool broken;
}

/// محاسبهٔ طول استریک از روی آمار روزها، کلیدشان «yyyy-MM-dd».
abstract final class StreakCalculator {
  /// شمارش روزهای پیاپیِ «کامل» که به [todayKey] ختم می‌شود.
  ///
  /// [days] فقط باید روزهای دارای نوبت باشد (روزهای بدون نوبت حذف شده‌اند).
  static int compute({
    required String todayKey,
    required Map<String, DayCompliance> days,
  }) {
    var streak = 0;
    var cursor = _previousDayKey(todayKey);

    // امروز: فقط مصرف ناقص استریک را می‌شکند.
    final today = days[todayKey];
    if (today != null) {
      if (today.broken) return 0;
      if (today.taken > 0) streak++;
    }

    // روزهای قبل: روز بدون نوبت نادیده گرفته می‌شود (داروی جدید استریک
    // قبلی را نمی‌سوزاند)؛ روز شکسته استریک را قطع می‌کند؛ روز کامل به
    // شمارش اضافه می‌شود. حداکثر ۳۶۶ روز بررسی می‌شود.
    for (var i = 0; i < 366; i++) {
      final day = days[cursor];
      if (day != null) {
        if (day.broken) break;
        if (day.taken > 0) streak++;
      }
      cursor = _previousDayKey(cursor);
    }

    return streak;
  }

  /// کلید روز قبل از [dateKey] («yyyy-MM-dd»).
  static String _previousDayKey(String dateKey) {
    final parts = dateKey.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    ).subtract(const Duration(days: 1));
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
