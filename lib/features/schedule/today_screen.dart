import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';
import 'package:darooyar/shared/widgets/status_badge.dart';

/// صفحهٔ «امروز»: تاریخ، نوار پیشرفت، نوار یادآوری نوبت‌های دیرشده
/// و فهرست نوبت‌های امروز با دکمه‌های «خوردم / نخوردم».
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.onGoToMedications});

  /// پرش به بخش «داروها» از حالت خالی.
  final VoidCallback? onGoToMedications;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('امروز')),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ContentMaxWidth(
          child: Builder(
            builder: (context) {
              if (provider.loading && provider.slots.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.error != null && provider.slots.isEmpty) {
                return _ErrorView(message: provider.error!, onRetry: provider.load);
              }
              if (provider.slots.isEmpty) {
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
                  _DateHeader(provider: provider),
                  const SizedBox(height: 16),
                  if (provider.dueNow.isNotEmpty) ...[
                    _DueBanner(provider: provider),
                    const SizedBox(height: 16),
                  ],
                  ..._sections(context, provider),
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

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.provider});

  final ScheduleProvider provider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        PersianUtils.jalaliWeekday(now),
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PersianUtils.formatJalaliLong(now),
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    PersianUtils.toPersianDigits(
                      '${provider.takenCount} از ${provider.total}',
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: provider.progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _countChip(
                  context,
                  label: 'در انتظار',
                  count: provider.upcomingCount,
                  color: scheme.onSurfaceVariant,
                ),
                _countChip(
                  context,
                  label: 'مصرف نشده',
                  count: provider.missedCount,
                  color: scheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countChip(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Text(
      PersianUtils.toPersianDigits('$label: $count'),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
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
        const SizedBox(height: 6),
        Text(slot.medicationName, style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          'دوز: ${slot.dose}',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
