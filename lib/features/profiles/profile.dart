import 'package:flutter/material.dart';

/// مدل فرد خانواده (دارندهٔ داروها).
class Profile {
  const Profile({
    this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  final int? id;

  /// نام فرد، مثلاً «مادر».
  final String name;

  /// رنگ شناسایی فرد در رابط کاربری.
  final int colorValue;

  /// تاریخ ثبت به کلید «yyyy-MM-dd».
  final String createdAt;

  Color get color => Color(colorValue);

  Profile copyWith({int? id, String? name, int? colorValue, String? createdAt}) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color_value': colorValue,
      'created_at': createdAt,
    };
  }

  factory Profile.fromMap(Map<String, Object?> map) {
    return Profile(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorValue: map['color_value'] as int,
      createdAt: map['created_at'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, colorValue, createdAt);
}
