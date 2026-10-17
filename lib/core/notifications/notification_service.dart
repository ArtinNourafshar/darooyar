import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:darooyar/core/alarms/alarm_payload.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/meals/meal.dart';

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

/// سرویس زنگ و یادآوری با نوتیفیکیشن محلی.
///
/// رفتار زنگ (مشابه ساعت زنگ‌دار):
/// - **اندروید**: زمان‌بندی دقیق (`exactAllowWhileIdle` + تکرار روزانه)،
///   کانال با صدای `alarm_beep.wav`، نوتیفیکیشن تمام‌صفحه (`fullScreenIntent`)
///   و دکمه‌های «قطع زنگ» و «چرت ۵ دقیقه». صدا تا قطع توسط کاربر ادامه دارد.
/// - **ویندوز**: toast با `scenario=alarm` که صدای حلقه‌ای سیستم را تا
///   دستی قطع کردن اجرا می‌کند. زمان‌بندی ویندوز تکی است، بنابراین برای
///   ۷ روز آینده به‌ازای هر نوبت کپی جدا زمان‌بندی می‌شود تا بدون باز
///   کردن اپ هم زنگ بزند.
/// - **چرت**: یک نوتیفیکیشن تک‌بارمصرف ۵ دقیقه بعد (فضای شناسهٔ جدا).
/// - **توقف**: هر تعاملی (دکمهٔ قطع، ضربه یا کنار کشیدن) زنگ را خاتمه می‌دهد؛
///   سری زمان‌بندی فردا بلافاصله دوباره ساخته می‌شود.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _alarmChannelId = 'darooyar_alarms';
  static const String _alarmChannelName = 'زنگ دارو و وعدهٔ غذایی';
  static const String _alarmChannelDescription =
      'زنگ دقیق یادآوری دارو و وعده‌های غذایی با صدای ادامه‌دار تا قطع توسط شما';

  /// کانال قدیمی/ساده برای نوتیفیکیشن‌های درون‌برنامه‌ای (بدون زنگ).
  static const String _reminderChannelId = 'darooyar_reminders';
  static const String _reminderChannelName = 'یادآوری دارو';
  static const String _reminderChannelDescription =
      'یادآوری زمان مصرف داروهای خانواده';

  /// شناسه‌های ثبت نوتیفیکیشن ویندوز (باید ثابت بمانند).
  static const String _windowsGuid = '7c1e4f60-9a2b-4d58-b3c7-2f8e51a94d16';
  static const String _windowsAppUserModelId = 'Com.Darooyar.FamilyReminder';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  AndroidNotificationDetails? _androidAlarm;
  AndroidNotificationDetails? _androidReminder;

  List<Medication> _lastMedications = const [];
  List<MealTime> _lastMeals = const [];

  bool _initialized = false;
  bool _permissionsRequested = false;
  bool? _notificationPermissionGranted;
  bool? _exactAlarmGranted;

  Future<void> _chain = Future.value();

  /// با ضربه روی نوتیفیکیشن (بدون دکمه) فراخوانی می‌شود.
  void Function(String? payload)? onNotificationTapped;

  bool get permissionsRequested => _permissionsRequested;

  /// آیا مجوز نمایش نوتیفیکیشن داده شده است؟
  bool get hasNotificationPermission =>
      _notificationPermissionGranted ?? _defaultTrue;

  /// آیا مجوز زنگ دقیق داده شده است؟
  bool get hasExactAlarmPermission => _exactAlarmGranted ?? _defaultTrue;

  /// نام‌های سازگار برای فراخواننده‌های موجود (بنر مجوز در پوسته).
  bool get notificationPermissionGranted => hasNotificationPermission;
  bool get exactAlarmPermissionGranted => hasExactAlarmPermission;

  /// در پلتفرم‌های بدون مفهوم مجوز (ویندوز) پیش‌فرض true است.
  static bool get _defaultTrue => !Platform.isAndroid;

  // ── مقداردهی اولیه ────────────────────────────────────────────────

  Future<NotificationInitResult> init() async {
    await _initTimeZone();
    await _initPlugin();

    if (!_initialized) {
      return const NotificationInitResult(
        pluginReady: false,
        notificationPermissionGranted: false,
        exactAlarmPermissionGranted: false,
      );
    }

    await _refreshPermissionState();
    _permissionsRequested = hasNotificationPermission;

    return NotificationInitResult(
      pluginReady: true,
      notificationPermissionGranted: hasNotificationPermission,
      exactAlarmPermissionGranted: hasExactAlarmPermission,
    );
  }

  Future<void> _initTimeZone() async {
    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('خطا در منطقهٔ زمانی: $e — پیش‌فرض: تهران');
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.UTC);
        } catch (_) {}
      }
    }
  }

  Future<void> _initPlugin() async {
    try {
      final initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: const WindowsInitializationSettings(
          appName: 'دارویار',
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsGuid,
        ),
      );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _ensureChannels();
      _initialized = true;
    } catch (e) {
      debugPrint('خطا در مقداردهی اولیهٔ نوتیفیکیشن: $e');
      _initialized = false;
    }
  }

  Future<void> _ensureChannels() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _alarmChannelId,
          _alarmChannelName,
          description: _alarmChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alarm_beep'),
          vibrationPattern: Int64List.fromList(<int>[0, 500, 250, 500]),
        ),
      );
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: _reminderChannelDescription,
          importance: Importance.high,
        ),
      );
    } catch (e) {
      debugPrint('خطا در ساخت کانال نوتیفیکیشن: $e');
    }
  }

  // ── مجوزها ────────────────────────────────────────────────────────

  Future<void> _refreshPermissionState() async {
    if (!Platform.isAndroid || !_initialized) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      final enabled = await android.areNotificationsEnabled();
      if (enabled != null) _notificationPermissionGranted = enabled;
    } catch (e) {
      debugPrint('خطا در بررسی مجوز نوتیفیکیشن: $e');
    }
    await _refreshExactAlarmPermission();
  }

  Future<void> _refreshExactAlarmPermission() async {
    if (!Platform.isAndroid || !_initialized) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      _exactAlarmGranted =
          await android.canScheduleExactNotifications() ?? _exactAlarmGranted;
    } catch (e) {
      debugPrint('خطا در بررسی مجوز آلارم دقیق: $e');
    }
  }

  /// درخواست مجوزها پس از بالا آمدن اپ (فقط اندروید).
  Future<void> requestPermissions() async {
    if (!Platform.isAndroid || !_initialized) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (granted != null) _notificationPermissionGranted = granted;
      _permissionsRequested = true;
      await _refreshExactAlarmPermission();
      notifyListeners();
    } catch (e) {
      debugPrint('خطا در درخواست مجوز: $e');
    }
  }

  // ── جزئیات نوتیفیکیشن ─────────────────────────────────────────────

  AndroidNotificationDetails get _alarmAndroid =>
      _androidAlarm ??= AndroidNotificationDetails(
        _alarmChannelId,
        _alarmChannelName,
        channelDescription: _alarmChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.private,
        actions: [
          AndroidNotificationAction(
            NotificationIds.stopAction,
            'قطع زنگ',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationIds.snoozeAction,
            'چرت ۵ دقیقه',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
      );

  AndroidNotificationDetails get _reminderAndroid =>
      _androidReminder ??= AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  /// جزئیات ویندوز برای هر زنگ (دکمه‌ها باید payload خود نوتیفیکیشن را
  /// در arguments حمل کنند؛ به همین دلیل per-notification ساخته می‌شود).
  WindowsNotificationDetails _alarmWindows(String payload) {
    return WindowsNotificationDetails(
      audio: WindowsNotificationAudio.preset(
        sound: WindowsNotificationSound.alarm1,
        shouldLoop: true,
      ),
      scenario: WindowsNotificationScenario.alarm,
      actions: [
        WindowsAction(
          content: 'قطع',
          arguments: 'cmd:stop|$payload',
          activationBehavior: WindowsNotificationBehavior.dismiss,
        ),
        WindowsAction(
          content: 'چرت ۵ دقیقه',
          arguments: 'cmd:snooze|$payload',
        ),
      ],
    );
  }

  NotificationDetails _alarmDetails(String payload) {
    return NotificationDetails(
      android: Platform.isAndroid ? _alarmAndroid : null,
      windows: Platform.isWindows ? _alarmWindows(payload) : null,
    );
  }

  NotificationDetails _reminderDetails() {
    return NotificationDetails(
      android: Platform.isAndroid ? _reminderAndroid : null,
      windows: Platform.isWindows ? WindowsNotificationDetails() : null,
    );
  }

  // ── زمان‌بندی ─────────────────────────────────────────────────────

  /// زمان‌بندی دوبارهٔ همهٔ زنگ‌ها (دارو + وعده‌های غذایی).
  ///
  /// هر فهرستِ داده‌نشده از آخرین حالت نگه‌داشته‌شده استفاده می‌شود؛
  /// بنابراین فراخوانی با هر یک از دو فهرست کافی است.
  Future<void> rescheduleAll({
    List<Medication>? medications,
    List<MealTime>? meals,
  }) {
    if (medications != null) _lastMedications = medications;
    if (meals != null) _lastMeals = meals;

    if (!_initialized) return Future.value();

    // زنجیرهٔ سریال: همگام‌سازی‌های پشت‌سرهم روی هم نیفتند.
    _chain = _chain
        .catchError((Object e) {
          debugPrint('خطا در زنجیرهٔ زمان‌بندی: $e');
        })
        .then((_) => _reschedule());
    return _chain;
  }

  Future<void> _reschedule() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('خطا در پاک‌سازی زمان‌بندی قبلی: $e');
    }

    for (final medication in _lastMedications) {
      final medId = medication.id;
      if (medId == null) continue;
      for (var i = 0; i < medication.times.length; i++) {
        final parts = medication.times[i].split(':');
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        await _scheduleAlarm(
          kind: AlarmKind.med,
          entityId: medId,
          baseId: NotificationIds.scheduledNotificationId(medId, i),
          hour: hour,
          minute: minute,
          title: 'یادآوری داروی ${medication.name}',
          body: _medBody(medication, hour, minute),
        );
      }
    }

    for (final meal in _lastMeals) {
      final mealId = meal.id;
      if (mealId == null || !meal.enabled) continue;
      final parts = meal.time.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      await _scheduleAlarm(
        kind: AlarmKind.meal,
        entityId: mealId,
        baseId: NotificationIds.mealNotificationId(mealId),
        hour: hour,
        minute: minute,
        title: 'وعدهٔ غذایی: ${meal.name}',
        body: 'زمان ${meal.name} رسیده است — ساعت '
            '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}',
      );
    }
  }

  String _medBody(Medication medication, int hour, int minute) {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return 'نوبت مصرف رسید. دوز: ${medication.dose} — ساعت $hh:$mm';
  }

  /// زمان‌بندی یک زنگ روزانه (یا کپی‌های روزهای آینده در ویندوز).
  Future<void> _scheduleAlarm({
    required AlarmKind kind,
    required int entityId,
    required int baseId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final payload = AlarmPayload(
      kind: kind,
      entityId: entityId,
      baseId: baseId,
    ).encode();

    try {
      if (Platform.isWindows) {
        // ویندوز زمان‌بندی تکی دارد؛ کپی ۷ روز آینده زنگ را بدون باز
        // کردن اپ هم تضمین می‌کند.
        for (var dayOffset = 0;
            dayOffset < NotificationIds.windowsLookaheadDays;
            dayOffset++) {
          final when = _occurrenceOnDay(
            DateTime.now().add(Duration(days: dayOffset)),
            hour,
            minute,
          );
          if (when == null) continue;
          await _plugin.zonedSchedule(
            id: NotificationIds.windowsDayId(baseId, dayOffset),
            title: title,
            body: body,
            scheduledDate: when,
            notificationDetails: _alarmDetails(payload),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        }
        return;
      }

      await _plugin.zonedSchedule(
        id: baseId,
        title: title,
        body: body,
        scheduledDate: _nextOccurrence(hour, minute),
        notificationDetails: _alarmDetails(payload),
        androidScheduleMode: _exactAlarmGranted ?? true
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      debugPrint('خطا در زمان‌بندی زنگ ($title): $e');
    }
  }

  /// نخستین زمانِ آیندهٔ امروز/فردا در ساعت داده‌شده.
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// زمانِ ساعت داده‌شده در روز مشخص؛ اگر گذشته باشد null.
  tz.TZDateTime? _occurrenceOnDay(DateTime day, int hour, int minute) {
    final when =
        tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);
    return when.isAfter(tz.TZDateTime.now(tz.local)) ? when : null;
  }

  // ── واکنش به تعامل کاربر ─────────────────────────────────────────

  void _handleResponse(NotificationResponse response) {
    final parsed = parseAlarmResponse(
      payload: response.payload,
      actionId: response.actionId,
    );

    if (parsed == null) {
      onNotificationTapped?.call(response.payload);
      return;
    }

    switch (parsed.action) {
      case AlarmAction.open:
        onNotificationTapped?.call(response.payload);
      case AlarmAction.stop:
        unawaited(_stopAlarm(response.id, parsed.payload));
      case AlarmAction.snooze:
        unawaited(_snoozeAlarm(parsed.payload));
    }
  }

  /// قطع زنگ + بازسازی زمان‌بندی فردا/آیندهٔ همان نوبت.
  Future<void> _stopAlarm(int? notificationId, AlarmPayload alarm) async {
    if (notificationId != null) {
      try {
        await _plugin.cancel(id: notificationId);
      } catch (e) {
        debugPrint('خطا در قطع زنگ: $e');
      }
    }
    await _rearmEntity(alarm);
  }

  Future<void> _snoozeAlarm(AlarmPayload alarm) async {
    final title = alarm.kind == AlarmKind.med
        ? 'چرت: یادآوری دارو'
        : 'چرت: وعدهٔ غذایی';
    final body = 'زنگ دوباره ۵ دقیقهٔ دیگر به صدا در می‌آید.';

    try {
      await _plugin.zonedSchedule(
        id: alarm.snoozeId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(
          const Duration(minutes: 5),
        ),
        notificationDetails: _alarmDetails(alarm.encode()),
        androidScheduleMode: _exactAlarmGranted ?? true
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: alarm.encode(),
      );
    } catch (e) {
      debugPrint('خطا در زمان‌بندی چرت: $e');
    }
  }

  /// ساخت دوبارهٔ زمان‌بندی یک دارو/وعده از فهرست نگه‌داشته‌شده.
  Future<void> _rearmEntity(AlarmPayload alarm) async {
    switch (alarm.kind) {
      case AlarmKind.med:
        for (final medication in _lastMedications) {
          if (medication.id != alarm.entityId) continue;
          for (var i = 0; i < medication.times.length; i++) {
            final parts = medication.times[i].split(':');
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            if (hour == null || minute == null) continue;
            await _scheduleAlarm(
              kind: AlarmKind.med,
              entityId: alarm.entityId,
              baseId: NotificationIds.scheduledNotificationId(
                alarm.entityId,
                i,
              ),
              hour: hour,
              minute: minute,
              title: 'یادآوری داروی ${medication.name}',
              body: _medBody(medication, hour, minute),
            );
          }
        }
      case AlarmKind.meal:
        for (final meal in _lastMeals) {
          if (meal.id != alarm.entityId || !meal.enabled) continue;
          final parts = meal.time.split(':');
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null || minute == null) continue;
          await _scheduleAlarm(
            kind: AlarmKind.meal,
            entityId: alarm.entityId,
            baseId: NotificationIds.mealNotificationId(alarm.entityId),
            hour: hour,
            minute: minute,
            title: 'وعدهٔ غذایی: ${meal.name}',
            body: 'زمان ${meal.name} رسیده است — ساعت '
                '${hour.toString().padLeft(2, '0')}:'
                '${minute.toString().padLeft(2, '0')}',
          );
        }
    }
  }

  /// نمایش فوری نوتیفیکیشن ساده (بدون زنگ؛ برای یادآوری درون‌برنامه‌ای).
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
        notificationDetails: _reminderDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('خطا در نمایش نوتیفیکیشن: $e');
    }
  }
}

