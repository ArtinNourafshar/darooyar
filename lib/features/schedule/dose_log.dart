/// وضعیت تأیید یک نوبت مصرف.
enum DoseStatus {
  /// تأییدشده: «خوردم».
  taken,

  /// تأییدشده: «نخوردم».
  skipped,

  /// بدون تأیید و زمانش گذشته — «مصرف نشده».
  missed,

  /// بدون تأیید و در آینده — «در انتظار».
  upcoming,
}

/// یک ردیف ثبت‌شده در پایگاه‌داده برای نوبت مصرف.
class DoseLog {
  const DoseLog({
    this.id,
    required this.medicationId,
    required this.logDate,
    required this.logTime,
    required this.status,
    required this.confirmedAt,
  });

  final int? id;
  final int medicationId;

  /// کلید تاریخ «yyyy-MM-dd».
  final String logDate;

  /// ساعت نوبت «HH:mm».
  final String logTime;

  /// «taken» یا «skipped».
  final String status;

  /// زمان تأیید به صورت ISO.
  final String confirmedAt;

  bool get isTaken => status == 'taken';
  bool get isSkipped => status == 'skipped';

  factory DoseLog.fromMap(Map<String, Object?> map) {
    return DoseLog(
      id: map['id'] as int?,
      medicationId: map['medication_id'] as int,
      logDate: map['log_date'] as String,
      logTime: map['log_time'] as String,
      status: map['status'] as String,
      confirmedAt: map['confirmed_at'] as String,
    );
  }
}

/// برچسب فارسی وضعیت‌ها.
extension DoseStatusLabel on DoseStatus {
  String get label => switch (this) {
        DoseStatus.taken => 'خورده شد',
        DoseStatus.skipped => 'نخوردم',
        DoseStatus.missed => 'مصرف نشده',
        DoseStatus.upcoming => 'در انتظار',
      };

  String get actionLabel => switch (this) {
        DoseStatus.taken => 'خوردم',
        DoseStatus.skipped => 'نخوردم',
        DoseStatus.missed => 'مصرف نشده',
        DoseStatus.upcoming => 'در انتظار',
      };
}
