import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';
import 'package:darooyar/features/medications/medication.dart';

/// دسترسی داده‌ای داروها.
class MedicationRepository {
  const MedicationRepository();

  Database get _db => DatabaseService.instance.db;

  Future<List<Medication>> getAll() async {
    final rows = await _db.query('medications', orderBy: 'id ASC');
    return rows.map(Medication.fromMap).toList(growable: false);
  }

  Future<List<Medication>> getByProfile(int profileId) async {
    final rows = await _db.query(
      'medications',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'id ASC',
    );
    return rows.map(Medication.fromMap).toList(growable: false);
  }

  Future<Medication> insert(Medication medication) async {
    final id = await _db.insert('medications', medication.toMap());
    return medication.copyWith(id: id);
  }

  Future<void> update(Medication medication) async {
    await _db.update(
      'medications',
      medication.toMap(),
      where: 'id = ?',
      whereArgs: [medication.id],
    );
  }

  /// حذف دارو؛ سابقهٔ مصرف آن نیز حذف می‌شود (ON DELETE CASCADE).
  Future<void> delete(int id) async {
    await _db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}
