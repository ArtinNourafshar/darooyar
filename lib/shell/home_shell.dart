import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/features/ai/ai_screen.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/health/health_screen.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/medications/medications_screen.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/profiles/profiles_screen.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/reports/reports_screen.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/features/schedule/today_screen.dart';

/// پوستهٔ اصلی: ناوبری تطبیقی (NavigationRail در دسکتاپ / NavigationBar در موبایل).
///
/// پنج بخش در نوار پایین موبایل (امروز، داروها، سلامت، گزارش، دستیار)؛
/// «افراد» در دسکتاپ مقصد ششم Rail است و در موبایل به‌صورت صفحهٔ
/// جداگانه باز می‌شود ([ProfilesScreen.push]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// کاربر بنر مجوز نوتیفیکیشن را بسته باشد (دیگر پا فشاری نمی‌شود).
  bool _permissionBannerDismissed = false;

  static const _titles = ['امروز', 'داروها', 'سلامت', 'گزارش', 'دستیار', 'افراد'];

  static const _icons = [
    Icons.event_available_outlined,
    Icons.medication_outlined,
    Icons.favorite_outline,
    Icons.bar_chart_outlined,
    Icons.auto_awesome_outlined,
    Icons.people_outline,
  ];

  static const _selectedIcons = [
    Icons.event_available,
    Icons.medication,
    Icons.favorite,
    Icons.bar_chart,
    Icons.auto_awesome,
    Icons.people,
  ];

  /// تعداد بخش‌های نوار پایین موبایل («افراد» جداگانه باز می‌شود).
  static const _mobileTabs = 5;

  @override
  void initState() {
    super.initState();

    // ضربهٔ کاربر روی نوتیفیکیشن → باز شدن بخش «امروز».
    NotificationService.instance.onNotificationTapped = (_) {
      if (mounted) _select(0);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScheduleProvider>().startTicker();
    });
  }

  @override
  void dispose() {
    NotificationService.instance.onNotificationTapped = null;
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _refreshFor(index);
  }

  /// باز کردن بخش «افراد»: در دسکتاپ با انتخاب مقصد Rail، در موبایل
  /// به‌صورت صفحهٔ رویی (push).
  void _openProfiles() {
    if (context.isExpanded) {
      _select(5);
    } else {
      ProfilesScreen.push(context);
    }
  }

  /// هنگام ورود به هر بخش، داده‌های آن بخش به‌روز می‌شود.
  void _refreshFor(int index) {
    final schedule = context.read<ScheduleProvider>();
    final report = context.read<ReportProvider>();
    final medications = context.read<MedicationProvider>();
    final profiles = context.read<ProfileProvider>();
    final health = context.read<HealthProvider>();

    switch (index) {
      case 0:
        schedule.load();
      case 1:
        medications.load();
      case 2:
        health.load();
      case 3:
        report.load();
      case 4:
        break; // دستیار خودش تنظیماتش را بارگذاری می‌کند.
      case 5:
        profiles.load();
    }
  }

  /// بنر راهنمای مجوز نوتیفیکیشن (فقط اندروید و فقط اگر مجوز رد شده باشد).
  ///
  /// بدون این بنر، ردِ یک‌بارهٔ مجوز یعنی یادآوری‌ها برای همیشه خاموش.
  Widget _withPermissionNotice(Widget child) {
    final service = NotificationService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final showBanner = Platform.isAndroid &&
            service.permissionsRequested &&
            !service.notificationPermissionGranted &&
            !_permissionBannerDismissed;
        if (!showBanner) return child;

        return Column(
          children: [
            MaterialBanner(
              content: const Text(
                'برای دریافت یادآوری دارو، مجوز نمایش نوتیفیکیشن لازم است.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await NotificationService.instance.requestPermissions();
                    // اگر باز هم رد شد، بنر بسته می‌شود تا آزاردهنده نباشد.
                    if (!NotificationService.instance
                            .notificationPermissionGranted &&
                        mounted) {
                      setState(() => _permissionBannerDismissed = true);
                    }
                  },
                  child: const Text('درخواست دوباره'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _permissionBannerDismissed = true),
                  child: const Text('بستن'),
                ),
              ],
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isExpanded;
    final extended = context.screenWidth >= Breakpoints.railExtended;

    // دکمه‌های «افزودن» در حالت خالی، بخش مربوطه را باز می‌کنند.
    final pages = [
      TodayScreen(
        onGoToMedications: () => _select(1),
        onGoToAssistant: () => _select(4),
      ),
      MedicationsScreen(onGoToProfiles: _openProfiles),
      const HealthScreen(),
      const ReportsScreen(),
      const AiScreen(),
      const ProfilesScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              extended: extended,
              minExtendedWidth: 180,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: extended
                    ? const _BrandRow()
                    : const _BrandMark(),
              ),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    selectedIcon: Icon(_selectedIcons[i]),
                    label: Text(_titles[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: _withPermissionNotice(
                IndexedStack(index: _index, children: pages),
              ),
            ),
          ],
        ),
      );
    }

    // موبایل: پنج تب؛ اگر از دسکتاپ با انتخاب «افراد» تغییر عرض شده باشد،
    // به اولین تب برمی‌گردیم تا selectedIndex همیشه معتبر بماند.
    final mobileIndex = _index < _mobileTabs ? _index : 0;

    return Scaffold(
      body: _withPermissionNotice(
        IndexedStack(index: mobileIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: _select,
        destinations: [
          for (var i = 0; i < _mobileTabs; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              selectedIcon: Icon(_selectedIcons[i]),
              label: _titles[i],
            ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFF7A2F), Color(0xFF3FB6F2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.health_and_safety, color: Colors.white),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFF7A2F), Color(0xFF3FB6F2)],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.health_and_safety,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'دارویار',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
