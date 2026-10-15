import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication_repository.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_repository.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// برنامهٔ امروز: محاسبهٔ نوبت‌ها، تأیید «خوردم/نخوردم»، نوار پیشرفت
/// و یادآوری درون‌برنامه‌ای هنگام باز بودن برنامه (مسیر پوشش‌دهندهٔ ویندوز).
class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider({
    MedicationRepository? medicationRepository,
    ProfileRepository? profileRepository,
    DoseRepository? doseRepository,
    NotificationService? notifications,
  })  : _medications = medicationRepository ?? const MedicationRepository(),
        _profiles = profileRepository ?? const ProfileRepository(),
        _doses = doseRepository ?? const DoseRepository(),
        _notifications = notifications ?? NotificationService.instance;

  final MedicationRepository _medications;
  final ProfileRepository _profiles;
  final DoseRepository _doses;
  final NotificationService _notifications;

  List<DoseSlot> _slots = const [];
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  Timer? _ticker;
  final Set<String> _remindedKeys = <String>{};
  String _activeDateKey = '';

  List<DoseSlot> get slots => _slots;
  bool get loading => _loading;
  String? get error => _error;

  int get total => _slots.length;
  int get takenCount =>
      _slots.where((s) => s.status == DoseStatus.taken).length;
  int get missedCount =>
      _slots.where((s) => s.status == DoseStatus.missed).length;
  int get upcomingCount =>
      _slots.where((s) => s.status == DoseStatus.upcoming).length;

  /// نسبت پیشرفت مصرف امروز (۰ تا ۱)؛ اگر نوبتی نباشد ۰.
  double get progress => _slots.isEmpty ? 0 : takenCount / _slots.length;

  /// نوبت‌های سررسیدشده و تأییدنشده تا ۲ ساعت اخیر (نوار یادآوری صفحه).
  List<DoseSlot> get dueNow {
    final now = DateTime.now();
    return _slots
        .where((s) =>
            s.status == DoseStatus.missed &&
            now.difference(s.scheduledAt).inMinutes < 120)
        .toList(growable: false);
  }

  /// گروه‌بندی نوبت‌ها بر اساس ساعت برای نمایش بخش‌بندی‌شده.
  Map<String, List<DoseSlot>> get slotsByTime {
    final grouped = <String, List<DoseSlot>>{};
    for (final slot in _slots) {
      grouped.putIfAbsent(slot.timeKey, () => []).add(slot);
    }
    return grouped;
  }

  /// شروع زمان‌سنج به‌روزرسانی خودکار (تغییر روز، وضعیت‌ها، یادآوری).
  void startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  Future<void> _tick() async {
    final todayKey = PersianUtils.dateKey(DateTime.now());
    if (todayKey != _activeDateKey) {
      // تغییر روز: بارگذاری کامل برای روز جدید.
      await load();
      return;
    }

    final before = _statusSignature();
    _slots = [
      for (final slot in _slots) slot.copyWith(status: _recomputeStatus(slot)),
    ];
    if (_statusSignature() != before) {
      notifyListeners();
    }
    await _remindDue();
  }

  DoseStatus _recomputeStatus(DoseSlot slot) {
    if (slot.status == DoseStatus.taken || slot.status == DoseStatus.skipped) {
      return slot.status;
    }
    return slot.scheduledAt.isAfter(DateTime.now())
        ? DoseStatus.upcoming
        : DoseStatus.missed;
  }

  String _statusSignature() =>
      _slots.map((s) => '${s.logKey}:${s.status.name}').join(',');

  /// یادآوری درون‌برنامه‌ای برای نوبت‌های سررسیدشده.
  ///
  /// فقط در ویندوز فعال است؛ زیرا زمان‌بندی نوتیفیکیشن ویندوز تکی است و
  /// اگر برنامه باز بماند این مسیر نوبت بعدی را پوشش می‌دهد. در اندروید
  /// نوتیفیکیشن زمان‌بندی‌شدهٔ سیستم خودش کافی است (تکرار ناخواسته نمی‌شود).
  Future<void> _remindDue() async {
    if (!Platform.isWindows) return;

    final now = DateTime.now();
    for (final slot in _slots) {
      if (slot.status != DoseStatus.missed) continue;
      final elapsed = now.difference(slot.scheduledAt);
      // فقط در پنجرهٔ ۱۰ دقیقهٔ اول سررسید و فقط یک بار.
      if (elapsed.isNegative || elapsed.inMinutes > 10) continue;
      if (!_remindedKeys.add('${slot.dateKey}|${slot.logKey}')) continue;

      final parts = slot.timeKey.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      await _notifications.showNow(
        // بازهٔ شناسه‌ها جدا از زمان‌بندی تکرارشونده است و ساعت کامل
        // (hour*60+minute) داخل اید لحاظ می‌شود تا ۰۱:۳۰ و ۱۳:۳۰ روی هم
        // نیفتند.
        id: NotificationService.inAppNotificationId(
          slot.medicationId,
          hour,
          minute,
        ),
        title: 'یادآوری داروی ${slot.medicationName}',
        body:
            'نوبت مصرف ${slot.profileName} سر رسیده است. دوز: ${slot.dose} — ${slot.timeLabel}',
        payload: 'medication:${slot.medicationId}',
      );
    }
  }

  /// بارگذاری نوبت‌های امروز.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final todayKey = PersianUtils.dateKey(now);
      _activeDateKey = todayKey;

      final medications = await _medications.getAll();
      final profiles = await _profiles.getAll();
      final logs = await _doses.forDate(todayKey);

      _slots = DoseSlotBuilder.build(
        medications: medications,
        profiles: profiles,
        logs: logs,
        dateKey: todayKey,
        now: now,
      );
      // نوبت‌هایی که هنگام شروع برنامه گذشته‌اند، دوباره یادآوری نمی‌شوند.
      _remindedKeys
        ..clear()
        ..addAll(_slots
            .where((s) => s.status == DoseStatus.missed)
            .map((s) => '${s.dateKey}|${s.logKey}'));
    } catch (e) {
      _error = 'خطا در خواندن برنامهٔ امروز: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// تأیید نوبت ([DoseStatus.taken] یا [DoseStatus.skipped]) یا بازگشت
  /// به حالت بدون تأیید (status = null).
  Future<void> confirm(DoseSlot slot, DoseStatus? status) async {
    try {
      final DoseStatus? newStatus;
      if (status == DoseStatus.taken || status == DoseStatus.skipped) {
        newStatus = status;
      } else {
        // بازگشت به «بدون تأیید»: وضعیت از روی زمان دوباره محاسبه می‌شود.
        newStatus = null;
      }

      if (newStatus == null) {
        await _doses.clear(
          medicationId: slot.medicationId,
          logDate: slot.dateKey,
          logTime: slot.timeKey,
        );
      } else {
        await _doses.upsert(
          medicationId: slot.medicationId,
          logDate: slot.dateKey,
          logTime: slot.timeKey,
          status: newStatus == DoseStatus.taken ? 'taken' : 'skipped',
          confirmedAt: DateTime.now().toIso8601String(),
        );
      }

      _slots = [
        for (final s in _slots)
          if (s.logKey == slot.logKey && s.dateKey == slot.dateKey)
            s.copyWith(
              status: newStatus ??
                  (s.scheduledAt.isAfter(DateTime.now())
                      ? DoseStatus.upcoming
                      : DoseStatus.missed),
            )
          else
            s,
      ];
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'خطا در ثبت وضعیت: $e';
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
