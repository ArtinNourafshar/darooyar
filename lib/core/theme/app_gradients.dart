import 'package:flutter/material.dart';

/// گرادیان‌های برند دارویار: نارنجی گرم ← آبی آسمانی.
///
/// در رابط راست‌چین، گرادیان‌ها از بالا-راست به پایین-چپ کشیده می‌شوند
/// تا «نارنجی» (گرم/اقدام) سمتِ خواندن شروع شود.
abstract final class AppGradients {
  /// گرادیان اصلی هیرو: نارنجی → کهربایی → آبی آسمانی.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFFF7A2F),
      Color(0xFFFFA64D),
      Color(0xFF3FB6F2),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// گرادیان ملایم برای سطوح ثانویه (کارت‌های آماری).
  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFFFE9DC),
      Color(0xFFDDF1FF),
    ],
  );

  /// گرادیان تأیید/فعالیت (پیشرفت و چارت‌ها).
  static const LinearGradient activity = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF7A2F),
      Color(0xFF3FB6F2),
    ],
  );

  /// گرادیان پشت‌زمینهٔ بخش «سلامت».
  static const LinearGradient calm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3FB6F2),
      Color(0xFF8ED8FF),
    ],
  );
}
