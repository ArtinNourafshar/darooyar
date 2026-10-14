/// بازهٔ زمانی گزارش.
enum ReportRange {
  /// امروز.
  today,

  /// ۷ روز اخیر (شامل امروز).
  last7,

  /// ۳۰ روز اخیر (شامل امروز).
  last30,

  /// همهٔ تاریخچه از اولین ثبت.
  all,
}

extension ReportRangeX on ReportRange {
  String get label => switch (this) {
        ReportRange.today => 'امروز',
        ReportRange.last7 => '۷ روز اخیر',
        ReportRange.last30 => '۳۰ روز اخیر',
        ReportRange.all => 'همهٔ تاریخچه',
      };

  /// کلیدهای تاریخ شروع/پایان نسبت به امروز.
  ///
  /// برای [ReportRange.all] مقدار شروع `null` است و پرووایدر آن را از
  /// روی اولین تاریخ ثبت داروها تعیین می‌کند.
  (String? startKey, String endKey) resolve(DateTime now) {
    final endKey = _key(now);
    switch (this) {
      case ReportRange.today:
        return (endKey, endKey);
      case ReportRange.last7:
        return (_key(now.subtract(const Duration(days: 6))), endKey);
      case ReportRange.last30:
        return (_key(now.subtract(const Duration(days: 29))), endKey);
      case ReportRange.all:
        return (null, endKey);
    }
  }

  static String _key(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
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