/// واکنش به دکمه‌های زنگ از isolate پس‌زمینه (وقتی اپ بسته است).
///
/// «قطع» از قبل توسط خود سیستم انجام شده (نوتیفیکیشن لغو می‌شود)؛
/// فقط «چرت» نیاز به زمان‌بندی دارد و همین‌جا انجام می‌شود.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  final parsed = parseAlarmResponse(
    payload: response.payload,
    actionId: response.actionId,
  );
  if (parsed == null || parsed.action != AlarmAction.snooze) return;

  final plugin = FlutterLocalNotificationsPlugin();
  try {
    try {
      tz_data.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      } catch (_) {}
    }

    await plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: const WindowsInitializationSettings(
          appName: 'دارویار',
          appUserModelId: 'Com.Darooyar.FamilyReminder',
          guid: '7c1e4f60-9a2b-4d58-b3c7-2f8e51a94d16',
        ),
      ),
    );

    final alarm = parsed.payload;
    final payload = alarm.encode();
    await plugin.zonedSchedule(
      id: alarm.snoozeId,
      title: alarm.kind == AlarmKind.med
          ? 'چرت: یادآوری دارو'
          : 'چرت: وعدهٔ غذایی',
      body: 'زنگ دوباره ۵ دقیقهٔ دیگر به صدا در می‌آید.',
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)),
      notificationDetails: NotificationDetails(
        android: Platform.isAndroid
            ? const AndroidNotificationDetails(
                'darooyar_alarms',
                'زنگ دارو و وعدهٔ غذایی',
                channelDescription:
                    'زنگ دقیق یادآوری دارو و وعده‌های غذایی با صدای ادامه‌دار تا قطع توسط شما',
                importance: Importance.max,
                priority: Priority.max,
                fullScreenIntent: true,
                autoCancel: true,
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.private,
              )
            : null,
        windows: Platform.isWindows
            ? WindowsNotificationDetails(
                audio: WindowsNotificationAudio.preset(
                  sound: WindowsNotificationSound.alarm1,
                  shouldLoop: true,
                ),
                scenario: WindowsNotificationScenario.alarm,
              )
            : null,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  } catch (e) {
    debugPrint('خطا در زمان‌بندی چرت از پس‌زمینه: $e');
  }
}
