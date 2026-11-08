import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/theme/app_theme.dart';
import 'package:darooyar/features/ai/ai_config.dart';
import 'package:darooyar/features/ai/ai_insight_repository.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/ai/ai_screen.dart';

/// تنظیمات در حافظه — بدون پایگاه‌داده (sqflite در تست در دسترس نیست).
class _FakeSettings extends SettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<bool> getBool(String key, {bool orElse = false}) async {
    final value = values[key];
    if (value == null) return orElse;
    return value == '1';
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

/// بینش‌های بی‌صدا — بدون پایگاه‌داده.
class _FakeInsights extends AiInsightRepository {
  @override
  Future<AiInsight?> latest(String kind) async => null;

  @override
  Future<AiInsight?> forDay(String day, String kind) async => null;

  @override
  Future<void> save({
    required String day,
    required String kind,
    required String text,
    required String createdAt,
  }) async {}

  @override
  Future<void> prune({int keep = 60}) async {}
}

Widget _app(AiProvider ai) {
  return ChangeNotifierProvider<AiProvider>(
    create: (_) => ai,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AiScreen(),
    ),
  );
}

AiProvider _ai({Map<String, String> settings = const {}}) {
  final fake = _FakeSettings()..values.addAll(settings);
  return AiProvider(settings: fake, insights: _FakeInsights());
}

Future<void> _pump(WidgetTester tester, AiProvider ai) async {
  await tester.pumpWidget(_app(ai));
  // فریم اول + اجرای load در postFrame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('حالت تنظیمات: معرفی، بدون فیلد متنی و راست‌چین', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, _ai());

    // عنوان هر دو در نوار برنامه و کارت معرفی هست؛ معرفی دقیقاً یک‌بار.
    expect(find.text('پزشک آنلاین دارویار'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('فعال‌سازی پزشک'), findsOneWidget);

    // کل رابط راست‌چین است.
    final directions = tester
        .widgetList<Directionality>(find.byType(Directionality))
        .map((w) => w.textDirection)
        .toSet();
    expect(directions, {TextDirection.rtl});

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فعال‌سازی: دکمه سوییچ روزانه را نگه می‌دارد و پیام می‌دهد',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ai = _ai();
    await _pump(tester, ai);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'فعال‌سازی پزشک'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(SnackBar), findsOneWidget);
    // بدون کلید سازنده، همچنان حالت تنظیمات می‌ماند.
    if (kAiApiKey.isEmpty) {
      expect(find.byType(TextField), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
  });

  // این دو تست فقط با کلید سازنده قابل اجراست:
  // flutter test --dart-define=DAROOYAR_AI_KEY=AQ.… test/ai_screen_test.dart
  testWidgets(
      'حالت فعال: دکمهٔ تحلیل کامل، چیپ‌ها، خوش‌آمدگویی و ورودی',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, _ai(settings: const {'ai_enabled': '1'}));

    expect(find.byType(TextField), findsOneWidget);
    // دکمهٔ برجستهٔ تحلیل کامل من + چیپ‌های موضوعی.
    expect(find.text('تحلیل کامل من'), findsOneWidget);
    expect(find.text('بررسی داروهایم'), findsOneWidget);
    expect(find.text('برنامهٔ امروز'), findsOneWidget);
    // حالت خالی با پیام خوش‌آمدگویی.
    expect(find.text('سلام! من پزشک دارویارم'), findsOneWidget);
    // دکمهٔ ارسال بدون متن غیرفعال است.
    final send = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((b) => b.tooltip == 'ارسال');
    expect(send.onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  }, skip: kAiApiKey.isEmpty);

  testWidgets('حالت فعال: حباب‌های چت، زمان و پاک کردن از منو',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = jsonEncode([
      {'u': 1, 't': 'سلام، سردرد دارم', 'd': 1717200000000},
      {'u': 0, 't': 'سلام! بگویید چند روز است و شدتش چقدر.', 'd': 1717200006000},
    ]);
    await _pump(
      tester,
      _ai(settings: {'ai_enabled': '1', 'ai_chat': history}),
    );

    // حباب کاربر و پزشک با آواتارهای متفاوت.
    expect(find.text('سلام، سردرد دارم'), findsOneWidget);
    expect(
      find.text('سلام! بگویید چند روز است و شدتش چقدر.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
    // زیر هر حباب ساعت به ارقام فارسی.
    expect(
      tester.widgetList<Text>(find.byType(Text)).where(
            (t) => RegExp(r'^[۰-۹]{2}:[۰-۹]{2}$').hasMatch(t.data ?? ''),
          ),
      hasLength(2),
    );

    // پاک کردن گفتگو از منوی گزینه‌ها.
    await tester.tap(find.byTooltip('گزینه‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاک کردن گفتگو'));
    await tester.pumpAndSettle();

    expect(find.text('سلام، سردرد دارم'), findsNothing);
    expect(find.text('سلام! من پزشک دارویارم'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  }, skip: kAiApiKey.isEmpty);
}
