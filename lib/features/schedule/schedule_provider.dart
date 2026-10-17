import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_repository.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_repository.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';
import 'package:darooyar/features/schedule/streak.dart';

/// برنامهٔ امروز: محاسبهٔ نوبت‌ها، تأیید «خوردم/نخوردم» و نوار پیشرفت.
class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider({
    MedicationRepository? medicationRepository,
    ProfileRepository? profileRepository,
    DoseRepository? doseRepository,
  })  : _medications = medicationRepository ?? const MedicationRepository(),
        _profiles = profileRepository ?? const ProfileRepository(),
        _doses = doseRepository ?? const DoseRepository();

  final MedicationRepository _medications;
  final ProfileRepository _profiles;
  final DoseRepository _doses;

  List<DoseSlot> _slots = const [];
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  Timer? _ticker;
  String _activeDateKey = '';
  int _streakDays = 0;

  List<DoseSlot> get slots => _slots;
  bool get loading => _loading;
  String? get error => _error;

  /// تعداد روزهای پیاپیِ مصرف کامل (استریک).
  int get streakDays => _streakDays;

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

      _streakDays = await _computeStreak(
        medications: medications,
        profiles: profiles,
        todayKey: todayKey,
      );
    } catch (e) {
      _error = 'خطا در خواندن برنامهٔ امروز: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// محاسبهٔ استریک از نوبت‌های ۶۰ روز اخیر.
  Future<int> _computeStreak({
    required List<Medication> medications,
    required List<Profile> profiles,
    required String todayKey,
  }) async {
    final now = DateTime.now();
    final fromKey = PersianUtils.dateKey(
      DateTime(now.year, now.month, now.day - 59),
    );
    final rangeLogs = await _doses.range(fromKey, todayKey);

    final logsByDay = <String, Map<String, DoseLog>>{};
    for (final log in rangeLogs) {
      (logsByDay[log.logDate] ??= {})['${log.medicationId}|${log.logTime}'] =
          log;
    }

    final days = <String, DayCompliance>{};
    for (var offset = 0; offset < 60; offset++) {
      final day = PersianUtils.dateKey(
        DateTime(now.year, now.month, now.day - offset),
      );
      final daySlots = DoseSlotBuilder.build(
        medications: medications,
        profiles: profiles,
        logs: logsByDay[day] ?? const <String, DoseLog>{},
        dateKey: day,
        now: now,
      );
      if (daySlots.isEmpty) continue;

      var taken = 0;
      var broken = false;
      for (final slot in daySlots) {
        if (slot.status == DoseStatus.taken) taken++;
        if (slot.status == DoseStatus.missed || slot.status == DoseStatus.skipped) {
          broken = true;
        }
      }
      days[day] = DayCompliance(taken: taken, broken: broken);
    }

    return StreakCalculator.compute(todayKey: todayKey, days: days);
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

        // «خوردم» تازه → یک واحد از باقی‌ماندهٔ دارو کم می‌شود
        // (برای هشدار اتمام دارو).
        if (newStatus == DoseStatus.taken &&
            slot.status != DoseStatus.taken) {
          try {
            await _medications.consumeOne(slot.medicationId);
          } catch (e) {
            debugPrint('خطا در کم کردن باقی‌ماندهٔ دارو: $e');
          }
        }
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

      // استریک باید با تغییر امروز به‌روز شود.
      try {
        final now = DateTime.now();
        _streakDays = await _computeStreak(
          medications: await _medications.getAll(),
          profiles: await _profiles.getAll(),
          todayKey: PersianUtils.dateKey(now),
        );
      } catch (e) {
        debugPrint('خطا در محاسبهٔ استریک: $e');
      }

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
