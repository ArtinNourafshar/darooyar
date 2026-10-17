import 'package:flutter/foundation.dart';

import 'package:darooyar/core/pdf/pdf_report_service.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/health_metric.dart';
import 'package:darooyar/features/health/health_repository.dart';
import 'package:darooyar/features/meals/meal_repository.dart';
import 'package:darooyar/features/medications/medication_repository.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';
import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_repository.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// گزارش تاریخچهٔ مصرف: بازه + فیلتر فرد + آمار + نمودار + جریان فعالیت + PDF.
class ReportProvider extends ChangeNotifier {
  ReportProvider({
    MedicationRepository? medicationRepository,
    ProfileRepository? profileRepository,
    DoseRepository? doseRepository,
    MealRepository? mealRepository,
    HealthRepository? healthRepository,
  })  : _medications = medicationRepository ?? const MedicationRepository(),
        _profiles = profileRepository ?? const ProfileRepository(),
        _doses = doseRepository ?? const DoseRepository(),
        _meals = mealRepository ?? const MealRepository(),
        _health = healthRepository ?? const HealthRepository();

  final MedicationRepository _medications;
  final ProfileRepository _profiles;
  final DoseRepository _doses;
  final MealRepository _meals;
  final HealthRepository _health;

  ReportRange _range = ReportRange.last7;
  int? _profileId; // null = همه
  List<DoseSlot> _rows = const [];
  ReportStats _stats = ReportStats.empty;
  List<ReportBar> _bars = const [];
  List<ActivityEntry> _activity = const [];
  List<Profile> _allProfiles = const [];
  Map<int, String> _mealNames = const {};
  bool _loading = false;
  bool _exporting = false;
  bool _disposed = false;
  String? _error;

  /// حداکثر بازهٔ «سالیانه» به روز.
  ///
  /// بدون این سقف، داروهای ثبت‌شده برای سال‌ها روزانه ده‌ها هزار ردیف
  /// می‌ساختند (کرش رندر + PDF چندصدصفحه‌ای).
  static const int maxHistoryDays = 365;

  ReportRange get range => _range;
  int? get profileId => _profileId;
  List<DoseSlot> get rows => _rows;
  ReportStats get stats => _stats;
  List<Profile> get allProfiles => _allProfiles;

  /// ستون‌های نمودار مصرف برای بازهٔ انتخابی.
  List<ReportBar> get bars => _bars;

  /// جریان یکپارچهٔ فعالیت‌ها (دارو + وعده + شاخص سلامت)، جدیدترین اول.
  List<ActivityEntry> get activity => _activity;

  bool get loading => _loading;
  bool get exporting => _exporting;
  String? get error => _error;

  bool get hasRows => _rows.isNotEmpty;

  String get profileLabel {
    if (_profileId == null) return 'همه';
    for (final p in _allProfiles) {
      if (p.id == _profileId) return p.name;
    }
    return 'همه';
  }

  /// برچسب بازهٔ انتخاب‌شده + فرد (برای سربرگ PDF).
  String get headerLabel => '${_range.label} — فرد: $profileLabel';

  Future<void> setRange(ReportRange range) async {
    if (_range == range) return;
    _range = range;
    notifyListeners();
    await load();
  }

