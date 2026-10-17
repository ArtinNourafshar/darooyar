import 'package:flutter/foundation.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/meals/meal.dart';
import 'package:darooyar/features/meals/meal_repository.dart';
import 'package:darooyar/features/meals/meal_slot.dart';
import 'package:darooyar/features/schedule/dose_log.dart';

/// وضعیت برنامهٔ غذایی امروز + مدیریت وعده‌ها.
class MealProvider extends ChangeNotifier {
  MealProvider({MealRepository? repository})
      : _repository = repository ?? const MealRepository();

  final MealRepository _repository;

  List<MealTime> _meals = const [];
  List<MealSlot> _slots = const [];
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  List<MealTime> get meals => _meals;

  /// نوبت‌های وعده‌های امروز (مرتب‌شده بر اساس ساعت).
  List<MealSlot> get slots => _slots;
  bool get loading => _loading;
  String? get error => _error;

  int get total => _slots.length;

  int get eatenCount =>
      _slots.where((s) => s.status == DoseStatus.taken).length;

  int get missedCount =>
      _slots.where((s) => s.status == DoseStatus.missed).length;

  int get upcomingCount =>
      _slots.where((s) => s.status == DoseStatus.upcoming).length;

  /// پیشرفت روز (خورده‌شده از کل نوبت‌های گذشته + در انتظار).
  double get progress => _slots.isEmpty ? 1 : eatenCount / _slots.length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // وعده‌های پیش‌فرض فقط یک بار ساخته می‌شوند.
      await _repository.ensureDefaults();
      final meals = await _repository.getAll();
      final todayKey = PersianUtils.dateKey(DateTime.now());
      final logs = await _repository.logsForDate(todayKey);

      _meals = meals;
      _slots = MealSlotBuilder.build(
        meals: meals,
        logs: logs,
        now: DateTime.now(),
        dateKey: todayKey,
      );

      // یادآوری‌های وعده‌ها باید با فهرست تازه همگام شوند.
      NotificationService.instance.rescheduleAll(meals: meals);
    } catch (e) {
      _error = 'خطا در بارگذاری برنامهٔ غذایی';
      debugPrint('MealProvider.load: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// ثبت وضعیت یک وعده؛ [status] پس از null شدن یعنی «تغییر/حذف ثبت».
  Future<bool> confirm(MealSlot slot, DoseStatus? status) async {
    final todayKey = PersianUtils.dateKey(DateTime.now());
    try {
      if (status == null) {
        await _repository.clear(mealTimeId: slot.mealId, dateKey: todayKey);
      } else {
        await _repository.confirm(
          mealTimeId: slot.mealId,
          dateKey: todayKey,
          status: status == DoseStatus.taken ? 'eaten' : 'skipped',
          confirmedAt: DateTime.now().toIso8601String(),
        );
      }
      await load();
      return true;
    } catch (e) {
      _error = 'خطا در ثبت وعده';
      debugPrint('MealProvider.confirm: $e');
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  /// افزودن/ویرایش وعده (+ همگام‌سازی زمان‌بندی یادآوری‌ها).
  Future<bool> save(MealTime meal) async {
    try {
      if (meal.id == null) {
        await _repository.insert(meal);
      } else {
        await _repository.update(meal);
      }
      await load();
      return true;
    } catch (e) {
      _error = 'خطا در ذخیرهٔ وعده';
      debugPrint('MealProvider.save: $e');
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      await load();
      return true;
    } catch (e) {
      _error = 'خطا در حذف وعده';
      debugPrint('MealProvider.delete: $e');
      if (!_disposed) notifyListeners();
      return false;
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
    super.dispose();
  }
}
