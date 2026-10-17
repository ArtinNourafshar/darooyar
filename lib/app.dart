import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/theme/app_theme.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/ai/ai_snapshot.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/shell/home_shell.dart';

/// ریشهٔ اپلیکیشن دارویار.
///
/// - تم ثابت برند (نارنجی + آبی آسمانی) با حالت روشن/تیرهٔ سیستم
/// - زبان فارسی و راست‌چین (به‌صورت خودکار از روی locale)
/// - رعایت مقیاس فونت کاربر با محدودهٔ ۰٫۸ تا ۱٫۸ (مناسب سالمندان)
class DarooyarApp extends StatefulWidget {
  const DarooyarApp({super.key});

  @override
  State<DarooyarApp> createState() => _DarooyarAppState();
}

class _DarooyarAppState extends State<DarooyarApp> {
  @override
  void initState() {
    super.initState();

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
      context.read<MealProvider>().load();
      context.read<HealthProvider>().load();

      // بررسی روزانهٔ دستیار: فقط وقتی کاربر دستیار را فعال کرده باشد
      // (opt-in) و با تاخیر کوتاه تا داده‌های اولیه آماده شده باشند.
      unawaited(_maybeRunDailyCheck());

      // درخواست مجوز نوتیفیکیشن پس از اولین فریم؛ دیالوگ سیستم دیگر روی
      // اسپلش ظاهر نمی‌شود و در صورت ردِ مجوز، بنر راهنما نمایش داده می‌شود.
      NotificationService.instance.requestPermissions();
    });
  }

  /// بررسی روزانهٔ دستیار (فقط اگر فعال باشد و یک‌بار در روز).
  Future<void> _maybeRunDailyCheck() async {
    final ai = context.read<AiProvider>();
    await ai.load();
    if (!mounted || !ai.isConfigured) return;

    // تاخیر کوتاه تا داده‌های اولیهٔ بخش‌ها آماده شده باشند.
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted || !ai.isConfigured) return;

    await ai.maybeRunDailyCheck(buildAiSnapshot(context));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دارویار',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
