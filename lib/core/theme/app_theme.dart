import 'package:flutter/material.dart';

/// تم «گرادیانی» دارویار:
///
/// - پالت دو رنگهٔ **نارنجی** (اقدام/هشدار/گرما) + **آبی آسمانی** (آرامش/سلامت)
/// - فرم‌های خیلی گرد (کارت ۲۴، دکمه‌های استادیومی/پیل)
/// - سطوح گرمِ کرمی در روز و قهوه‌ای تیره در شب
/// - پیشرفت‌ها و نشانگرها با گرادیان نارنجی←آسمانی
/// - فونت سراسری IRANYekan
///
/// تم سیستم (روشن/تیره) دنبال می‌شود؛ رنگ پویای Material You فقط
/// به‌عنوان [`AppTheme.withSeed`] برای سازگاری نگه داشته شده و در تم
/// پیش‌فرض از پالت ثابت برند استفاده می‌شود.
abstract final class AppTheme {
  // ── نارنجی (رنگ اول) ──────────────────────────────────────────────
  static const Color orange = Color(0xFFFF6A2B);
  static const Color orangeDeep = Color(0xFFE8541A);
  static const Color orangeContainer = Color(0xFFFFE2D1);
  static const Color onOrangeContainer = Color(0xFF7A2B00);

  // ── آبی آسمانی (رنگ دوم) ─────────────────────────────────────────
  static const Color sky = Color(0xFF25A6E8);
  static const Color skyContainer = Color(0xFFD6EEFF);
  static const Color onSkyContainer = Color(0xFF0A4763);

  // ── سطوح روشن ─────────────────────────────────────────────────────
  static const Color _lightSurface = Color(0xFFFAF7F3);
  static const Color _lightOnSurface = Color(0xFF211A16);
  static const Color _lightOnSurfaceVariant = Color(0xFF6E625B);

  // ── سطوح تیره ─────────────────────────────────────────────────────
  static const Color _darkSurface = Color(0xFF17130F);
  static const Color _darkOnSurface = Color(0xFFF6F0EB);
  static const Color _darkOnSurfaceVariant = Color(0xFFBCAFA6);

  /// بذر پیش‌فرض (برای سیستم‌های بدون Material You).
  static const Color seed = orange;

  static ThemeData light() => _build(_lightScheme());
  static ThemeData dark() => _build(_darkScheme());

