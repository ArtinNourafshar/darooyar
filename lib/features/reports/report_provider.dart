import 'package:flutter/foundation.dart';

import 'package:darooyar/core/pdf/pdf_report_service.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication_repository.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_repository.dart';
import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_repository.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';

/// گزارش تاریخچهٔ مصرف: بازه + فیلتر فرد + آمار + خروجی PDF.
class ReportProvider extends ChangeNotifier {
  ReportProvider({
    MedicationRepository? medicationRepository,
    ProfileRepository? profileRepository,
    DoseRepository? doseRepository,
  })  : _medications = medicationRepository ?? const MedicationRepository(),
        _profiles = profileRepository ?? const ProfileRepository(),
        _doses = doseRepository ?? const DoseRepository();

  final MedicationRepository _medications;
  final ProfileRepository _profiles;
  final DoseRepository _doses;

  ReportRange _range = ReportRange.last7;
  int? _profileId; // null = همه
  List<DoseSlot> _rows = const [];
  ReportStats _stats = ReportStats.empty;
  List<Profile> _allProfiles = const [];
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  String? _lastExportedPath;

  ReportRange get range => _range;
  int? get profileId => _profileId;
  List<DoseSlot> get rows => _rows;
  ReportStats get stats => _stats;
  List<Profile> get allProfiles => _allProfiles;
  bool get loading => _loading;
  bool get exporting => _exporting;
  String? get error => _error;
  String? get lastExportedPath => _lastExportedPath;

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
        // «همهٔ تاریخچه»: از اولین ثبت داروها.
        if (medications.isEmpty) {
          startKey = todayKey;
        } else {
          startKey = medications
              .map((m) => m.createdAt)
              .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
        }
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
      _lastExportedPath = null;
    } catch (e) {
      _error = 'خطا در ساخت گزارش: $e';
    } finally {
      _loading = false;
      notifyListeners();
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
      _lastExportedPath = path;
      return path;
    } catch (e) {
      _error = 'خطا در ساخت PDF: $e';
      return null;
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }
}

extension _DoseLogKey on DoseLog {
  String get logKey => '$medicationId|$logTime';
}
