import 'package:flutter/material.dart';

/// گرادیان‌های برند دارویار: **زمردی عمیق ← تیل روشن** (پالت پزشکی).
///
/// در رابط راست‌چین، گرادیان‌های هیرو از بالا-راست به پایین-چپ کشیده
/// می‌شوند تا رنگ زمردی عمیق (اقدام/اعتماد) سمتِ خواندن شروع شود.
abstract final class AppGradients {
  /// گرادیان اصلی هیرو: زمردی ← تیل ← یشمی روشن.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF0E8F73),
      Color(0xFF14B8A6),
      Color(0xFF5EEAD4),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// گرادیان ملایم برای سطوح ثانویه (کارت‌های آماری و حباب پاسخ).
  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFDFF7EF),
      Color(0xFFD5F3F6),
    ],
  );

  /// گرادیان تأیید/فعالیت (پیشرفت و چارت‌ها).
  static const LinearGradient activity = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF10B981),
      Color(0xFF14B8A6),
    ],
  );

  /// گرادیان پشت‌زمینهٔ بخش «سلامت» و نوشیدن آب.
  static const LinearGradient calm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0EA5A4),
      Color(0xFF67E8F9),
    ],
  );

  /// گرادیان تیرهٔ هیرو (حالت شب): زمردی شب‌تاب.
  static const LinearGradient heroDark = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF0B5E4E),
      Color(0xFF0E7C66),
      Color(0xFF14B8A6),
    ],
    stops: [0.0, 0.55, 1.0],
  );
}
