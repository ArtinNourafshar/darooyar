import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_prompts.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';

/// ساخت «خلاصهٔ وضعیت» برای پرامپت‌های دستیار.
///
/// فقط اعداد و آمار کلی (تعداد نوبت‌ها، شاخص‌های سلامت) در این متن می‌آیند؛
/// با فعال نکردن دستیار هیچ داده‌ای از اپ خارج نمی‌شود.
String buildAiSnapshot(BuildContext context) {
  final schedule = context.read<ScheduleProvider>();
  final meals = context.read<MealProvider>();
  final health = context.read<HealthProvider>();

  final p = PersianUtils.toPersianDigits;

  final adherence = schedule.total == 0
      ? null
      : 'امروز ${p('${schedule.takenCount}')} از ${p('${schedule.total}')} '
          'نوبت دارو خورده شده'
          '${schedule.missedCount > 0 ? '؛ ${p('${schedule.missedCount}')} نوبت مصرف نشده' : ''}';

  final mealSummary = meals.total == 0
      ? null
      : 'امروز ${p('${meals.eatenCount}')} از ${p('${meals.total}')} وعده '
          'ثبت شده'
          '${meals.missedCount > 0 ? '؛ ${p('${meals.missedCount}')} وعده سپری شده بدون ثبت' : ''}';

  return AiPrompts.healthSnapshot(
    dateLabel: AiPrompts.todayLabel(),
    health: health.aiSummary(),
    adherence: adherence,
    meals: mealSummary,
  );
}
