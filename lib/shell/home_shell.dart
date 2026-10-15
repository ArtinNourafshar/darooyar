import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/medications/medications_screen.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/profiles/profiles_screen.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/reports/reports_screen.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/features/schedule/today_screen.dart';

/// پوستهٔ اصلی: ناوبری تطبیقی (NavigationRail در دسکتاپ / NavigationBar در موبایل).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// کاربر بنر مجوز نوتیفیکیشن را بسته باشد (دیگر پا فشاری نمی‌شود).
  bool _permissionBannerDismissed = false;

  static const _titles = ['امروز', 'داروها', 'افراد', 'گزارش'];

  static const _icons = [
    Icons.event_available_outlined,
    Icons.medication_outlined,
    Icons.people_outline,
    Icons.bar_chart_outlined,
  ];

  static const _selectedIcons = [
    Icons.event_available,
    Icons.medication,
    Icons.people,
    Icons.bar_chart,
  ];

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

  /// هنگام ورود به هر بخش، داده‌های آن بخش به‌روز می‌شود.
  void _refreshFor(int index) {
    final schedule = context.read<ScheduleProvider>();
    final report = context.read<ReportProvider>();
    final medications = context.read<MedicationProvider>();
    final profiles = context.read<ProfileProvider>();

    switch (index) {
      case 0:
        schedule.load();
      case 1:
        medications.load();
      case 2:
        profiles.load();
      case 3:
        report.load();
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
      TodayScreen(onGoToMedications: () => _select(1)),
      MedicationsScreen(onGoToProfiles: () => _select(2)),
      const ProfilesScreen(),
      const ReportsScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(              selectedIndex: _index,
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

    return Scaffold(
      body: _withPermissionNotice(
        IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (var i = 0; i < _titles.length; i++)
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.health_and_safety, color: scheme.onPrimaryContainer),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.health_and_safety,
            size: 22,
            color: scheme.onPrimaryContainer,
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
