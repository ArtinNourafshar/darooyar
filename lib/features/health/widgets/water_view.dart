import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/health_provider.dart';

/// برگهٔ «نوشیدن آب»: شمارندهٔ لیوان‌های امروز، هدف روزانه،
/// نمودار ۷ روزه و یادآوری اختیاری.
class WaterView extends StatelessWidget {
  const WaterView({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TodayCard(health: health),
        const SizedBox(height: 16),
        _WeekChart(week: health.waterWeek, target: health.waterTarget),
        const SizedBox(height: 16),
        _ReminderCard(health: health),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// کارت اصلی امروز: شمارنده + دکمه‌های افزودن/حذف + هدف.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.health});

  final HealthProvider health;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = PersianUtils.toPersianDigits;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.calm,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFF0B4A6F)),
              const SizedBox(width: 8),
              Text(
                'لیوان‌های امروز',
                style: textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0B4A6F),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تغییر هدف روزانه',
                icon: const Icon(Icons.flag_outlined, color: Color(0xFF0B4A6F)),
                onPressed: () => _editTarget(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${p('${health.waterCupsToday}')} از ${p('${health.waterTarget}')} لیوان',
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF06283D),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: health.waterProgress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              color: const Color(0xFF1E9BE9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E9BE9),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('یک لیوان آب خوردم'),
                  onPressed: () => health.addCup(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'حذف آخرین لیوان',
                iconSize: 22,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  foregroundColor: const Color(0xFF0B4A6F),
                ),
                onPressed:
                    health.waterCupsToday == 0 ? null : () => health.removeLastCup(),
                icon: const Icon(Icons.undo),
              ),
            ],
          ),
          if (health.waterCupsToday >= health.waterTarget) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.celebration_outlined,
                    size: 18, color: Color(0xFF0B4A6F)),
                const SizedBox(width: 6),
                Text(
                  'هدف امروز را کامل کردید! آفرین!',
                  style: textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF0B4A6F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editTarget(BuildContext context) async {
    final controller = TextEditingController(
      text: '${health.waterTarget}',
    );
    final messenger = ScaffoldMessenger.of(context);

    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هدف روزانهٔ آب'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'تعداد لیوان در روز',
            hintText: 'مثلاً ۸',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = PersianUtils.parseNumber(controller.text);
              if (parsed != null) {
                Navigator.pop(context, parsed.round());
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final ok = await health.setWaterTarget(value);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('خطا در ذخیرهٔ هدف')),
      );
    }
  }
}

/// نمودار ستونی ۷ روز اخیر (فل‌چارت، راست‌چین).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.week, required this.target});

  final Map<String, int> week;
  final int target;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (week.values.every((v) => v == 0)) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.bar_chart, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'با ثبت لیوان‌های آب، نمودار هفتگی اینجا ساخته می‌شود.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ستون‌ها: قدیمی → جدید (فل‌چارت داخل RTL خودش آینه می‌کند).
    final days = week.keys.toList(growable: false)..sort();
    final maxCups = [
      target,
      ...week.values,
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('۷ روز اخیر', style: textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _bar(
                          context,
                          cups: week[day] ?? 0,
                          maxCups: maxCups,
                          label: PersianUtils.toPersianDigits(
                            day.split('-').last,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E9BE9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'تعداد لیوان هر روز (خطوط‌چین: هدف روزانه)',
                  style: textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required int cups,
    required int maxCups,
    required String label,
  }) {
    final ratio = maxCups <= 0 ? 0.0 : (cups / maxCups).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          PersianUtils.toPersianDigits('$cups'),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: ratio == 0 ? 0.04 : ratio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF1E9BE9), Color(0xFF7FD1FF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// کارت یادآوری اختیاری نوشیدن آب.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.health});

  final HealthProvider health;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('یادآوری نوشیدن آب'),
              subtitle: Text(
                'هر روز بین ساعت ۸ صبح تا ۱۰ شب، یادآوری ساده دریافت می‌کنید.',
                style:
                    textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              value: health.waterReminderEnabled,
              onChanged: (v) => health.setWaterReminderEnabled(v),
            ),
            if (health.waterReminderEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'بازهٔ یادآوری:',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('هر ۱ ساعت')),
                        ButtonSegment(value: 2, label: Text('هر ۲ ساعت')),
                        ButtonSegment(value: 3, label: Text('هر ۳ ساعت')),
                      ],
                      selected: {health.waterReminderInterval},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          health.setWaterReminderInterval(selection.first),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
