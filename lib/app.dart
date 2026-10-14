import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/theme/app_theme.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/shell/home_shell.dart';

/// ریشهٔ اپلیکیشن دارویار.
///
/// - تم داینامیک Material You: رنگ سیستم (CorePalette اندروید یا رنگ اکنت
///   ویندوز) به‌عنوان بذر رنگ؛ در نبود آن بذر ثابت `AppTheme.seed`
/// - زبان فارسی و راست‌چین (به‌صورت خودکار از روی locale)
/// - رعایت مقیاس فونت کاربر با محدودهٔ ۰٫۸ تا ۱٫۸ (مناسب سالمندان)
class DarooyarApp extends StatefulWidget {
  const DarooyarApp({super.key});

  @override
  State<DarooyarApp> createState() => _DarooyarAppState();
}

class _DarooyarAppState extends State<DarooyarApp> {
  /// بذر رنگ سیستم؛ تا رسیدن پاسخ، null است و تم از بذر ثابت استفاده می‌کند.
  Color? _systemSeed;

  @override
  void initState() {
    super.initState();
    _loadSystemSeed();

    // بارگذاری اولیهٔ همهٔ بخش‌ها پس از ساخت اولین فریم.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profiles = context.read<ProfileProvider>();
      final medications = context.read<MedicationProvider>();
      // شمارش داروهای افراد پس از هر تغییر دارو به‌روز می‌شود.
      medications.setProfileCountsListener(profiles.refreshCounts);
      profiles.load();
      medications.load();
      context.read<ScheduleProvider>().load();
      context.read<ReportProvider>().load();
    });
  }

  /// دریافت رنگ پویای سیستم:
  ///
  /// - اندروید: CorePalette سیستم (Material You)
  /// - ویندوز/لینوکس/مک: رنگ اکنت سیستم
  ///
  /// هر خطا یا نبود پشتیبانی، بدون اثر ماندنی جذب می‌شود و بذر ثابت
  /// `AppTheme.seed` مورد استفاده قرار می‌گیرد.
  Future<void> _loadSystemSeed() async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null && mounted) {
        setState(() {
          _systemSeed = Color(corePalette.primary.get(40));
        });
        return;
      }
    } catch (_) {
      // پلتفرم پشتیبانی نمی‌کند → تلاش بعدی.
    }

    try {
      final accent = await DynamicColorPlugin.getAccentColor();
      if (accent != null && mounted) {
        setState(() {
          _systemSeed = accent;
        });
      }
    } catch (_) {
      // بدون رنگ سیستم → تم از بذر ثابت استفاده می‌کند.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دارویار',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(_systemSeed),
      darkTheme: AppTheme.dark(_systemSeed),
      themeMode: ThemeMode.system,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // رعایت فونت درشت‌شدهٔ سیستم تا ۱٫۸ برابر و کوچک تا ۰٫۸ برابر
        // تا چیدمان در همهٔ حالت‌ها سالم بماند.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.8,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeShell(),
    );
  }
}
