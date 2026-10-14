import 'package:flutter/material.dart';

/// کلاس‌های عرض پنجره (Material Window Size Classes) + آستانهٔ دسکتاپ.
///
/// مکانیزم‌های مقیاس‌بندی فلاتر که در این پروژه استفاده می‌شوند:
/// 1. **Breakpoints / Window Size Classes** — تغییر ساختار ناوبری و چیدمان
///    بر اساس عرض موجود (این فایل).
/// 2. **MediaQuery textScaler** — رعایت اندازهٔ فونت تنظیم‌شده توسط کاربر
///    (برای سالمندان حیاتی) با clamp بازهٔ ۰٫۸ تا ۱٫۸ برای جلوگیری از
///    شکستن چیدمان (در `app.dart`).
/// 3. **Scale factor پاسخگو** — ضریب فاصله‌گذاری و اندازهٔ عناصر بر اساس
///    عرض صفحه ([Scale.of]).
/// 4. **LayoutBuilder + عرض حداکثر محتوا** — محدود کردن عرض محتوا در
///    نمایشگرهای بزرگ ([Scale.maxContentWidth]).
/// 5. **FittedBox / Flexible** — جلوگیری از سرریز متن در مقیاس‌های بزرگ.
enum WindowClass { compact, medium, expanded }

/// آستانه‌های عرض (پیکسل منطقی).
abstract final class Breakpoints {
  /// تا ۵۹۹: موبایل فشرده (تک‌ستونه، نوار پایین).
  static const double compactMax = 599;

  /// ۶۰۰ تا ۸۳۹: تبلت/پنجرهٔ متوسط (ستون‌بندی دوتایی).
  static const double mediumMax = 839;

  /// ۸۴۰ به بالا: دسکتاپ (Rail کناری، سه‌ستونه).
  static const double desktop = 840;

  /// از این عرض به بالا برچسب‌های Rail باز می‌شوند.
  static const double railExtended = 1100;
}

extension WindowClassX on BuildContext {
  /// عرض فعلی فضا (پیکسل منطقی).
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// ارتفاع فعلی فضا.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// کلاس عرض پنجره بر اساس Material Window Size Classes.
  WindowClass get windowClass {
    final w = screenWidth;
    if (w <= Breakpoints.compactMax) return WindowClass.compact;
    if (w <= Breakpoints.mediumMax) return WindowClass.medium;
    return WindowClass.expanded;
  }

  bool get isCompact => windowClass == WindowClass.compact;
  bool get isMedium => windowClass == WindowClass.medium;
  bool get isExpanded => windowClass == WindowClass.expanded;

  /// مقدار پیش‌فرض بر اساس کلاس عرض.
  T responsive<T>(T compact, T? medium, T? expanded) {
    switch (windowClass) {
      case WindowClass.compact:
        return compact;
      case WindowClass.medium:
        return medium ?? compact;
      case WindowClass.expanded:
        return expanded ?? medium ?? compact;
    }
  }
}

/// ضریب مقیاس‌پذیری فاصله‌ها و اندازه‌های چیدمان.
///
/// compact = ۱٫۰ (معیار موبایل)، medium = ۱٫۱۵، expanded = ۱٫۳ — یعنی
/// در نمایشگر بزرگ فاصله‌ها و کارت‌ها کمی پهن‌تر می‌شوند اما ساختار ثابت می‌ماند.
class Scale {
  Scale._(this.windowClass);

  final WindowClass windowClass;

  static Scale of(BuildContext context) =>
      Scale._(context.windowClass);

  /// ضریب کلی فاصله‌گذاری.
  double get factor {
    switch (windowClass) {
      case WindowClass.compact:
        return 1;
      case WindowClass.medium:
        return 1.15;
      case WindowClass.expanded:
        return 1.3;
    }
  }

  /// [base] در ضریب مقیاس — برای padding و اندازهٔ کارت‌ها.
  double by(double base) => base * factor;

  /// حداکثر عرض محتوای اصلی؛ در دسکتاپ وسط‌چین می‌شود.
  double get maxContentWidth {
    switch (windowClass) {
      case WindowClass.compact:
        return double.infinity;
      case WindowClass.medium:
        return 840;
      case WindowClass.expanded:
        return 1080;
    }
  }

  /// حداکثر عرض فرم‌ها/دیالوگ‌ها.
  double get maxFormWidth => windowClass == WindowClass.compact ? double.infinity : 560;

  /// حداکثر تعداد ستون در چیدمان شبکه‌ای (کارت‌های دارو).
  int get maxGridColumns {
    switch (windowClass) {
      case WindowClass.compact:
        return 1;
      case WindowClass.medium:
        return 2;
      case WindowClass.expanded:
        return 3;
    }
  }

  /// حاشیهٔ افقی صفحه.
  double get gutter => switch (windowClass) {
        WindowClass.compact => 16,
        WindowClass.medium => 24,
        WindowClass.expanded => 32,
      };
}

/// محتوای محدود‌شده در عرض حداکثر + وسط‌چین (برای دسکتاپ).
class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({super.key, required this.child, this.scale});

  final Widget child;
  final Scale? scale;

  @override
  Widget build(BuildContext context) {
    final maxWidth = (scale ?? Scale.of(context)).maxContentWidth;
    if (maxWidth == double.infinity) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
