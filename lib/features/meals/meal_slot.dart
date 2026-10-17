import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/meals/meal.dart';
import 'package:darooyar/features/schedule/dose_log.dart';

/// یک کارت وعدهٔ غذایی در یک روز مشخص.
class MealSlot {
  const MealSlot({
    required this.mealId,
    required this.name,
    required this.timeKey,
    required this.dateKey,
    required this.scheduledAt,
    required this.status,
  });

  final int mealId;
  final String name;

  /// ساعت وعده به کلید «HH:mm».
  final String timeKey;

  /// کلید روز «yyyy-MM-dd».
  final String dateKey;
  final DateTime scheduledAt;

  /// از همان وضعیت نوبت دارو استفاده می‌کنیم تا برچسب‌ها و نشان‌ها
  /// (خوردم/نخوردم، مصرف نشده، در انتظار) یکسان بمانند.
  final DoseStatus status;

  String get timeLabel => PersianUtils.formatTimeString(timeKey);
}

/// سازندهٔ نوبت‌های وعده‌های غذایی برای یک روز.
///
/// قواعد:
/// - وعده‌ای که هنوز ثبت نشده (`createdAt` جلوتر) نادیده گرفته می‌شود.
/// - نوبت‌های پیش از لحظهٔ ثبتِ وعده حذف می‌شوند (مگر سابقه داشته باشند).
/// - سابقهٔ ثبت‌شده → eaten/skipped؛ زمان گذشته → missed؛ آینده → upcoming.
abstract final class MealSlotBuilder {
  static List<MealSlot> build({
    required List<MealTime> meals,
    required Map<int, MealLog> logs,
    required DateTime now,
    required String dateKey,
  }) {
    final slots = <MealSlot>[];

    for (final meal in meals) {
      if (!meal.enabled) continue;
      final id = meal.id;
      if (id == null) continue;
      if (meal.createdAt.compareTo(dateKey) > 0) continue;

      final createdMoment =
          PersianUtils.dateTimeFromKey(meal.createdAt, meal.createdTime);
      final log = logs[id];

      final scheduledAt = PersianUtils.dateTimeFromKey(dateKey, meal.time);
      if (log == null && scheduledAt.isBefore(createdMoment)) continue;

      final DoseStatus status;
      if (log != null) {
        status = log.asDoseStatus;
      } else {
        status = scheduledAt.isAfter(now) ? DoseStatus.upcoming : DoseStatus.missed;
      }

      slots.add(MealSlot(
        mealId: id,
        name: meal.name,
        timeKey: meal.time,
        dateKey: dateKey,
        scheduledAt: scheduledAt,
        status: status,
      ));
    }

    slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return slots;
  }
}
