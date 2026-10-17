import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/features/meals/meal_plan_view.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';

/// سکشن جداگانهٔ «وعده‌ها»: ثبت وعده‌های غذایی و زمان‌بندی آن‌ها.
///
/// زنگ/یادآوری هر وعده **اختیاری** است: هر وعده یک کلید جداگانه
/// (آیکون زنگ) دارد و بدون روشن کردن آن، وعده فقط ثبت می‌شود.
class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  bool _initialLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  void _initialLoad() {
    if (_initialLoadStarted || !mounted) return;
    _initialLoadStarted = true;

    final meals = context.read<MealProvider>();
    if (meals.meals.isEmpty && !meals.loading) {
      meals.load();
    }

    // نوبت‌های امروز (برای نشان وضعیت هر وعده) نیز لازم است.
    final schedule = context.read<ScheduleProvider>();
    if (schedule.slots.isEmpty && !schedule.loading) {
      schedule.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وعده‌ها')),
      body: const MealPlanView(),
    );
  }
}
