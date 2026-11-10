import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/ai/ai_provider.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/meals/meal_slot.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/features/schedule/today_tools_menu.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';
import 'package:darooyar/shared/widgets/status_badge.dart';

/// صفحهٔ «امروز»: هیروی گرادیانی، نوار یادآوری نوبت‌های دیرشده،
/// وعده‌های غذایی، کارت بررسی روزانهٔ دستیار و فهرست نوبت‌های دارو.
class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    this.onGoToMedications,
    this.onGoToAssistant,
  });

  /// پرش به بخش «داروها» از حالت خالی.
  final VoidCallback? onGoToMedications;

  /// پرش به بخش «دستیار» از کارت بررسی روزانه.
  final VoidCallback? onGoToAssistant;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final meals = context.watch<MealProvider>();
    final ai = context.watch<AiProvider>();
    final medications = context.watch<MedicationProvider>();

    final hasDoses = provider.slots.isNotEmpty;
    final hasMeals = meals.slots.isNotEmpty || meals.meals.isNotEmpty;
    final lowStock = medications.lowStock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('امروز'),
        actions: const [TodayToolsMenu(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.load();
          await meals.load();
          await medications.load();
        },
        child: ContentMaxWidth(
          child: Builder(
            builder: (context) {
              if (provider.loading && !hasDoses && !hasMeals) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.error != null && !hasDoses && !hasMeals) {
                return _ErrorView(message: provider.error!, onRetry: provider.load);
              }
              if (!hasDoses && !hasMeals) {
                return ListView(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.sizeOf(context).height * 0.08,
                      ),
                      child: EmptyState(
                        icon: Icons.medication_outlined,
                        title: 'هنوز نوبتی ثبت نشده',
                        message:
                            'برای ساخت برنامهٔ امروز، اول دارویی ثبت کنید. '
                            'داروی هر فرد را در بخش «داروها» اضافه کنید.',
                        actionLabel: 'افزودن دارو',
                        onAction: onGoToMedications,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: Scale.of(context).gutter,
                  vertical: 16,
                ),
                children: [
                  _HeroCard(provider: provider),
                  const SizedBox(height: 16),
                  if (provider.dueNow.isNotEmpty) ...[
                    _DueBanner(provider: provider),
                    const SizedBox(height: 16),
                  ],
                  if (lowStock.isNotEmpty) ...[
                    _RefillBanner(medications: lowStock),
                    const SizedBox(height: 16),
                  ],
                  if (ai.dailyInsight != null) ...[
                    _AiInsightCard(
                      text: ai.dailyInsight!.text,
                      onTap: onGoToAssistant,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (hasMeals) ...[
                    _MealsSection(meals: meals),
                    const SizedBox(height: 16),
                  ],
                  if (hasDoses) ..._sections(context, provider),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, ScheduleProvider provider) {
    final grouped = provider.slotsByTime;
    final keys = grouped.keys.toList(growable: false)..sort();
    final scale = Scale.of(context);

    return [
      for (final timeKey in keys) ...[
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                PersianUtils.formatTimeString(timeKey),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
        for (final slot in grouped[timeKey]!)
          Padding(
            padding: EdgeInsets.only(bottom: scale.by(12)),
            child: _DoseCard(
              slot: slot,
              onConfirm: (status) => provider.confirm(slot, status),
            ),
          ),
      ],
    ];
  }
}

/// هیروی مدرن: سلام شخصی + تاریخ + درصد پیشرفت روز روی گرادیان زمردی،
/// با دایره‌های تزئینی نیمه‌شفاف و چیپ‌های شیشه‌ای (روشن و تیره).
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.provider});

  final ScheduleProvider provider;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'صبح بخیر ☀️';
    if (hour < 14) return 'ظهر بخیر 🌤️';
    if (hour < 18) return 'عصر بخیر 🌇';
    return 'شب بخیر 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (provider.progress * 100).round();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.heroDark : AppGradients.hero,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7C66).withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // دایره‌های تزئینی نیمه‌شفاف (عمق بصری).
          Positioned(
            top: -46,
            left: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            PersianUtils.formatJalaliLong(now),
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // حلقهٔ درصد پیشرفت.
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        PersianUtils.toPersianDigits('$percent٪'),
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  PersianUtils.toPersianDigits(
                    '${provider.takenCount} از ${provider.total} نوبت خورده شده',
                  ),
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (provider.streakDays > 0)
                      _glassChip(
                        textTheme,
                        icon: Icons.local_fire_department,
                        label:
                            '${provider.streakDays} روز پیاپی مصرف کامل',
                        strong: true,
                      ),
                    _glassChip(
                      textTheme,
                      icon: Icons.hourglass_bottom,
                      label: 'در انتظار: ${provider.upcomingCount}',
                    ),
                    if (provider.missedCount > 0)
                      _glassChip(
                        textTheme,
                        icon: Icons.error_outline,
                        label: 'مصرف نشده: ${provider.missedCount}',
                        warn: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// چیپ شیشه‌ای (سفید نیمه‌شفاف)؛ در حالت هشدار زرد کهربایی می‌شود.
  Widget _glassChip(
    TextTheme textTheme, {
    required IconData icon,
    required String label,
    bool strong = false,
    bool warn = false,
  }) {
    final color = warn
        ? const Color(0xFFFFD166)
        : strong
            ? const Color(0xFFFFE5A0)
            : Colors.white.withValues(alpha: 0.92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            PersianUtils.toPersianDigits(label),
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت کوتاه بررسی روزانهٔ دستیار (با ضربه به بخش دستیار می‌رود).
class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بررسی روزانهٔ دستیار', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// بخش وعده‌های غذایی امروز با دکمه‌های «خوردم / نخوردم».
class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.meals});

  final MealProvider meals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (meals.slots.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.restaurant_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'برنامهٔ غذایی در بخش «وعده‌ها» تعریف کنید تا اینجا نمایش داده شود.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_outlined,
                size: 20, color: scheme.primary),
            const SizedBox(width: 6),
            Text('وعده‌های امروز', style: textTheme.titleMedium),
            const Spacer(),
            Text(
              PersianUtils.toPersianDigits(
                '${meals.eatenCount} از ${meals.total}',
              ),
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final slot in meals.slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MealCard(
              slot: slot,
              onConfirm: (status) => meals.confirm(slot, status),
            ),
          ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.slot, required this.onConfirm});

  final MealSlot slot;
  final void Function(DoseStatus? status) onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final confirmed =
        slot.status == DoseStatus.taken || slot.status == DoseStatus.skipped;

    final statusColor = switch (slot.status) {
      DoseStatus.taken => scheme.primary,
      DoseStatus.skipped => scheme.tertiary,
      DoseStatus.missed => scheme.error,
      DoseStatus.upcoming => scheme.secondary,
    };

    final info = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withValues(alpha: 0.45)),
          ),
          child: Icon(
            confirmed ? Icons.restaurant : Icons.restaurant_outlined,
            size: 21,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot.name, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      slot.timeLabel,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = confirmed
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(status: slot.status),
              TextButton(
                onPressed: () => onConfirm(null),
                child: const Text('تغییر'),
              ),
            ],
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => onConfirm(DoseStatus.taken),
                child: const Text('خوردم'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => onConfirm(DoseStatus.skipped),
                child: const Text('نخوردم'),
              ),
            ],
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 14),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  const _DueBanner({required this.provider});

  final ScheduleProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = provider.dueNow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'نوبت‌های دیرشده — لطفاً تأیید کنید',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final slot in due)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      PersianUtils.toPersianDigits(
                        '${slot.timeLabel} — داروی ${slot.medicationName} '
                        '(${slot.profileName})',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => provider.confirm(slot, DoseStatus.taken),
                    child: const Text('خوردم'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// بنر هشدار اتمام دارو (داروهایی که به آستانه رسیده‌اند).
class _RefillBanner extends StatelessWidget {
  const _RefillBanner({required this.medications});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'دارو رو به پایان است — دوباره تهیه کنید',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final med in medications)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      PersianUtils.toPersianDigits(
                        'داروی ${med.name} — ${med.remainingDoses ?? 0} واحد باقی',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.slot, required this.onConfirm});

  final DoseSlot slot;
  final void Function(DoseStatus? status) onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final confirmed = slot.status == DoseStatus.taken ||
        slot.status == DoseStatus.skipped;

    // رنگ و آیکون وضعیت نوبت.
    final (statusColor, statusIcon) = switch (slot.status) {
      DoseStatus.taken => (scheme.primary, Icons.check_circle),
      DoseStatus.skipped => (scheme.tertiary, Icons.remove_circle_outline),
      DoseStatus.missed => (scheme.error, Icons.error),
      DoseStatus.upcoming => (scheme.outline, Icons.schedule),
    };

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(slot.profileColorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                slot.profileName,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // نشان دایره‌ای وضعیت.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.45),
                ),
              ),
              child: Icon(statusIcon, size: 21, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.medicationName, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'دوز: ${slot.dose}',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // چیپ ساعت مصرف.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 14,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    slot.timeLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final actions = _Actions(
      slot: slot,
      confirmed: confirmed,
      onConfirm: onConfirm,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // در عرض‌های کافی، اقدامات کنار متن قرار می‌گیرند.
            if (constraints.maxWidth >= 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 14),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.slot,
    required this.confirmed,
    required this.onConfirm,
  });

  final DoseSlot slot;
  final bool confirmed;
  final void Function(DoseStatus? status) onConfirm;

  @override
  Widget build(BuildContext context) {
    if (confirmed) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(status: slot.status),
          TextButton(
            onPressed: () => onConfirm(null),
            child: const Text('تغییر'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => onConfirm(DoseStatus.taken),
          icon: const Icon(Icons.check, size: 20),
          label: const Text('خوردم'),
        ),
        OutlinedButton.icon(
          onPressed: () => onConfirm(DoseStatus.skipped),
          icon: const Icon(Icons.close, size: 20),
          label: const Text('نخوردم'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
          ],
        ),
      ),
    );
  }
}
