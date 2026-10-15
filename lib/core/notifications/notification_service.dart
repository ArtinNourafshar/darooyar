import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:darooyar/features/medications/medication.dart';

/// خروجی مورد انتظار از [NotificationService.init].
class NotificationInitResult {
  const NotificationInitResult({
    required this.pluginReady,
    required this.notificationPermissionGranted,
    required this.exactAlarmPermissionGranted,
  });

  /// آیا افزونهٔ نوتیفیکیشن با موفقیت مقداردهی اولیه شد.
  final bool pluginReady;

  /// مجوز نمایش نوتیفیکیشن (اندروید ۱۳ به بالا).
  final bool notificationPermissionGranted;

  /// مجوز آلارم دقیق (اندروید ۱۲ به بالا).
  final bool exactAlarmPermissionGranted;
}

/// سرویس یادآوری با نوتیفیکیشن محلی (بدون اینترنت).
///
/// رفتار هر پلتفرم:
/// - **اندروید**: زمان‌بندی تکرار روزانه با `matchDateTimeComponents: time`
///   + دریافت مجوز نمایش نوتیفیکیشن و آلارم دقیق + سازگاری با ری‌استارت
///   دستگاه (Boot Receiver در AndroidManifest).
/// - **ویندوز**: زمان‌بندی تکی برای نوبت بعدی (قابلیت تکرار در ویندوز
///   وجود ندارد)؛ همگام‌سازی دوباره در هر بار اجرای برنامه و پس از هر
///   تغییر دارو + یادآوری درون‌برنامه‌ای هنگام باز بودن برنامه.
///
/// این کلاس [ChangeNotifier] است تا رابط کاربری (بنر مجوز) بتواند وضعیت
/// مجوزها را تماشا کند.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'darooyar_reminders';
  static const String _channelName = 'یادآوری دارو';
  static const String _channelDescription =
      'یادآوری زمان مصرف داروهای خانواده';

  static const String _windowsGuid = '7c1e4f60-9a2b-4d58-b3c7-2f8e51a94d16';
  static const String _windowsAppUserModelId = 'Com.Darooyar.FamilyReminder';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;
  bool _exactAlarmGranted = false;
  bool _notificationPermissionGranted = true;
  bool _permissionsRequested = false;

  /// زنجیرهٔ اجرای زمان‌بندی‌ها؛ برای جلوگیری از هم‌پوشانی دو فراخوانی
  /// هم‌زمان (لغوِ وسطِ کارِ یکدیگر).
  Future<void> _rescheduleChain = Future.value();

  /// ضربهٔ کاربر روی نوتیفیکیشن (payload: `medication:<id>`).
  void Function(String? payload)? onNotificationTapped;

  bool get isInitialized => _initialized;

  /// آیا مجوز نمایش نوتیفیکیشن داده شده (پس از [requestPermissions] دقیق است).
  bool get notificationPermissionGranted => _notificationPermissionGranted;

  /// آیا درخواست مجوزها یک بار انجام شده؛ بنر فقط از این پس نمایش داده
  /// می‌شود تا با دیالوگ سیستم هم‌زمان نشود.
  bool get permissionsRequested => _permissionsRequested;

  /// مقداردهی اولیهٔ افزونه، منطقهٔ زمانی و کانال اعلان اندروید.
  ///
  /// خطاها هرگز بالا پرتاب نمی‌شوند تا رابط کاربری بدون نوتیفیکیشن هم
  /// بالا بیاید؛ نتیجه در [NotificationInitResult] گزارش می‌شود.
  Future<NotificationInitResult> init() async {
    if (_initialized) {
      return NotificationInitResult(
        pluginReady: true,
        notificationPermissionGranted: _notificationPermissionGranted,
        exactAlarmPermissionGranted: _exactAlarmGranted,
      );
    }

    var pluginReady = false;
    var notificationPermissionGranted = true;
    var exactAlarmGranted = false;

    try {
      await _initTimezone();
      pluginReady = true;
    } catch (e) {
      debugPrint('خطا در مقداردهی منطقهٔ زمانی نوتیفیکیشن: $e');
      pluginReady = false;
    }

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const windowsSettings = WindowsInitializationSettings(
        appName: 'دارویار',
        appUserModelId: _windowsAppUserModelId,
        guid: _windowsGuid,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        windows: windowsSettings,
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) =>
            onNotificationTapped?.call(response.payload),
      );
      pluginReady = true;
    } catch (e) {
      debugPrint('خطا در مقداردهی افزونهٔ نوتیفیکیشن: $e');
      pluginReady = false;
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        try {
          await android.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
            ),
          );
        } catch (e) {
          debugPrint('خطا در ساخت کانال نوتیفیکیشن: $e');
        }

        // فقط وضعیت فعلی خوانده می‌شود؛ درخواست مجوز در [requestPermissions]
        // و پس از اولین فریم رابط کاربری انجام می‌شود تا دیالوگ سیستم روی
        // اسپلش و بدون زمینه ظاهر نشود.
        try {
          notificationPermissionGranted =
              await android.areNotificationsEnabled() ?? false;
        } catch (e) {
          debugPrint('خطا در خواندن مجوز نوتیفیکیشن: $e');
          notificationPermissionGranted = false;
        }

        try {
          exactAlarmGranted =
              await android.canScheduleExactNotifications() ?? false;
        } catch (e) {
          debugPrint('خطا در بررسی مجوز آلارم دقیق: $e');
        }
      }
    } else if (!Platform.isWindows) {
      // پلتفرم‌های دیگر نیازی به مجوز اندرویدی ندارند.
      exactAlarmGranted = true;
    }

    _initialized = pluginReady;
    _exactAlarmGranted = exactAlarmGranted;
    _notificationPermissionGranted = notificationPermissionGranted;

    return NotificationInitResult(
      pluginReady: pluginReady,
      notificationPermissionGranted: notificationPermissionGranted,
      exactAlarmPermissionGranted: exactAlarmGranted,
    );
  }

  /// درخواست مجوزهای نوتیفیکیشن (پس از اولین فریم رابط کاربری).
  ///
  /// - اگر نمایش اعلان از قبل مجاز باشد چیزی پرسیده نمی‌شود.
  /// - نتیجه با [notifyListeners] اعلام می‌شود تا بنر رابط کاربری
  ///   بتواند در صورت ردِ مجوز نمایش یا پنهان شود.
  Future<void> requestPermissions() async {
    _permissionsRequested = true;

    if (!Platform.isAndroid) {
      // پلتفرم‌های دیگر مجوز اندرویدی ندارند.
      notifyListeners();
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      notifyListeners();
      return;
    }

    try {
      final enabled = await android.areNotificationsEnabled() ?? false;
      if (enabled) {
        _notificationPermissionGranted = true;
      } else {
        await android.requestNotificationsPermission();
        _notificationPermissionGranted =
            await android.areNotificationsEnabled() ?? false;
      }
    } catch (e) {
      debugPrint('خطا در درخواست مجوز نوتیفیکیشن: $e');
    }

    try {
      final canSchedule = await android.canScheduleExactNotifications();
      if (canSchedule == false) {
        await android.requestExactAlarmsPermission();
        _exactAlarmGranted =
            await android.canScheduleExactNotifications() ?? false;
      } else {
        _exactAlarmGranted = true;
      }
    } catch (e) {
      debugPrint('خطا در درخواست مجوز آلارم دقیق: $e');
    }

    notifyListeners();
  }

  Future<void> _initTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // در صورت شکست تشخیص خودکار، منطقهٔ زمانی پیش‌فرض تهران.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
    _timezoneReady = true;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        // حریم خصوصی: نام و دوز دارو روی قفل‌صفحه دیده نشود.
        visibility: NotificationVisibility.private,
      ),
      windows: WindowsNotificationDetails(),
    );
  }

  /// شناسهٔ پایدار نوتیفیکیشن زمان‌بندی‌شده بر اساس دارو + اندیس ساعت.
  static int scheduledNotificationId(int medicationId, int timeIndex) =>
      medicationId * 1000 + timeIndex;

  /// شناسهٔ نوتیفیکیشن درون‌برنامه‌ای (یادآوری فوری هنگام باز بودن اپ).
  ///
  /// بازهٔ جداگانهٔ `8_000_000+` تا با شناسه‌های زمان‌بندی‌شده برخورد
  /// نکند و با `hour * 60 + minute` دو ساعت متفاوت روی هم نیفتند.
  static int inAppNotificationId(int medicationId, int hour, int minute) =>
      8000000 + medicationId * 2000 + hour * 60 + minute;

  /// اولین وقوع آیندهٔ ساعت [hour:minute] (امروز یا فردا).
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(next, tz.local);
  }

  /// همگام‌سازی کامل زمان‌بندی نوتیفیکیشن‌ها با فهرست فعلی داروها.
  ///
  /// ابتدا همهٔ زمان‌بندی‌های قبلی لغو و سپس بر اساس [medications]
  /// از نو ساخته می‌شود؛ بنابراین افزودن/ویرایش/حذف دارو کافی است.
  ///
  /// فراخوانی‌ها **پشت سر هم** اجرا می‌شوند تا دو فراخوانی هم‌زمان (مثلاً
  /// ورود به تب «داروها» هم‌زمان با ذخیرهٔ یک دارو) لغوِ زمان‌بندیِ یکدیگر
  /// را وسطِ کار نبینند.
  Future<void> rescheduleAll(List<Medication> medications) {
    final run = _rescheduleChain
        .then((_) => _reschedule(medications))
        .catchError((Object e) {
      debugPrint('خطا در همگام‌سازی نوتیفیکیشن‌ها: $e');
    });
    _rescheduleChain = run;
    return run;
  }

  Future<void> _reschedule(List<Medication> medications) async {
    if (!_initialized) return;
    if (!_timezoneReady) await _initTimezone();

    // مجوز آلارم دقیق ممکن است بعد از آخرین بار در تنظیمات سیستم تغییر
    // کرده باشد؛ قبل از زمان‌بندی دوباره بررسی می‌شود.
    await _refreshExactAlarmPermission();

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('خطا در لغو زمان‌بندی‌های قبلی: $e');
    }

    for (final medication in medications) {
      final id = medication.id;
      if (id == null) continue;
      final times = medication.parsedTimes;
      for (var i = 0; i < times.length; i++) {
        final time = times[i];
        try {
          await _scheduleOne(
            medication: medication,
            id: id,
            timeIndex: i,
            hour: time.hour,
            minute: time.minute,
          );
        } catch (e) {
          debugPrint('خطا در زمان‌بندی نوتیفیکیشن ${medication.name}: $e');
        }
      }
    }
  }

  Future<void> _refreshExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      _exactAlarmGranted =
          await android.canScheduleExactNotifications() ?? _exactAlarmGranted;
    } catch (e) {
      debugPrint('خطا در تازه‌سازی مجوز آلارم دقیق: $e');
    }
  }

  Future<void> _scheduleOne({
    required Medication medication,
    required int id,
    required int timeIndex,
    required int hour,
    required int minute,
  }) async {
    final notificationId = scheduledNotificationId(id, timeIndex);
    final scheduledDate = _nextOccurrence(hour, minute);

    final text = _bodyFor(medication, hour, minute);

    if (Platform.isWindows) {
      // ویندوز فقط زمان‌بندی تکی دارد؛ تکرار در هر اجرای برنامه
      // با rescheduleAll پوشش داده می‌شود.
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'یادآوری داروی ${medication.name}',
        body: text,
        scheduledDate: scheduledDate,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'یادآوری داروی ${medication.name}',
      body: text,
      scheduledDate: scheduledDate,
      notificationDetails: _details(),
      androidScheduleMode: _exactAlarmGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'medication:$id',
    );
  }

  String _bodyFor(Medication medication, int hour, int minute) {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return 'نوبت مصرف رسید. دوز: ${medication.dose} — ساعت $hh:$mm';
  }

  /// نمایش فوری نوتیفیکیشن (برای یادآوری درون‌برنامه‌ای ویندوز).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('خطا در نمایش نوتیفیکیشن: $e');
    }
  }
}
