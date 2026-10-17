import 'package:sqflite/sqflite.dart';

import 'package:darooyar/core/database/database_service.dart';

/// یک بینش ذخیره‌شدهٔ هوش مصنوعی (مثلاً بررسی روزانهٔ سلامت).
class AiInsight {
  const AiInsight({
    this.id,
    required this.day,
    required this.kind,
    required this.text,
    required this.createdAt,
  });

  final int? id;

  /// روزِ مربوطه به کلید «yyyy-MM-dd».
  final String day;

  /// نوع بینش: «daily» یا «analysis».
  final String kind;
  final String text;

  /// زمان ساخت به صورت ISO.
  final String createdAt;

  factory AiInsight.fromMap(Map<String, Object?> map) {
    return AiInsight(
      id: map['id'] as int?,
      day: map['day'] as String,
      kind: map['kind'] as String,
      text: map['text'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

/// ذخیرهٔ بینش‌های هوش مصنوعی در پایگاه‌دادهٔ محلی.
class AiInsightRepository {
  const AiInsightRepository();

  Database get _db => DatabaseService.instance.db;

  /// آخرین بینش یک نوع (برای نمایش کارت اول صفحه).
  Future<AiInsight?> latest(String kind) async {
    final rows = await _db.query(
      'ai_insights',
      where: 'kind = ?',
      whereArgs: [kind],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiInsight.fromMap(rows.first);
  }

  /// بینش امروز از نوع [kind] (برای جلوگیری از اجرای دوبارهٔ روزانه).
  Future<AiInsight?> forDay(String day, String kind) async {
    final rows = await _db.query(
      'ai_insights',
      where: 'day = ? AND kind = ?',
      whereArgs: [day, kind],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiInsight.fromMap(rows.first);
  }

  Future<void> save({
    required String day,
    required String kind,
    required String text,
    required String createdAt,
  }) async {
    await _db.insert(
      'ai_insights',
      {
        'day': day,
        'kind': kind,
        'text': text,
        'created_at': createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// نگه‌داشتن حداکثر ۶۰ بینش آخر (جلوگیری از رشد بی‌انتها).
  Future<void> prune({int keep = 60}) async {
    await _db.execute('''
      DELETE FROM ai_insights WHERE id NOT IN (
        SELECT id FROM ai_insights ORDER BY created_at DESC LIMIT ?
      )
    ''', [keep]);
  }
}
