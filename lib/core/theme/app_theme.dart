import 'package:flutter/material.dart';

/// تم «مات» دارویار:
/// - بدون گرادیان، بدون براقیت (surfaceTintColor شفاف، ارتفاع سایهٔ صفر)
/// - کارت‌ها با کادر مویی به‌جای سایه
/// - دنبال‌کردن تم سیستم (روشن/تیره) و رنگ‌های داینامیک Material You
/// - فونت سراسری IRANYekan
abstract final class AppTheme {
  /// بذر رنگ برای سیستم‌های بدون Material You (ویندوز و اندروید قدیمی).
  static const Color seed = Color(0xFF16706B);

  /// [seedColor] رنگ پویای سیستم (Material You یا اکنت ویندوز) است؛
  /// در نبود آن از [seed] ثابت استفاده می‌شود.
  static ThemeData light(Color? seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? seed,
      brightness: Brightness.light,
    );
    return _build(scheme);
  }

  static ThemeData dark(Color? seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor ?? seed,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // کادر مویی مات به‌جای سایه.
    final hairline = BorderSide(color: scheme.outlineVariant, width: 1);
    final matteShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: hairline,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IRANYekan',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,

      // حذف براقیت سطح Material روی همهٔ عناصر.
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: matteShape,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: hairline,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w800,
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

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'IRANYekan',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderRadius: BorderRadius.circular(14),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        side: hairline,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 14,
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        elevation: 0,
        indicatorColor: scheme.secondaryContainer,
        groupAlignment: -0.9,
        labelType: NavigationRailLabelType.none,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer, size: 26),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 26),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w700,
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
        backgroundColor: isDark ? scheme.inverseSurface : scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 14.5,
          height: 1.5,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 8,
      ),

      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: scheme.outline, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outlineVariant),
        thumbColor: WidgetStateProperty.all(scheme.onSurface),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'IRANYekan',
          fontWeight: FontWeight.w500,
          fontSize: 14.5,
        ),
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
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
      displaySmall: base(size: 30, weight: FontWeight.w800, height: 1.3),
      headlineLarge: base(size: 26, weight: FontWeight.w800, height: 1.35),
      headlineMedium: base(size: 23, weight: FontWeight.w800, height: 1.35),
      headlineSmall: base(size: 20, weight: FontWeight.w700, height: 1.4),
      titleLarge: base(size: 18, weight: FontWeight.w800, height: 1.45),
      titleMedium: base(size: 16, weight: FontWeight.w700, height: 1.5),
      titleSmall: base(size: 14, weight: FontWeight.w700, height: 1.5),
      bodyLarge: base(size: 16, weight: FontWeight.w400, height: 1.65),
      bodyMedium: base(size: 14.5, weight: FontWeight.w400, height: 1.65),
      bodySmall: base(size: 12.5, weight: FontWeight.w400, height: 1.55),
      labelLarge: base(size: 15, weight: FontWeight.w700, height: 1.4),
      labelMedium: base(size: 13, weight: FontWeight.w700, height: 1.4),
      labelSmall: base(size: 11.5, weight: FontWeight.w500, height: 1.4),
    );
  }
}
