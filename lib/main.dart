import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/app.dart';
import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ۱) پایگاه‌دادهٔ محلی SQLite (کاملاً آفلاین).
  await DatabaseService.instance.init();

  // ۲) سرویس نوتیفیکیشن (خطاها بالا نمی‌آیند؛ نتیجه فقط گزارش می‌شود).
  await NotificationService.instance.init();

  // ۳) اجرای اپ با چهار پرووایدر مستقل.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: const DarooyarApp(),
    ),
  );
}
