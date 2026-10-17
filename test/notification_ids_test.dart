import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/core/alarms/alarm_payload.dart';

/// شناسه‌های نوتیفیکیشن باید یکتا باشند تا یک یادآوری جای دیگری را
/// لغو یا جایگزین نکند — دارو، وعدهٔ غذایی، چرت و کپی روزهای ویندوز.
void main() {
  group('شناسهٔ زمان‌بندی‌شدهٔ دارو', () {
    test('بر اساس دارو + اندیس ساعت محاسبه می‌شود', () {
      expect(NotificationIds.scheduledNotificationId(1, 0), 1000);
      expect(NotificationIds.scheduledNotificationId(1, 1), 1001);
      expect(NotificationIds.scheduledNotificationId(2, 0), 2000);
    });

    test('برای داروهای مختلف یکتا است', () {
      final ids = {
        for (var med = 1; med <= 20; med++)
          for (var index = 0; index < 10; index++)
            NotificationIds.scheduledNotificationId(med, index),
      };
      expect(ids.length, 20 * 10);
    });
  });

  group('شناسهٔ وعدهٔ غذایی', () {
    test('در بازهٔ ۴ میلیونی جدا از داروهاست', () {
      expect(NotificationIds.mealNotificationId(1), 4000001);
      expect(NotificationIds.mealNotificationId(9999), 4009999);
    });

    test('با شناسه‌های دارو برخورد نمی‌کند', () {
      // بزرگ‌ترین شناسهٔ معقول دارو (۴۰۰۰ دارو × ساعت‌ها) زیر ۴ میلیون است.
      final maxMed = NotificationIds.scheduledNotificationId(3999, 999);
      expect(maxMed, lessThan(NotificationIds.mealNotificationId(1)));
    });
  });

  group('شناسهٔ درون‌برنامه‌ای', () {
    test('ساعت کامل داخل اید هست؛ ۰۱:۳۰ و ۱۳:۳۰ روی هم نمی‌افتند', () {
      final early = NotificationIds.inAppNotificationId(1, 1, 30);
      final afternoon = NotificationIds.inAppNotificationId(1, 13, 30);
      expect(early, isNot(afternoon));
    });

    test('برای داروهای مختلف یکتا است', () {
      final ids = {
        for (var med = 1; med <= 50; med++)
          for (var hour = 0; hour < 24; hour++)
            for (var minute = 0; minute < 60; minute += 15)
              NotificationIds.inAppNotificationId(med, hour, minute),
      };
      expect(ids.length, 50 * 24 * 4); // minute: ۰، ۱۵، ۳۰، ۴۵
    });

    test('با بازهٔ شناسه‌های زمان‌بندی‌شده برخورد نمی‌کند', () {
      for (var med = 1; med <= 100; med++) {
        final inApp = NotificationIds.inAppNotificationId(med, 0, 0);
        final scheduled = NotificationIds.scheduledNotificationId(med, 999);
        expect(inApp, greaterThan(scheduled), reason: 'داروی $med');
      }
    });
  });

  group('چرت و کپی روزهای ویندوز', () {
    test('شناسهٔ چرت از شناسهٔ پایه جدا است', () {
      final base = NotificationIds.scheduledNotificationId(3, 2);
      final snoozed = base + NotificationIds.snoozeOffset;
      expect(snoozed, greaterThan(base));

      // باند چرت بالاتر از همهٔ بازه‌های پایه (دارو/وعده/درون‌برنامه) می‌نشیند.
      final minSnoozed = NotificationIds.scheduledNotificationId(1, 0) +
          NotificationIds.snoozeOffset;
      expect(minSnoozed, greaterThan(NotificationIds.mealNotificationId(9999)));
      expect(
        minSnoozed,
        greaterThan(NotificationIds.inAppNotificationId(3999, 23, 59)),
      );
      // ...و پایین‌تر از نخستین کپی روز ویندوز می‌ماند.
      final maxSnoozed = NotificationIds.scheduledNotificationId(3999, 999) +
          NotificationIds.snoozeOffset;
      expect(maxSnoozed, lessThan(NotificationIds.windowsDayId(0, 0)));

      // با هیچ شناسهٔ پایهٔ دیگری برابر نمی‌شود.
      expect(snoozed, isNot(NotificationIds.scheduledNotificationId(23, 2)));
      expect(snoozed, isNot(NotificationIds.mealNotificationId(3)));
    });

    test('کپی روزها نه با روز صفر و نه با چرت برخورد دارد', () {
      for (var med = 1; med <= 50; med++) {
        for (var index = 0; index < 5; index++) {
          final base = NotificationIds.scheduledNotificationId(med, index);
          for (var day = 0;
              day < NotificationIds.windowsLookaheadDays;
              day++) {
            final copy = NotificationIds.windowsDayId(base, day);
            expect(copy, isNot(base), reason: 'دارو $med روز $day');
            expect(
              copy,
              isNot(base + NotificationIds.snoozeOffset),
              reason: 'دارو $med روز $day',
            );
          }
        }
      }
    });

    test('همهٔ کپی‌های ۷ روزهٔ همهٔ نوبت‌ها یکتا هستند', () {
      final ids = <int>{};
      for (var med = 1; med <= 30; med++) {
        for (var index = 0; index < 4; index++) {
          final base = NotificationIds.scheduledNotificationId(med, index);
          ids.add(base);
          for (var day = 0; day < 7; day++) {
            ids.add(NotificationIds.windowsDayId(base, day));
          }
        }
      }
      expect(ids.length, 30 * 4 * 8); // روز صفر + ۷ کپی
    });
  });

  group('payload زنگ', () {
    test('encode/decode پایه‌ها را حفظ می‌کند', () {
      const alarm = AlarmPayload(
        kind: AlarmKind.med,
        entityId: 7,
        baseId: 7000,
      );
      final parsed = AlarmPayload.tryParse(alarm.encode());
      expect(parsed, alarm);
      expect(parsed!.snoozeId, 7000 + NotificationIds.snoozeOffset);
    });

    test('برای وعدهٔ غذایی هم درست کار می‌کند', () {
      const alarm = AlarmPayload(
        kind: AlarmKind.meal,
        entityId: 3,
        baseId: 4000003,
      );
      final parsed = AlarmPayload.tryParse(alarm.encode());
      expect(parsed, alarm);
    });

    test('رشته‌های خراب یا غیرزنگ null می‌شوند', () {
      expect(AlarmPayload.tryParse(null), isNull);
      expect(AlarmPayload.tryParse(''), isNull);
      expect(AlarmPayload.tryParse('medication:5'), isNull);
      expect(AlarmPayload.tryParse('alarm|med|1'), isNull);
      expect(AlarmPayload.tryParse('alarm|xxx|1|1'), isNull);
      expect(AlarmPayload.tryParse('alarm|med|abc|1'), isNull);
    });
  });

  group('تحلیل پاسخ نوتیفیکیشن', () {
    const alarm = AlarmPayload(kind: AlarmKind.med, entityId: 2, baseId: 2000);

    test('ضربهٔ معمولی = باز کردن اپ (اندروید)', () {
      final parsed = parseAlarmResponse(payload: alarm.encode());
      expect(parsed!.action, AlarmAction.open);
      expect(parsed.payload, alarm);
    });

    test('دکمه‌ها در اندروید از actionId می‌آیند', () {
      final stop = parseAlarmResponse(
        payload: alarm.encode(),
        actionId: NotificationIds.stopAction,
      );
      expect(stop!.action, AlarmAction.stop);
      expect(stop.payload, alarm);

      final snooze = parseAlarmResponse(
        payload: alarm.encode(),
        actionId: NotificationIds.snoozeAction,
      );
      expect(snooze!.action, AlarmAction.snooze);
      expect(snooze.payload.baseId, alarm.baseId);
    });

    test('دکمه‌ها در ویندوز از payload با پیشوند cmd می‌آیند', () {
      final stop = parseAlarmResponse(payload: 'cmd:stop|${alarm.encode()}');
      expect(stop!.action, AlarmAction.stop);
      expect(stop.payload, alarm);

      final snooze = parseAlarmResponse(payload: 'cmd:snooze|${alarm.encode()}');
      expect(snooze!.action, AlarmAction.snooze);
    });

    test('payload غیرزنگ یا cmd نامعتبر null می‌شود', () {
      expect(parseAlarmResponse(payload: 'medication:3'), isNull);
      expect(parseAlarmResponse(payload: 'cmd:delete|${alarm.encode()}'), isNull);
      expect(parseAlarmResponse(payload: 'cmd:stop|not-an-alarm'), isNull);
      expect(parseAlarmResponse(payload: null), isNull);
    });
  });
}
