import 'package:flutter/foundation.dart';

import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/bmi_calculator.dart';
import 'package:darooyar/features/health/health_metric.dart';
import 'package:darooyar/features/health/health_repository.dart';
import 'package:darooyar/features/health/water_repository.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';

/// وضعیت شاخص‌های سلامت خانواده: انتخاب فرد، آخرین مقادیر،
/// تاریخچهٔ نموداری، محاسبهٔ BMI و پیگیری نوشیدن آب.
class HealthProvider extends ChangeNotifier {
  HealthProvider({
    HealthRepository? repository,
    ProfileRepository? profileRepository,
    WaterRepository? waterRepository,
    SettingsRepository? settings,
    NotificationService? notifications,
  })  : _repository = repository ?? const HealthRepository(),
        _profileRepository = profileRepository ?? const ProfileRepository(),
        _water = waterRepository ?? const WaterRepository(),
        _settings = settings ?? const SettingsRepository(),
        _notifications = notifications ?? NotificationService.instance;

  final HealthRepository _repository;
  final ProfileRepository _profileRepository;
  final WaterRepository _water;
  final SettingsRepository _settings;
  final NotificationService _notifications;

  List<Profile> _profiles = const [];
  int? _profileId;
  Map<String, HealthLog> _latest = const {};
  Map<String, List<HealthLog>> _history = const {};
  double? _height;
  bool _loading = false;
  bool _disposed = false;
  String? _error;

  // ── نوشیدن آب ───────────────────────────────────────────────────
  List<WaterLog> _waterToday = const [];
  Map<String, int> _waterWeek = const {};
  int _waterTarget = 8;
  bool _waterReminderEnabled = false;
  int _waterReminderInterval = 2;

  /// لیوان‌های ثبت‌شدهٔ امروز.
  List<WaterLog> get waterToday => _waterToday;
  int get waterCupsToday => _waterToday.length;
  int get waterTarget => _waterTarget;
  bool get waterReminderEnabled => _waterReminderEnabled;
  int get waterReminderInterval => _waterReminderInterval;

  /// نسبت پیشرفت آب امروز (۰ تا۱).
  double get waterProgress =>
      _waterTarget <= 0 ? 0 : (waterCupsToday / _waterTarget).clamp(0.0, 1.0);

  /// شمارش لیوان هر روز از ۷ روز اخیر (برای نمودار).
  Map<String, int> get waterWeek => _waterWeek;

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
      await _loadWaterSettings();
      await _refreshWater();
    } catch (e) {
      _error = 'خطا در بارگذاری شاخص‌های سلامت';
      debugPrint('HealthProvider.load: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── نوشیدن آب ───────────────────────────────────────────────────

  /// بارگذاری تنظیمات آب از پایگاه‌داده و اعمال روی سرویس یادآور.
  Future<void> _loadWaterSettings() async {
    try {
      final enabled =
          await _settings.getBool(SettingKeys.waterReminderEnabled);
      final interval =
          int.tryParse(await _settings.get(SettingKeys.waterReminderInterval) ?? '') ?? 2;
      final target =
          int.tryParse(await _settings.get(SettingKeys.waterTarget) ?? '') ?? 8;

      _waterReminderEnabled = enabled;
      _waterReminderInterval = interval.clamp(1, 6);
      _waterTarget = target.clamp(1, 30);

      await _notifications.setWaterReminder(
        enabled: _waterReminderEnabled,
        intervalHours: _waterReminderInterval,
      );
    } catch (e) {
      debugPrint('HealthProvider._loadWaterSettings: $e');
    }
  }

  /// تازه‌سازی لیوان‌های امروز + نمودار ۷ روزه.
  Future<void> _refreshWater() async {
    try {
      final now = DateTime.now();
      _waterToday = await _water.forDate(PersianUtils.dateKey(now));
      final from = DateTime(now.year, now.month, now.day - 6);
      final counts = await _water.countByDay(
        PersianUtils.dateKey(from),
        PersianUtils.dateKey(now),
      );
      // هر ۷ روز حاضر باشند (روزهای بدون لیوان صفر می‌شوند تا روند دروغ
      // نگوید و ستون‌ها همیشه ۷ تا باشند).
      _waterWeek = {
        for (var i = 6; i >= 0; i--)
          PersianUtils.dateKey(DateTime(now.year, now.month, now.day - i)): 0,
        ...counts,
      };
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('HealthProvider._refreshWater: $e');
    }
  }

  /// ثبت یک لیوان آب.
  Future<bool> addCup() async {
    try {
      final now = DateTime.now();
      await _water.add(WaterLog(
        logDate: PersianUtils.dateKey(now),
        logTime: PersianUtils.timeKey(now),
      ));
      await _refreshWater();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.addCup: $e');
      return false;
    }
  }

  /// حذف آخرین لیوان ثبت‌شدهٔ امروز (برگشت از اشتباه).
  Future<bool> removeLastCup() async {
    final last = _waterToday.isEmpty ? null : _waterToday.last;
    if (last?.id == null) return false;
    try {
      await _water.delete(last!.id!);
      await _refreshWater();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.removeLastCup: $e');
      return false;
    }
  }

  /// تغییر هدف روزانهٔ لیوان آب (۱ تا ۳۰).
  Future<bool> setWaterTarget(int target) async {
    final clamped = target.clamp(1, 30);
    try {
      _waterTarget = clamped;
      await _settings.set(SettingKeys.waterTarget, '$clamped');
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.setWaterTarget: $e');
      return false;
    }
  }

  /// فعال/غیرفعال کردن یادآوری نوشیدن آب.
  Future<bool> setWaterReminderEnabled(bool enabled) async {
    try {
      _waterReminderEnabled = enabled;
      await _settings.setBool(SettingKeys.waterReminderEnabled, enabled);
      await _notifications.setWaterReminder(
        enabled: enabled,
        intervalHours: _waterReminderInterval,
      );
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.setWaterReminderEnabled: $e');
      return false;
    }
  }

  /// بازهٔ یادآوری آب به ساعت (۱ تا۶).
  Future<bool> setWaterReminderInterval(int hours) async {
    final clamped = hours.clamp(1, 6);
    try {
      _waterReminderInterval = clamped;
      await _settings.set(SettingKeys.waterReminderInterval, '$clamped');
      await _notifications.setWaterReminder(
        enabled: _waterReminderEnabled,
        intervalHours: clamped,
      );
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HealthProvider.setWaterReminderInterval: $e');
      return false;
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
