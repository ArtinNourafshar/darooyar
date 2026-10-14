/// مدل دارو — ثبت: نام، دوز و یک یا چند زمان مصرف در روز.
class Medication {
  const Medication({
    this.id,
    required this.profileId,
    required this.name,
    required this.dose,
    required this.times,
    required this.createdAt,
  });

  /// شناسهٔ داخلی (پس از ذخیره در پایگاه‌داده).
  final int? id;

  /// شناسهٔ فردِ صاحب این دارو.
  final int profileId;

  /// نام دارو، مثلاً «استامینوفن».
  final String name;

  /// دوز، مثلاً «۱ قرص» یا «۵ میلی‌لیتر».
  final String dose;

  /// زمان‌های مصرف به صورت «HH:mm» مرتب‌شده، مثلاً ['08:00', '20:00'].
  final List<String> times;

  /// تاریخ ثبت دارو به کلید «yyyy-MM-dd» (برای گزارش تاریخچه).
  final String createdAt;

  Medication copyWith({
    int? id,
    int? profileId,
    String? name,
    String? dose,
    List<String>? times,
    String? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      times: times ?? this.times,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// زمان‌های مصرف به صورت انتزاعیِ [TimeOfDay]-مانند برای زمان‌بندی.
  List<({int hour, int minute})> get parsedTimes {
    return times.map((raw) {
      final parts = raw.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return (hour: hour, minute: minute);
    }).toList(growable: false);
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'name': name,
      'dose': dose,
      'times': times.join(','),
      'created_at': createdAt,
    };
  }

  factory Medication.fromMap(Map<String, Object?> map) {
    final rawTimes = (map['times'] as String)
        .split(',')
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();
    return Medication(
      id: map['id'] as int?,
      profileId: map['profile_id'] as int,
      name: map['name'] as String,
      dose: map['dose'] as String,
      times: rawTimes,
      createdAt: map['created_at'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Medication &&
      other.id == id &&
      other.profileId == profileId &&
      other.name == name &&
      other.dose == dose &&
      other.createdAt == createdAt &&
      _sameTimes(other.times, times);

  static bool _sameTimes(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, profileId, name, dose, createdAt);
}