  Future<void> setProfile(int? profileId) async {
    if (_profileId == profileId) return;
    _profileId = profileId;
    notifyListeners();
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final todayKey = PersianUtils.dateKey(now);

      final medications = await _medications.getAll();
      final profiles = await _profiles.getAll();
      _allProfiles = profiles;

      var (startKey, endKey) = _range.resolve(now);
      if (startKey == null) {
        // «سالیانه»: از اولین ثبت داروها، اما حداکثر [maxHistoryDays]
        // روز اخیر تا تعداد ردیف‌ها همیشه محدود بماند.
        final earliestAllowed = PersianUtils.dateKey(
          DateTime(now.year, now.month, now.day - maxHistoryDays),
        );
        final firstMedication = medications.isEmpty
            ? todayKey
            : medications
                .map((m) => m.createdAt)
                .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
        startKey = firstMedication.compareTo(earliestAllowed) > 0
            ? firstMedication
            : earliestAllowed;
      }
      if (startKey.compareTo(endKey) > 0) {
        startKey = endKey;
      }

      final logs = await _doses.range(startKey, endKey);
      final logsByDate = <String, Map<String, DoseLog>>{};
      for (final log in logs) {
        logsByDate.putIfAbsent(log.logDate, () => {})[log.logKey] = log;
      }

      final rows = <DoseSlot>[];
      var cursor = PersianUtils.dateTimeFromKey(startKey, '00:00');
      final end = PersianUtils.dateTimeFromKey(endKey, '00:00');
      while (!cursor.isAfter(end)) {
        final key = PersianUtils.dateKey(cursor);
        rows.addAll(DoseSlotBuilder.build(
          medications: medications,
          profiles: profiles,
          logs: logsByDate[key] ?? const <String, DoseLog>{},
          dateKey: key,
          now: now,
          profileFilterId: _profileId,
        ));
        cursor = cursor.add(const Duration(days: 1));
      }

      _rows = rows;
      _stats = _computeStats(rows);
      _bars = ReportChartBuilder.build(
        range: _range,
        rows: rows,
        now: now,
      );

      await _loadActivity(startKey, endKey);
    } catch (e) {
      _error = 'خطا در ساخت گزارش: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// بارگذاری وعده‌ها و شاخص‌های سلامت برای جریان فعالیت.
  Future<void> _loadActivity(String startKey, String endKey) async {
    final mealTimes = await _meals.getAll();
    _mealNames = {
      for (final meal in mealTimes)
        if (meal.id != null) meal.id!: meal.name,
    };
    final mealLogs = await _meals.range(startKey, endKey);
    final healthLogs =
        await _health.allInRangeAllProfiles(fromKey: startKey, toKey: endKey);

    final profileById = {for (final p in _allProfiles) p.id: p};
    final entries = <ActivityEntry>[];

    // نوبت‌های دارو (فقط گذشته/ثبتشده؛ در انتظار نمی‌آید).
    for (final row in _rows) {
      if (row.status == DoseStatus.upcoming) continue;
      entries.add(ActivityEntry(
        dateKey: row.dateKey,
        timeKey: row.timeKey,
        kind: ActivityKind.dose,
        title: row.medicationName,
        subtitle: '${row.profileName} — دوز: ${row.dose}',
        status: row.status,
        profileColorValue: row.profileColorValue,
      ));
    }

    // وعده‌های غذایی.
    for (final log in mealLogs) {
      final confirmed = DateTime.tryParse(log.confirmedAt);
      entries.add(ActivityEntry(
        dateKey: log.logDate,
        timeKey: confirmed == null
            ? '00:00'
            : PersianUtils.timeKey(confirmed),
        kind: ActivityKind.meal,
        title: _mealNames[log.mealTimeId] ?? 'وعدهٔ غذایی',
        subtitle: log.isEaten ? 'خورده شد' : 'نخوردم',
        status: log.isEaten ? DoseStatus.taken : DoseStatus.skipped,
      ));
    }

    // شاخص‌های سلامت.
    final filterId = _profileId;
    for (final log in healthLogs) {
      if (filterId != null && log.profileId != filterId) continue;
      final metric = HealthMetric.fromDbKey(log.metric);
      final profileName = profileById[log.profileId]?.name ?? '—';
      entries.add(ActivityEntry(
        dateKey: log.logDate,
        timeKey: log.logTime,
        kind: ActivityKind.health,
        title: metric?.label ?? log.metric,
        subtitle: '$profileName — ${_healthValueText(log, metric)}',
        profileColorValue: profileById[log.profileId]?.colorValue,
      ));
    }

    // جدیدترین اول.
    entries.sort((a, b) {
      final byDate = b.dateKey.compareTo(a.dateKey);
      if (byDate != 0) return byDate;
      return b.timeKey.compareTo(a.timeKey);
    });

    _activity = entries;
  }

  /// مقدار فارسی یک ثبت سلامت (برای زیرنویس جریان فعالیت).
  static String _healthValueText(HealthLog log, HealthMetric? metric) {
    final p = PersianUtils.toPersianDigits;
    switch (metric) {
      case HealthMetric.bloodPressure:
        return '${p(log.value1.round().toString())}/'
            '${p((log.value2 ?? 0).round().toString())} mmHg';
      case HealthMetric.sleep:
        return '${p(log.value1.toStringAsFixed(1))} ساعت — '
            'کیفیت ${p((log.value2 ?? 0).round().toString())} از ۵';
      case null:
        return p(log.value1.toString());
      default:
        final digits = (metric == HealthMetric.weight ||
                metric == HealthMetric.bodyFat)
            ? 1
            : 0;
        return '${p(log.value1.toStringAsFixed(digits))} ${metric.unit}';
    }
  }

  ReportStats _computeStats(List<DoseSlot> rows) {
    var taken = 0, skipped = 0, missed = 0, upcoming = 0;
    for (final row in rows) {
      switch (row.status) {
        case DoseStatus.taken:
          taken++;
        case DoseStatus.skipped:
          skipped++;
        case DoseStatus.missed:
          missed++;
        case DoseStatus.upcoming:
          upcoming++;
      }
    }
    return ReportStats(
      taken: taken,
      skipped: skipped,
      missed: missed,
      upcoming: upcoming,
    );
  }

  /// ساخت PDF و ذخیرهٔ آن؛ مسیر فایل در صورت موفقیت برمی‌گردد.
  Future<String?> exportPdf() async {
    if (_exporting) return null;
    _exporting = true;
    _error = null;
    notifyListeners();
    try {
      final path = await PdfReportService.export(
        rows: _rows,
        stats: _stats,
        rangeLabel: _range.label,
        profileLabel: profileLabel,
      );
      return path;
    } catch (e) {
      _error = 'خطا در ساخت PDF: $e';
      return null;
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  /// بارگذاری ممکن است پس از dispose کامل شود.
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

extension _DoseLogKey on DoseLog {
  String get logKey => '$medicationId|$logTime';
}
