/// وعدهٔ غذایی (مثل «ناهار» ساعت ۱۳:۰۰) و ثبت روزانهٔ آن.
library;

import 'package:darooyar/features/schedule/dose_log.dart';

/// یک وعدهٔ غذایی تکرارشونده (زمان‌بندی روزانه، مانند نوبت دارو).
class MealTime {
  const MealTime({
    this.id,
    required this.name,
    required this.time,
    this.enabled = true,
    required this.createdAt,
    this.createdTime = '00:00',
  });

  final int? id;

  /// نام وعده (صبحانه، ناهار، میان‌وعده…).
  final String name;

  /// ساعت وعده به کلید «HH:mm».
  final String time;

  /// آیا برای این وعده یادآوری فعال است؟
  final bool enabled;

  /// تاریخ ثبت به کلید «yyyy-MM-dd».
  final String createdAt;

  /// ساعت دقیق ثبت به کلید «HH:mm»؛ وعده‌های قدیمی «00:00».
  final String createdTime;

  MealTime copyWith({
    int? id,
    String? name,
    String? time,
    bool? enabled,
    String? createdAt,
    String? createdTime,
  }) {
    return MealTime(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      createdTime: createdTime ?? this.createdTime,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'time': time,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt,
      'created_time': createdTime,
    };
  }

  factory MealTime.fromMap(Map<String, Object?> map) {
    return MealTime(
      id: map['id'] as int?,
      name: map['name'] as String,
      time: map['time'] as String,
      enabled: (map['enabled'] as int? ?? 1) != 0,
      createdAt: map['created_at'] as String,
      createdTime: map['created_time'] as String? ?? '00:00',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MealTime &&
      other.id == id &&
      other.name == name &&
      other.time == time &&
      other.enabled == enabled &&
      other.createdAt == createdAt &&
      other.createdTime == createdTime;

  @override
  int get hashCode =>
      Object.hash(id, name, time, enabled, createdAt, createdTime);
}

/// وضعیت ثبت‌شدهٔ یک وعده در یک روز.
class MealLog {
  const MealLog({
    this.id,
    required this.mealTimeId,
    required this.logDate,
    required this.status,
    required this.confirmedAt,
  });

  final int? id;
  final int mealTimeId;

  /// کلید تاریخ «yyyy-MM-dd».
  final String logDate;

  /// «eaten» یا «skipped».
  final String status;

  /// زمان تأیید به صورت ISO.
  final String confirmedAt;

  bool get isEaten => status == 'eaten';
  bool get isSkipped => status == 'skipped';

  /// وضعیت هم‌معنای نوبت دارو (برای استفاده از همان برچسب‌ها/نشان‌ها).
  DoseStatus get asDoseStatus =>
      isEaten ? DoseStatus.taken : DoseStatus.skipped;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'meal_time_id': mealTimeId,
      'log_date': logDate,
      'status': status,
      'confirmed_at': confirmedAt,
    };
  }

  factory MealLog.fromMap(Map<String, Object?> map) {
    return MealLog(
      id: map['id'] as int?,
      mealTimeId: map['meal_time_id'] as int,
      logDate: map['log_date'] as String,
      status: map['status'] as String,
      confirmedAt: map['confirmed_at'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MealLog &&
      other.id == id &&
      other.mealTimeId == mealTimeId &&
      other.logDate == logDate &&
      other.status == status &&
      other.confirmedAt == confirmedAt;

  @override
  int get hashCode =>
      Object.hash(id, mealTimeId, logDate, status, confirmedAt);
}
