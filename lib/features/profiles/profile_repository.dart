import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/features/profiles/profile.dart';

/// دسترسی داده‌ای افراد (پروفایل‌ها).
class ProfileRepository {
  const ProfileRepository();

  Database get _db => DatabaseService.instance.db;

  Future<List<Profile>> getAll() async {
    final rows = await _db.query('profiles', orderBy: 'id ASC');
    return rows.map(Profile.fromMap).toList(growable: false);
  }

  Future<Profile> insert(Profile profile) async {
    final id = await _db.insert('profiles', profile.toMap());
    return profile.copyWith(id: id);
  }

  Future<void> update(Profile profile) async {
    await _db.update(
      'profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  /// حذف فرد؛ داروها و سوابق مصرف او به خاطر ON DELETE CASCADE حذف می‌شوند.
  Future<void> delete(int id) async {
    await _db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  /// تعداد داروهای هر فرد (برای نمایش در کارت افراد).
  Future<Map<int, int>> medicationCounts() async {
    final rows = await _db.rawQuery(
      'SELECT profile_id, COUNT(*) AS cnt FROM medications GROUP BY profile_id',
    );
    return {
      for (final row in rows)
        row['profile_id'] as int: row['cnt'] as int,
    };
  }
}
