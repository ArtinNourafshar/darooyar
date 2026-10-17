import 'package:flutter/material.dart';

/// شاخص‌های قابل ثبت سلامت.
enum HealthMetric {
  bloodPressure('bp', 'فشار خون', 'mmHg', Icons.favorite_outline),
  bloodSugar('sugar', 'قند خون', 'mg/dL', Icons.water_drop_outlined),
  weight('weight', 'وزن', 'کیلوگرم', Icons.monitor_weight_outlined),
  bodyFat('body_fat', 'چربی بدن', 'درصد', Icons.donut_small_outlined),
  sleep('sleep', 'خواب', 'ساعت', Icons.bedtime_outlined),
  waist('waist', 'دور کمر', 'سانتی‌متر', Icons.straighten_outlined);

  const HealthMetric(this.dbKey, this.label, this.unit, this.icon);

  /// کلید ذخیره در پایگاه‌داده.
  final String dbKey;

  /// برچسب فارسی.
  final String label;

  /// واحد نمایش.
  final String unit;

  final IconData icon;

  /// آیا دو مقدار دارد؟ (فشار: سیستول/دیاستول — خواب: ساعت/کیفیت)
  bool get hasSecondValue =>
      this == HealthMetric.bloodPressure || this == HealthMetric.sleep;

  static HealthMetric? fromDbKey(String key) {
    for (final metric in values) {
      if (metric.dbKey == key) return metric;
    }
    return null;
  }
}

/// یک ثبت سلامت برای یک فرد در یک لحظه.
class HealthLog {
  const HealthLog({
    this.id,
    required this.profileId,
    required this.metric,
    required this.value1,
    this.value2,
    required this.logDate,
    required this.logTime,
    this.note,
  });

  final int? id;
  final int profileId;

  /// کلید شاخص (یکی از [HealthMetric.dbKey]).
  final String metric;

  /// مقدار اول: فشار سیستول / قند / وزن / چربی / ساعت خواب / دور کمر.
  final double value1;

  /// مقدار دوم: دیاستول (فشار) یا کیفیت خواب ۱ تا ۵.
  final double? value2;

  /// کلید تاریخ «yyyy-MM-dd».
  final String logDate;

  /// ساعت ثبت «HH:mm».
  final String logTime;
  final String? note;

  HealthMetric? get metricInfo => HealthMetric.fromDbKey(metric);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'metric': metric,
      'value1': value1,
      'value2': value2,
      'log_date': logDate,
      'log_time': logTime,
      'note': note,
    };
  }

  factory HealthLog.fromMap(Map<String, Object?> map) {
    return HealthLog(
      id: map['id'] as int?,
      profileId: map['profile_id'] as int,
      metric: map['metric'] as String,
      value1: (map['value1'] as num).toDouble(),
      value2: (map['value2'] as num?)?.toDouble(),
      logDate: map['log_date'] as String,
      logTime: map['log_time'] as String,
      note: map['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HealthLog &&
      other.id == id &&
      other.profileId == profileId &&
      other.metric == metric &&
      other.value1 == value1 &&
      other.value2 == value2 &&
      other.logDate == logDate &&
      other.logTime == logTime &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
        id,
        profileId,
        metric,
        value1,
        value2,
        logDate,
        logTime,
        note,
      );
}
