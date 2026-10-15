import 'package:flutter/foundation.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';

/// مدیریت افراد خانواده (افزودن/ویرایش/حذف).
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({ProfileRepository? repository})
      : _repository = repository ?? const ProfileRepository();

  final ProfileRepository _repository;

  List<Profile> _profiles = const [];
  Map<int, int> _medicationCounts = const {};
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  List<Profile> get profiles => _profiles;
  Map<int, int> get medicationCounts => _medicationCounts;
  bool get loading => _loading;
  String? get error => _error;

  int get count => _profiles.length;

  Profile? byId(int id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final profiles = await _repository.getAll();
      final counts = await _repository.medicationCounts();
      _profiles = profiles;
      _medicationCounts = counts;
    } catch (e) {
      _error = 'خطا در خواندن افراد: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// افزودن فرد؛ در صورت موفقیت true برمی‌گرداند.
  Future<bool> add({required String name, required int colorValue}) async {
    try {
      final profile = await _repository.insert(Profile(
        name: name.trim(),
        colorValue: colorValue,
        createdAt: PersianUtils.dateKey(DateTime.now()),
      ));
      _profiles = [..._profiles, profile];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطا در افزودن فرد: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Profile profile) async {
    try {
      await _repository.update(profile);
      _profiles = [
        for (final p in _profiles) p.id == profile.id ? profile : p,
      ];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطا در ویرایش فرد: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      _profiles = _profiles.where((p) => p.id != id).toList(growable: false);
      _medicationCounts = {..._medicationCounts}..remove(id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'خطا در حذف فرد: $e';
      notifyListeners();
      return false;
    }
  }

  void refreshCounts(Map<int, int> counts) {
    _medicationCounts = counts;
    notifyListeners();
  }

  /// بارگذاری ممکن است پس از dispose کامل شود؛ اعلان نباید پس از مرگ پرووایدر.
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
