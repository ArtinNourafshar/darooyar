import 'package:flutter/material.dart';

/// تم «زمردی/تیل پزشکی» دارویار:
///
/// - پالت دو رنگهٔ **زمردی عمیق** (اعتماد/اقدام/سلامت) + **تیل آبی**
///   (آرامش/آب) با اکسنت **کهربایی** برای هشدارها
/// - سطوح سبز-خاکستری ملایم در روز و ذغالی سبز در شب
/// - فرم‌های خیلی گرد (کارت ۲۶، دیالوگ ۲۸، دکمه‌های پیل)
/// - پیشرفت‌ها و نشانگرها با گرادیان زمردی←تیل
/// - فونت سراسری IRANYekan
///
/// تم سیستم (روشن/تیره) دنبال می‌شود؛ رنگ پویای Material You فقط
/// به‌عنوان [`AppTheme.seed`] برای سیستم‌های بدون تم دستی است.
abstract final class AppTheme {
  // ── زمردی (رنگ اول) ──────────────────────────────────────────────
  static const Color emerald = Color(0xFF0E7C66);
  static const Color emeraldDeep = Color(0xFF0A5F4F);
  static const Color emeraldContainer = Color(0xFFA8F2DC);
  static const Color onEmeraldContainer = Color(0xFF002E24);

  // ── تیل (رنگ دوم) ────────────────────────────────────────────────
  static const Color teal = Color(0xFF2CA58D);
  static const Color tealContainer = Color(0xFFCFF5EC);
  static const Color onTealContainer = Color(0xFF002E28);

  // ── سطوح روشن (سبز-خاکستری) ─────────────────────────────────────
  static const Color _lightSurface = Color(0xFFF7FBF9);
  static const Color _lightOnSurface = Color(0xFF101F1A);
  static const Color _lightOnSurfaceVariant = Color(0xFF526660);

  // ── سطوح تیره (ذغالی سبز) ───────────────────────────────────────
  static const Color _darkSurface = Color(0xFF0E1613);
  static const Color _darkOnSurface = Color(0xFFDDE6E2);
  static const Color _darkOnSurfaceVariant = Color(0xFF9FB4AD);

  /// بذر پیش‌فرض (برای سیستم‌های بدون Material You).
  static const Color seed = emerald;

  static ThemeData light() => _build(_lightScheme());
  static ThemeData dark() => _build(_darkScheme());

  static ColorScheme _lightScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: emerald,
        onPrimary: Colors.white,
        primaryContainer: emeraldContainer,
        onPrimaryContainer: onEmeraldContainer,
        secondary: teal,
        onSecondary: Colors.white,
        secondaryContainer: tealContainer,
        onSecondaryContainer: onTealContainer,
        tertiary: Color(0xFFD99A00),
        onTertiary: Color(0xFF3A2C00),
        tertiaryContainer: Color(0xFFFFE9B8),
        onTertiaryContainer: Color(0xFF3A2C00),
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        onSurfaceVariant: _lightOnSurfaceVariant,
        outline: Color(0xFF74908A),
        outlineVariant: Color(0xFFC4D6D1),
        shadow: Color(0xFF000000),
        scrim: Color(0x99000000),
        inverseSurface: Color(0xFF1E312B),
        onInverseSurface: Color(0xFFF4FBF8),
        inversePrimary: Color(0xFF7DD6BC),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF2FAF7),
        surfaceContainer: Color(0xFFECF5F2),
        surfaceContainerHigh: Color(0xFFE6EFEC),
        surfaceContainerHighest: Color(0xFFE0EAE6),
        surfaceTint: emerald,
      );

  static ColorScheme _darkScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF5FD8BC),
        onPrimary: Color(0xFF00382B),
        primaryContainer: Color(0xFF005244),
        onPrimaryContainer: Color(0xFF9DF3DC),
        secondary: Color(0xFF7FD8C8),
        onSecondary: Color(0xFF00382F),
        secondaryContainer: Color(0xFF005144),
        onSecondaryContainer: Color(0xFFA0F0E2),
        tertiary: Color(0xFFF5C24A),
        onTertiary: Color(0xFF3C2E00),
        tertiaryContainer: Color(0xFF594400),
        onTertiaryContainer: Color(0xFFFFE9B8),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        onSurfaceVariant: _darkOnSurfaceVariant,
        outline: Color(0xFF6B7B75),
        outlineVariant: Color(0xFF25332E),
        shadow: Color(0xFF000000),
        scrim: Color(0x99000000),
        inverseSurface: Color(0xFFDCE5E1),
        onInverseSurface: Color(0xFF1E312B),
        inversePrimary: Color(0xFF2CA58D),
        surfaceContainerLowest: Color(0xFF070E0C),
        surfaceContainerLow: Color(0xFF131D1A),
        surfaceContainer: Color(0xFF17221F),
        surfaceContainerHigh: Color(0xFF212C29),
        surfaceContainerHighest: Color(0xFF2B3733),
        surfaceTint: Color(0xFF5FD8BC),
      );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // رنگ کارت و ورودی‌ها بر اساس روشن/تیره.
    final cardColor =
        isDark ? const Color(0xFF17221F) : const Color(0xFFFFFFFF);
    final fieldColor =
        isDark ? const Color(0xFF1C2724) : const Color(0xFFF1F8F5);

    // مرز سبز-خاکستری ملایم به‌جای خاکستری خنثی.
    final softBorder = BorderSide(color: scheme.outlineVariant, width: 1);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IRANYekan',
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0A1210) : const Color(0xFFF5FAF8),

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
          fontSize: 22,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: softBorder,
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

      // دکمه‌ها استادیومی (پیل) — امضای استایل زمردی.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
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
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
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
          borderSide: softBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: softBorder,
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
        backgroundColor: isDark ? const Color(0xFF101A17) : Colors.white,
        elevation: 0,
        height: 74,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
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
        backgroundColor: isDark ? const Color(0xFF101A17) : Colors.white,
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

      // دکمهٔ شناور کشیده/گرد مدرن با رنگ زمردی.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      // منوی کشویی گرد بدون سایه (مینیمال مدرن).
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: softBorder,
        ),
        textStyle: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      // ورق پایینی مدرن با دستهٔ کشیدن.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
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
