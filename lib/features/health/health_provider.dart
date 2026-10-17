import 'package:flutter/foundation.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/bmi_calculator.dart';
import 'package:darooyar/features/health/health_metric.dart';
import 'package:darooyar/features/health/health_repository.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';

/// وضعیت شاخص‌های سلامت خانواده: انتخاب فرد، آخرین مقادیر،
/// تاریخچهٔ نموداری و محاسبهٔ BMI.
class HealthProvider extends ChangeNotifier {
  HealthProvider({
    HealthRepository? repository,
    ProfileRepository? profileRepository,
  })  : _repository = repository ?? const HealthRepository(),
        _profileRepository = profileRepository ?? const ProfileRepository();

  final HealthRepository _repository;
  final ProfileRepository _profileRepository;

  List<Profile> _profiles = const [];
  int? _profileId;
  Map<String, HealthLog> _latest = const {};
  Map<String, List<HealthLog>> _history = const {};
  double? _height;
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  List<Profile> get profiles => _profiles;

  /// فردِ انتخاب‌شدهٔ فعلی.
  Profile? get selectedProfile {
    final id = _profileId;
    if (id == null) return null;
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  int? get profileId => _profileId;
  bool get loading => _loading;
  String? get error => _error;
  double? get heightCm => _height;

  /// آخرین مقدار هر شاخص (کلید = [HealthMetric.dbKey]).
  Map<String, HealthLog> get latest => _latest;

  /// BMI از آخرین وزن ثبت‌شده + قد فرد (null اگر داده‌ای نباشد).
  BmiResult? get bmi {
    final weight = _latest[HealthMetric.weight.dbKey]?.value1;
    final height = _height;
    if (weight == null || height == null) return null;
    return BmiCalculator.calculateWithCategory(
      weightKg: weight,
      heightCm: height,
    );
  }

  /// تاریخچهٔ ۳۰ روزهٔ یک شاخص (برای نمودار).
  List<HealthLog> historyOf(String metricKey) =>
      _history[metricKey] ?? const [];

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final profiles = await _profileRepository.getAll();
      _profiles = profiles;

      // پیش‌فرض: اولین فرد، مگر انتخاب قبلی هنوز معتبر باشد.
      final valid = profiles.any((p) => p.id == _profileId);
      if (!valid) {
        _profileId = profiles.isEmpty ? null : profiles.first.id;
      }

      await _refreshSelected();
    } catch (e) {
      _error = 'خطا در بارگذاری شاخص‌های سلامت';
      debugPrint('HealthProvider.load: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> selectProfile(int? id) async {
    if (id == _profileId) return;
    _profileId = id;
    _latest = const {};
    _history = const {};
    _height = null;
    notifyListeners();
    await _refreshSelected();
  }

  /// به‌روزرسانی داده‌های فرد انتخاب‌شده (آخرین مقادیر + تاریخچهٔ BMI).
  Future<void> _refreshSelected() async {
    final id = _profileId;
    if (id == null) return;

    _latest = await _repository.latestPerMetric(id);
    _height = await _repository.heightOf(id);

    // تاریخچهٔ وزن برای نمودار BMI همیشه لازم است.
    final now = DateTime.now();
    final from = PersianUtils.dateKey(
      DateTime(now.year, now.month, now.day - 29),
    );
    final weightHistory = await _repository.history(
      profileId: id,
      metric: HealthMetric.weight.dbKey,
      fromKey: from,
      toKey: PersianUtils.dateKey(now),
    );
    _history = {HealthMetric.weight.dbKey: weightHistory};

    if (!_disposed) notifyListeners();
  }

  /// بارگذاری تاریخچهٔ ۳۰ روزهٔ یک شاخص (برای نمودار).
  Future<void> loadHistory(String metricKey) async {
    final id = _profileId;
    if (id == null) return;

    try {
      final now = DateTime.now();
      final from = PersianUtils.dateKey(
        DateTime(now.year, now.month, now.day - 29),
      );
      final items = await _repository.history(
        profileId: id,
        metric: metricKey,
        fromKey: from,
        toKey: PersianUtils.dateKey(now),
      );
      _history = {..._history, metricKey: items};
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('HealthProvider.loadHistory: $e');
    }
  }

  Future<bool> addLog({
    required HealthMetric metric,
    required double value1,
    double? value2,
    String? note,
  }) async {
    final id = _profileId;
    if (id == null) return false;

    try {
      final now = DateTime.now();
      await _repository.add(
        HealthLog(
          profileId: id,
          metric: metric.dbKey,
          value1: value1,
          value2: value2,
          logDate: PersianUtils.dateKey(now),
          logTime: PersianUtils.timeKey(now),
          note: (note == null || note.trim().isEmpty) ? null : note.trim(),
        ),
      );
      await _refreshSelected();
      // تاریخچهٔ خود شاخص هم تازه شود.
      await loadHistory(metric.dbKey);
      return true;
    } catch (e) {
      _error = 'خطا در ثبت شاخص';
      debugPrint('HealthProvider.addLog: $e');
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLog(int logId) async {
    try {
      await _repository.delete(logId);
      await _refreshSelected();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.deleteLog: $e');
      return false;
    }
  }

  Future<bool> setHeight(double heightCm) async {
    final id = _profileId;
    if (id == null) return false;
    try {
      await _repository.setHeight(id, heightCm);
      _height = heightCm;
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.setHeight: $e');
      return false;
    }
  }

  /// خلاصهٔ متنی فرد برای پرامپت‌های هوش مصنوعی.
  String aiSummary() => summarizeForAi(
        profileLabel: selectedProfile?.name ?? '—',
        heightCm: _height,
        bmi: bmi,
        latest: _latest,
      );

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

  /// خلاصهٔ سلامت به متن فارسی (برای ارسال به AI — بدون دادهٔ اضافه).
  static String summarizeForAi({
    required String profileLabel,
    required double? heightCm,
    required BmiResult? bmi,
    required Map<String, HealthLog> latest,
  }) {
    final lines = <String>['فرد: $profileLabel'];

    if (heightCm != null) {
      lines.add(
        'قد: ${PersianUtils.toPersianDigits(heightCm.toStringAsFixed(0))} سانتی‌متر',
      );
    }
    if (bmi != null) {
      lines.add(
        'BMI: ${BmiCalculator.format(bmi.value)} (${bmi.category.label})',
      );
    }

    for (final metric in HealthMetric.values) {
      final log = latest[metric.dbKey];
      if (log == null) continue;

      String fmt(double v, int digits) =>
          PersianUtils.toPersianDigits(v.toStringAsFixed(digits));

      final String line;
      switch (metric) {
        case HealthMetric.bloodPressure:
          line =
              'فشار خون: ${fmt(log.value1, 0)}/${fmt(log.value2 ?? 0, 0)} mmHg';
        case HealthMetric.sleep:
          line =
              'خواب: ${fmt(log.value1, 1)} ساعت، کیفیت ${fmt(log.value2 ?? 0, 0)} از ۵';
        default:
          final digits =
              (metric == HealthMetric.weight || metric == HealthMetric.bodyFat)
                  ? 1
                  : 0;
          line = '${metric.label}: ${fmt(log.value1, digits)} ${metric.unit}';
      }
      lines.add(line);
    }

    if (lines.length == 1) lines.add('هنوز شاخصی ثبت نشده است.');
    return lines.join('\n');
  }
}