  static ColorScheme _lightScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: orange,
        onPrimary: Colors.white,
        primaryContainer: orangeContainer,
        onPrimaryContainer: onOrangeContainer,
        secondary: sky,
        onSecondary: Colors.white,
        secondaryContainer: skyContainer,
        onSecondaryContainer: onSkyContainer,
        tertiary: Color(0xFFFFB300),
        onTertiary: Color(0xFF3D2B00),
        tertiaryContainer: Color(0xFFFFE7AE),
        onTertiaryContainer: Color(0xFF3D2B00),
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        onSurfaceVariant: _lightOnSurfaceVariant,
        outline: Color(0xFFC9BDB4),
        outlineVariant: Color(0xFFE7DDD4),
        shadow: Color(0xFF000000),
        scrim: Color(0x99000000),
        inverseSurface: Color(0xFF372F2A),
        onInverseSurface: Color(0xFFFDF3EC),
        inversePrimary: Color(0xFFFFB68C),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFFEF8F3),
        surfaceContainer: Color(0xFFF7F1EC),
        surfaceContainerHigh: Color(0xFFF1EBE5),
        surfaceContainerHighest: Color(0xFFEBE5DF),
        surfaceTint: orange,
      );

  static ColorScheme _darkScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFF8A50),
        onPrimary: Color(0xFF4A1600),
        primaryContainer: Color(0xFF8A3200),
        onPrimaryContainer: Color(0xFFFFDBCB),
        secondary: Color(0xFF7CD0FF),
        onSecondary: Color(0xFF003449),
        secondaryContainer: Color(0xFF004C6B),
        onSecondaryContainer: Color(0xFFC8EAFF),
        tertiary: Color(0xFFFFCA57),
        onTertiary: Color(0xFF412D00),
        tertiaryContainer: Color(0xFF5E4200),
        onTertiaryContainer: Color(0xFFFFE7AE),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        onSurfaceVariant: _darkOnSurfaceVariant,
        outline: Color(0xFF8B7F76),
        outlineVariant: Color(0xFF403831),
        shadow: Color(0xFF000000),
        scrim: Color(0x99000000),
        inverseSurface: Color(0xFFF1E5DC),
        onInverseSurface: Color(0xFF372F2A),
        inversePrimary: Color(0xFFB43D00),
        surfaceContainerLowest: Color(0xFF110E0B),
        surfaceContainerLow: Color(0xFF1A1613),
        surfaceContainer: Color(0xFF1F1B17),
        surfaceContainerHigh: Color(0xFF2A2521),
        surfaceContainerHighest: Color(0xFF352F2A),
        surfaceTint: Color(0xFFFF8A50),
      );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // رنگ کارت و ورودی‌ها بر اساس روشن/تیره.
    final cardColor =
        isDark ? const Color(0xFF1F1B17) : const Color(0xFFFFFFFF);
    final fieldColor =
        isDark ? const Color(0xFF241F1B) : const Color(0xFFF6F1EC);

    // مرز گرمِ ملایم به‌جای خاکستری خنثی.
    final warmBorder = BorderSide(color: scheme.outlineVariant, width: 1);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IRANYekan',
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF131010) : const Color(0xFFF9F6F2),

      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w900,
          fontSize: 21,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: warmBorder,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w900,
          fontSize: 19,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 15,
          height: 1.6,
          color: scheme.onSurfaceVariant,
        ),
      ),

      // دکمه‌ها استادیومی (پیل) — امضای استایل گرادیانی.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: scheme.primary, width: 1.4),
          foregroundColor: scheme.primary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 15,
          color: scheme.onSurfaceVariant,
        ),
        labelStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 15,
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: warmBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: warmBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: fieldColor,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1815) : Colors.white,
        elevation: 0,
        height: 72,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
            size: 26,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1815) : Colors.white,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        groupAlignment: -0.92,
        labelType: NavigationRailLabelType.none,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 26),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 26),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w400,
          fontSize: 13.5,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 14.5,
          height: 1.5,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
        linearMinHeight: 10,
      ),

      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: scheme.outline, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outlineVariant),
        thumbColor: WidgetStateProperty.all(
          isDark ? scheme.onSurface : Colors.white,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      textTheme: _textTheme(scheme),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle base({
      required double size,
      FontWeight weight = FontWeight.w400,
      double height = 1.5,
    }) {
      return TextStyle(
        fontFamily: 'IRANYekan',
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: scheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: base(size: 44, weight: FontWeight.w900, height: 1.25),
      displayMedium: base(size: 36, weight: FontWeight.w900, height: 1.25),
      displaySmall: base(size: 30, weight: FontWeight.w900, height: 1.3),
      headlineLarge: base(size: 26, weight: FontWeight.w900, height: 1.35),
      headlineMedium: base(size: 23, weight: FontWeight.w900, height: 1.35),
      headlineSmall: base(size: 20, weight: FontWeight.w800, height: 1.4),
      titleLarge: base(size: 18, weight: FontWeight.w800, height: 1.45),
      titleMedium: base(size: 16, weight: FontWeight.w800, height: 1.5),
      titleSmall: base(size: 14, weight: FontWeight.w700, height: 1.5),
      bodyLarge: base(size: 16, weight: FontWeight.w400, height: 1.65),
      bodyMedium: base(size: 14.5, weight: FontWeight.w400, height: 1.65),
      bodySmall: base(size: 12.5, weight: FontWeight.w400, height: 1.55),
      labelLarge: base(size: 15, weight: FontWeight.w700, height: 1.4),
      labelMedium: base(size: 13, weight: FontWeight.w700, height: 1.4),
      labelSmall: base(size: 11.5, weight: FontWeight.w600, height: 1.4),
    );
  }
}
