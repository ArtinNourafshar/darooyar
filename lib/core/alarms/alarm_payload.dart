/// پروتکل payload زنگ‌ها — منطق خالص و قابل تست.
///
/// payload نوتیفیکیشن:
/// `alarm|<kind>|<entityId>|<baseId>`
/// - kind: `med` یا `meal`
/// - entityId: شناسهٔ دارو یا وعده
/// - baseId: شناسهٔ پایهٔ نوتیفیکیشن (برای ساخت شناسهٔ چرت)
///
/// دکمه‌ها:
/// - اندروید: `actionId` برابر `alarm_stop` / `alarm_snooze` است.
/// - ویندوز: `payload` برابر `cmd:stop|<payload>` / `cmd:snooze|<payload>`
///   (در ویندوز، payload و actionId هر دو متن دکمه را می‌گیرند).
library;

/// نوع زنگ.
enum AlarmKind {
  med('med'),
  meal('meal');

  const AlarmKind(this.dbKey);
  final String dbKey;

  static AlarmKind? fromDbKey(String key) {
    for (final kind in values) {
      if (kind.dbKey == key) return kind;
    }
    return null;
  }
}

/// کنش دریافتی از نوتیفیکیشن زنگ.
enum AlarmAction {
  /// ضربه روی خود نوتیفیکیشن → باز کردن اپ.
  open,

  /// دکمهٔ «قطع زنگ».
  stop,

  /// دکمهٔ «چرت ۵ دقیقه».
  snooze,
}

/// payload رمزگشایی‌شدهٔ یک زنگ.
class AlarmPayload {
  const AlarmPayload({
    required this.kind,
    required this.entityId,
    required this.baseId,
  });

  final AlarmKind kind;
  final int entityId;

  /// شناسهٔ پایهٔ نوتیفیکیشن زمان‌بندی‌شده.
  final int baseId;

  String encode() => 'alarm|${kind.dbKey}|$entityId|$baseId';

  /// شناسهٔ نوتیفیکیشن چرت (یک‌بارمصرف، ۵ دقیقه بعد).
  int get snoozeId => baseId + NotificationIds.snoozeOffset;

  static AlarmPayload? tryParse(String? raw) {
    if (raw == null || !raw.startsWith('alarm|')) return null;
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final kind = AlarmKind.fromDbKey(parts[1]);
    final entityId = int.tryParse(parts[2]);
    final baseId = int.tryParse(parts[3]);
    if (kind == null || entityId == null || baseId == null) return null;
    return AlarmPayload(kind: kind, entityId: entityId, baseId: baseId);
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmPayload &&
      other.kind == kind &&
      other.entityId == entityId &&
      other.baseId == baseId;

  @override
  int get hashCode => Object.hash(kind, entityId, baseId);
}

/// نتیجهٔ کامل تحلیل یک پاسخ نوتیفیکیشن زنگ.
class AlarmResponse {
  const AlarmResponse({required this.payload, required this.action});

  final AlarmPayload payload;
  final AlarmAction action;
}

/// تبدیل پاسخ خام افزونه به [AlarmResponse].
///
/// اگر مربوط به زنگ نباشد null برمی‌گردد.
AlarmResponse? parseAlarmResponse({String? payload, String? actionId}) {
  if (payload == null) return null;

  // ویندوز: دکمه‌ها payload را با پیشوند cmd: می‌فرستند.
  if (payload.startsWith('cmd:')) {
    final separator = payload.indexOf('|');
    if (separator < 0) return null;
    final command = payload.substring(4, separator);
    final rest = payload.substring(separator + 1);
    final alarm = AlarmPayload.tryParse(rest);
    if (alarm == null) return null;
    final action = switch (command) {
      'stop' => AlarmAction.stop,
      'snooze' => AlarmAction.snooze,
      _ => null,
    };
    if (action == null) return null;
    return AlarmResponse(payload: alarm, action: action);
  }

  final alarm = AlarmPayload.tryParse(payload);
  if (alarm == null) return null;

  // اندروید: شناسهٔ دکمه در actionId می‌آید.
  final action = switch (actionId) {
    NotificationIds.stopAction => AlarmAction.stop,
    NotificationIds.snoozeAction => AlarmAction.snooze,
    _ => AlarmAction.open,
  };
  return AlarmResponse(payload: alarm, action: action);
}

/// شناسه‌ها و کنش‌های مشترک زنگ‌ها.
abstract final class NotificationIds {
  /// آفست شناسهٔ چرت نسبت به شناسهٔ پایه.
  static const int snoozeOffset = 20000000;

  /// آفست هر «کپی روز» در زمان‌بندی ۷ روزهٔ ویندوز.
  ///
  /// باید از بزرگ‌ترین شناسهٔ پایه بزرگ‌تر باشد تا کپی‌ها با شناسه‌های
  /// روز صفر (و با فضای چرت/درون‌برنامه) برخورد نکنند.
  static const int windowsDayStride = 40000000;

  /// تعداد روزهایی که زنگ‌های ویندوز از هم‌اکنون جلوتر زمان‌بندی می‌شوند
  /// (ویندوز زمان‌بندی تکی دارد).
  static const int windowsLookaheadDays = 7;

  /// کپی روزِ [dayOffset] (۰ تا ۶) از یک زنگ در ویندوز.
  static int windowsDayId(int baseId, int dayOffset) =>
      baseId + (dayOffset + 1) * windowsDayStride;

  /// شناسهٔ زمان‌بندی‌شدهٔ نوبت دارو (دارو × اندیس ساعت).
  static int scheduledNotificationId(int medicationId, int timeIndex) =>
      medicationId * 1000 + timeIndex;

  /// شناسهٔ زمان‌بندی‌شدهٔ وعدهٔ غذایی (بازهٔ ۴ میلیونی جدا).
  static int mealNotificationId(int mealId) => 4000000 + mealId;

  /// شناسهٔ نوتیفیکیشن درون‌برنامه‌ای (بازهٔ ۸ میلیونی جدا).
  static int inAppNotificationId(int medicationId, int hour, int minute) =>
      8000000 + medicationId * 2000 + hour * 60 + minute;

  static const String stopAction = 'alarm_stop';
  static const String snoozeAction = 'alarm_snooze';
}
