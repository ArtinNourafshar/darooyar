import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/dose_slot.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';
import 'package:darooyar/shared/widgets/status_badge.dart';

/// صفحهٔ «گزارش»: بازهٔ زمانی، فیلتر فرد، آمار، جدول تاریخچه و خروجی PDF.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('گزارش')),
      body: ContentMaxWidth(
        child: Builder(
          builder: (context) {
            if (provider.loading && provider.rows.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: Scale.of(context).gutter,
                vertical: 16,
              ),
              children: [
                _RangeSelector(provider: provider),
                const SizedBox(height: 12),
                _ProfileFilter(provider: provider),
                const SizedBox(height: 16),
                _StatsGrid(stats: provider.stats),
                const SizedBox(height: 16),
                _ExportButton(provider: provider),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (provider.rows.isEmpty)
                  const EmptyState(
                    icon: Icons.bar_chart_outlined,
                    title: 'نوبتی در این بازه نیست',
                    message:
                        'برای این بازه داده‌ای ثبت نشده است. بازه یا فرد '
                        'دیگری را انتخاب کنید.',
                  )
                else
                  ..._dayGroups(context, provider.rows),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  /// گروه‌بندی ردیف‌ها بر اساس روز + سرگروه شمسی.
  List<Widget> _dayGroups(BuildContext context, List<DoseSlot> rows) {
    final groups = <String, List<DoseSlot>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.dateKey, () => []).add(row);
    }
    final keys = groups.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a)); // جدیدترین روز بالاتر

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return [
      for (final key in keys) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                PersianUtils.formatJalaliFromDateKey(key),
                style: textTheme.titleSmall,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: scheme.outlineVariant),
              ),
            ],
          ),
        ),
        for (final row in groups[key]!) _ReportRow(row: row),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.provider});

  final ReportProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('بازهٔ زمانی', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final range in ReportRange.values)
              ChoiceChip(
                label: Text(range.label),
                selected: provider.range == range,
                onSelected: (_) => provider.setRange(range),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileFilter extends StatelessWidget {
  const _ProfileFilter({required this.provider});

  final ReportProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('فرد', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('همه'),
              selected: provider.profileId == null,
              onSelected: (_) => provider.setProfile(null),
            ),
            for (final profile in provider.allProfiles)
              ChoiceChip(
                label: Text(profile.name),
                selected: provider.profileId == profile.id,
                onSelected: (_) => provider.setProfile(profile.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ReportStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'خورده شد', value: stats.taken, emphasized: true, percent: false),
      (label: 'نخوردم', value: stats.skipped, emphasized: false, percent: false),
      (
        label: 'مصرف نشده',
        value: stats.missed,
        emphasized: false,
        percent: false
      ),
      (
        label: 'پایبندی',
        value: stats.adherencePercent.round(),
        emphasized: true,
        percent: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 420
                ? 2
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _StatCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final ({
    String label,
    int value,
    bool emphasized,
    bool percent,
  }) item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = item.percent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                PersianUtils.toPersianDigits(
                  percent ? '${item.value}٪' : '${item.value}',
                ),
                style: textTheme.headlineMedium?.copyWith(
                  color: item.emphasized ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.provider});

  final ReportProvider provider;

  @override
  Widget build(BuildContext context) {
    final canExport = provider.hasRows && !provider.exporting;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canExport ? () => _export(context) : null,
            icon: provider.exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              provider.exporting ? 'در حال ساخت PDF…' : 'خروجی PDF',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final provider = context.read<ReportProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final path = await provider.exportPdf();
    if (path == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'خطا در ساخت PDF'),
        ),
      );
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF ذخیره شد اما باز نشد:\n$path'),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('گزارش PDF ذخیره و باز شد')),
      );
    }
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.row});

  final DoseSlot row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                row.timeLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.medicationName,
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.profileName} — دوز: ${row.dose}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: row.status, compact: true),
          ],
        ),
      ),
    );
  }
}
