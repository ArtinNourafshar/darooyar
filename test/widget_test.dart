import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/app.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/shell/home_shell.dart';

/// اپ کامل با چهار پرووایدر (بدون فراخوانی main؛ پایگاه‌داده در محیط تست
/// در دسترس نیست و پرووایدرها خطای آن را به‌صورت کنترل‌شده مدیریت می‌کنند).
Widget _app() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => MedicationProvider()),
      ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ChangeNotifierProvider(create: (_) => ReportProvider()),
    ],
    child: const DarooyarApp(),
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  // فریم اول + شروع بارگذاری اولیه در postFrame.
  await tester.pump();
  // تکمیل بارگذاری (خطاها به‌صورت کنترل‌شده جذب می‌شوند) و رندر نهایی.
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

/// آزادسازی پرووایدرها پیش از پایان تست (لغو زمان‌سنج درون‌برنامه‌ای).
Future<void> _teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _tapNav(WidgetTester tester, String label) async {
  final nav = find.byType(NavigationBar);
  await tester.tap(find.descendant(of: nav, matching: find.text(label)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('پوستهٔ اصلی: ناوبری موبایل، راست‌چین، فونت فارسی و تم مات',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpApp(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // کل رابط راست‌چین است (locale فارسی).
    final directions = tester
        .widgetList<Directionality>(find.byType(Directionality))
        .map((w) => w.textDirection)
        .toSet();
    expect(directions, {TextDirection.rtl});

    // فونت سراسری ایران‌یکان.
    final theme = Theme.of(tester.element(find.byType(HomeShell)));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'IRANYekan');

    // تم مات: بدون سایهٔ کارت و بدون ارتفاع AppBar.
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);

    await _teardownTree(tester);
  });

  testWidgets('جابه‌جایی میان چهار بخش و نمایش حالت خالی هر بخش',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpApp(tester);

    // بخش «امروز» به‌صورت پیش‌فرض انتخاب شده است.
    expect(find.text('امروز'), findsWidgets);

    await _tapNav(tester, 'داروها');
    expect(find.text('ابتدا فردی ثبت کنید'), findsOneWidget);
    expect(find.text('هنوز فردی ثبت نشده'), findsNothing);

    await _tapNav(tester, 'افراد');
    expect(find.text('هنوز فردی ثبت نشده'), findsOneWidget);
    expect(find.text('ابتدا فردی ثبت کنید'), findsNothing);

    await _tapNav(tester, 'گزارش');
    expect(find.text('نوبتی در این بازه نیست'), findsOneWidget);
    expect(find.text('خروجی PDF'), findsOneWidget);

    await _tapNav(tester, 'امروز');
    expect(find.text('امروز'), findsWidgets);

    await _teardownTree(tester);
  });

  testWidgets('دکمهٔ «افزودن فرد» در حالت خالی، بخش افراد را باز می‌کند',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpApp(tester);
    await _tapNav(tester, 'داروها');

    final emptyAction = find.widgetWithText(FilledButton, 'افزودن فرد');
    expect(emptyAction, findsOneWidget);
    await tester.tap(emptyAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('هنوز فردی ثبت نشده'), findsOneWidget);

    await _teardownTree(tester);
  });

  testWidgets('در عرض دسکتاپ، NavigationRail جای NavigationBar را می‌گیرد',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpApp(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // برچسب‌های Rail در عرض ≥۱۱۰۰ باز می‌شوند.
    expect(find.text('دارویار'), findsOneWidget);
    expect(find.text('گزارش'), findsWidgets);

    await _teardownTree(tester);
  });
}
