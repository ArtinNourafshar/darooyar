import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/core/utils/persian_utils.dart';

/// یک نوبت مصرف محاسبه‌شده برای یک دارو در یک روزِ مشخص.
class DoseSlot {
  const DoseSlot({
    required this.medicationId,
    required this.profileId,
    required this.medicationName,
    required this.dose,
    required this.profileName,
    required this.profileColorValue,
    required this.dateKey,
    required this.timeKey,
    required this.scheduledAt,
    required this.status,
  });

  final int medicationId;
  final int profileId;
  final String medicationName;
  final String dose;
  final String profileName;
  final int profileColorValue;
  final String dateKey;
  final String timeKey;
  final DateTime scheduledAt;
  final DoseStatus status;

  bool get isConfirmed => status == DoseStatus.taken || status == DoseStatus.skipped;

  /// کلید یکتای نوبت در پایگاه‌داده: «medicationId|logTime»
  String get logKey => '$medicationId|$timeKey';

  String get timeLabel => PersianUtils.formatTimeString(timeKey);

  DoseSlot copyWith({DoseStatus? status}) => DoseSlot(
        medicationId: medicationId,
        profileId: profileId,
        medicationName: medicationName,
        dose: dose,
        profileName: profileName,
        profileColorValue: profileColorValue,
        dateKey: dateKey,
        timeKey: timeKey,
        scheduledAt: scheduledAt,
        status: status ?? this.status,
      );
}

/// محاسبهٔ نوبت‌های یک روز از روی داروها + سابقهٔ مصرف.
///
/// این منطق بین صفحهٔ «امروز» و صفحهٔ «گزارش» مشترک است تا آمار
/// همیشه یکسان باشد.
abstract final class DoseSlotBuilder {
  /// ساخت نوبت‌های [dateKey].
  ///
  /// - داروهایی که در [dateKey] هنوز ثبت نشده‌اند (`createdAt` جلوتر) نادیده
  ///   گرفته می‌شوند.
  /// - نوبت‌هایی از روزِ ثبتِ دارو که پیش از لحظهٔ ثبت (`createdAt` +
  ///   `createdTime`) برنامه‌ریزی شده‌اند نیز حذف می‌شوند؛ دارویی که ساعت ۱۵
  ///   ثبت شده نباید نوبت ۰۸ همان روز را «مصرف نشده» ببیند.
  /// - اگر سابقهٔ مصرف وجود داشته باشد وضعیت taken/skipped است؛
  ///   در غیر این صورت زمان گذشته → missed و زمان آینده → upcoming.
  static List<DoseSlot> build({
    required List<Medication> medications,
    required List<Profile> profiles,
    required Map<String, DoseLog> logs,
    required String dateKey,
    required DateTime now,
    int? profileFilterId,
  }) {
    final profileById = {for (final p in profiles) p.id: p};
    final slots = <DoseSlot>[];

    for (final medication in medications) {
      if (profileFilterId != null && medication.profileId != profileFilterId) {
        continue;
      }
      if (medication.id == null) continue;
      // دارویی که هنوز در این تاریخ ثبت نشده نوبتی ندارد.
      if (medication.createdAt.compareTo(dateKey) > 0) continue;

      final profile = profileById[medication.profileId];
      final profileName = profile?.name ?? '—';
      final profileColor = profile?.colorValue ?? 0xFF8A8A8A;

      // لحظهٔ دقیق ثبت دارو (فقط برای روز ثبت اهمیت دارد).
      final createdMoment = PersianUtils.dateTimeFromKey(
        medication.createdAt,
        medication.createdTime,
      );

      for (final timeKey in medication.times) {
        final scheduledAt = PersianUtils.dateTimeFromKey(dateKey, timeKey);
        final log = logs['${medication.id}|$timeKey'];

        // نوبتی که پیش از ثبت دارو بوده و سابقه‌ای هم ندارد، نوبت معتبری
        // نیست و نباید «مصرف نشده» شمرده شود.
        if (log == null && scheduledAt.isBefore(createdMoment)) continue;

        final DoseStatus status;
        if (log != null) {
          status = log.isTaken ? DoseStatus.taken : DoseStatus.skipped;
        } else if (scheduledAt.isAfter(now)) {
          status = DoseStatus.upcoming;
        } else {
          status = DoseStatus.missed;
        }

        slots.add(DoseSlot(
          medicationId: medication.id!,
          profileId: medication.profileId,
          medicationName: medication.name,
          dose: medication.dose,
          profileName: profileName,
          profileColorValue: profileColor,
          dateKey: dateKey,
          timeKey: timeKey,
          scheduledAt: scheduledAt,
          status: status,
        ));
      }
    }

    slots.sort((a, b) {
      final byTime = a.timeKey.compareTo(b.timeKey);
      if (byTime != 0) return byTime;
      final byName = a.medicationName.compareTo(b.medicationName);
      if (byName != 0) return byName;
      return a.profileName.compareTo(b.profileName);
    });
    return slots;
  }
}
