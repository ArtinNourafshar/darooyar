import 'package:flutter_test/flutter_test.dart';

import 'package:darooyar/core/notifications/notification_service.dart';

/// شناسه‌های نوتیفیکیشن باید یکتا باشند تا یک یادآوری جای دیگری را
/// لغو یا جایگزین نکند.
void main() {
  group('شناسهٔ زمان‌بندی‌شده', () {
    test('بر اساس دارو + اندیس ساعت محاسبه می‌شود', () {
      expect(NotificationService.scheduledNotificationId(1, 0), 1000);
      expect(NotificationService.scheduledNotificationId(1, 1), 1001);
      expect(NotificationService.scheduledNotificationId(2, 0), 2000);
    });

    test('برای داروهای مختلف یکتا است', () {
      final ids = {
        for (var med = 1; med <= 20; med++)
          for (var index = 0; index < 10; index++)
            NotificationService.scheduledNotificationId(med, index),
      };
      expect(ids.length, 20 * 10);
    });
  });

  group('شناسهٔ نوتیفیکیشن درون‌برنامه‌ای', () {
    test('ساعت کامل داخل اید هست؛ ۰۱:۳۰ و ۱۳:۳۰ روی هم نمی‌افتند', () {
      final early = NotificationService.inAppNotificationId(1, 1, 30);
      final afternoon = NotificationService.inAppNotificationId(1, 13, 30);
      expect(early, isNot(afternoon));
    });

    test('برای داروهای مختلف یکتا است', () {
      final ids = {
        for (var med = 1; med <= 50; med++)
          for (var hour = 0; hour < 24; hour++)
            for (var minute = 0; minute < 60; minute += 15)
              NotificationService.inAppNotificationId(med, hour, minute),
      };
      expect(ids.length, 50 * 24 * 4); // minute: ۰، ۱۵، ۳۰، ۴۵
    });

    test('با بازهٔ شناسه‌های زمان‌بندی‌شده برخورد نمی‌کند', () {
      for (var med = 1; med <= 100; med++) {
        final inApp = NotificationService.inAppNotificationId(med, 0, 0);
        final scheduled = NotificationService.scheduledNotificationId(med, 999);
        expect(inApp, greaterThan(scheduled), reason: 'داروی $med');
      }
    });
  });
}
