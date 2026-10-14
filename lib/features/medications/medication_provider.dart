import 'package:flutter/foundation.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_repository.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';

/// مدیریت داروها + همگام‌سازی زمان‌بندی نوتیفیکیشن پس از هر تغییر.
class MedicationProvider extends ChangeNotifier {
  MedicationProvider({
    MedicationRepository? repository,
    ProfileRepository? profileRepository,
    NotificationService? notifications,
  })  : _repository = repository ?? const MedicationRepository(),
        _profileRepository = profileRepository ?? const ProfileRepository(),
        _notifications = notifications ?? NotificationService.instance;

  final MedicationRepository _repository;
  final ProfileRepository _profileRepository;
  final NotificationService _notifications;

  List<Medication> _medications = const [];
  bool _loading = false;
  String? _error;

  List<Medication> get medications => _medications;
  bool get loading => _loading;
  String? get error => _error;

  int countForProfile(int profileId) =>
      _medications.where((m) => m.profileId == profileId).length;

  List<Medication> forProfile(int profileId) =>
      _medications.where((m) => m.profileId == profileId).toList(growable: false);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _medications = await _repository.getAll();
      await _syncNotifications();
    } catch (e) {
      _error = 'خطا در خواندن داروها: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> add(Medication medication) async {
    try {
      final saved = await _repository.insert(medication);
      _medications = [..._medications, saved];
      _error = null;
      notifyListeners();
      await _afterChange();
      return true;
    } catch (e) {
      _error = 'خطا در افزودن دارو: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Medication medication) async {
    try {
      await _repository.update(medication);
      _medications = [
        for (final m in _medications) m.id == medication.id ? medication : m,
      ];
      _error = null;
      notifyListeners();
      await _afterChange();
      return true;
    } catch (e) {
      _error = 'خطا در ویرایش دارو: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      _medications = _medications.where((m) => m.id != id).toList(growable: false);
      _error = null;
      notifyListeners();
      await _afterChange();
      return true;
    } catch (e) {
      _error = 'خطا در حذف دارو: $e';
      notifyListeners();
      return false;
    }
  }

  /// پس از هر تغییر: شمارش داروهای افراد + زمان‌بندی دوبارهٔ نوتیفیکیشن.
  Future<void> _afterChange() async {
    await _syncNotifications();
    try {
      final counts = await _profileRepository.medicationCounts();
      _profileCountsListener?.call(counts);
    } catch (_) {
      // شمارش فرعی است؛ خطای آن نباید جلوی کاربر را بگیرد.
    }
  }

  Future<void> _syncNotifications() async {
    try {
      await _notifications.rescheduleAll(_medications);
    } catch (e) {
      debugPrint('خطا در همگام‌سازی نوتیفیکیشن‌ها: $e');
    }
  }

  /// بازخورد به ProfileProvider برای به‌روزرسانی شمارش داروها.
  void Function(Map<int, int> counts)? _profileCountsListener;

  void setProfileCountsListener(void Function(Map<int, int>) listener) {
    _profileCountsListener = listener;
  }
}
