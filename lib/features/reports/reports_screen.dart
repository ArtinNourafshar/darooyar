import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/reports/report_models.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';
import 'package:darooyar/shared/widgets/status_badge.dart';

/// صفحهٔ «گزارش»: بازه زمانی (امروز/هفتگی/ماهیانه/سالیانه)، فیلتر فرد،
/// آمار، نمودار مصرف، جریان فعالیت و خروجی PDF.
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

            final gutter = Scale.of(context).gutter;
            // ردیف‌ها به‌صورت تخت (سرگروه + فعالیت) ساخته می‌شوند تا رندر
            // **تنبل** باشد؛ بازه‌های بلند هزاران ردیف دارند.
            final items = _flatten(provider.activity);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RangeSelector(provider: provider),
                        const SizedBox(height: 12),
                        _ProfileFilter(provider: provider),
                        const SizedBox(height: 16),
                        _StatsGrid(stats: provider.stats),
                        if (provider.bars.any((b) => b.total > 0)) ...[
                          const SizedBox(height: 16),
                          _ConsumptionChart(bars: provider.bars),
                        ],
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
                        if (provider.range == ReportRange.all) ...[
                          const SizedBox(height: 12),
                          Text(
                            'نمایش حداکثر یک سال اخیر (۳۶۵ روز) از تاریخچه.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (items.isEmpty)
                          const EmptyState(
                            icon: Icons.bar_chart_outlined,
                            title: 'نوبتی در این بازه نیست',
                            message:
                                'برای این بازه داده‌ای ثبت نشده است. بازه یا فرد '
                                'دیگری را انتخاب کنید.',
                          )
                        else
                          Text(
                            'جریان فعالیت',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                      ],
                    ),
                  ),
                ),
                if (items.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final header = item.header;
                        if (header != null) return _DayHeader(dateKey: header);
                        return _ActivityRow(entry: item.entry!);
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// تخت‌کردن فعالیت‌ها: هر روز یک سرگروه، سپس فعالیت‌های همان روز.
  ///
  /// فهرست از قبل جدیدترین اول مرتب است؛ گروه‌ها به ترتیب ظاهر می‌شوند.
  List<({String? header, ActivityEntry? entry})> _flatten(
    List<ActivityEntry> activity,
  ) {
    final flat = <({String? header, ActivityEntry? entry})>[];
    String? lastHeader;
    for (final entry in activity) {
      if (entry.dateKey != lastHeader) {
        flat.add((header: entry.dateKey, entry: null));
        lastHeader = entry.dateKey;
      }
      flat.add((header: null, entry: entry));
    }
    return flat;
  }
}

/// سرگروه روز در جریان فعالیت (تاریخ شمسی + جداکننده).
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            PersianUtils.formatJalaliFromDateKey(dateKey),
            style: textTheme.titleSmall,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: scheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

/// ردیف یک فعالیت: دارو / وعده / شاخص سلامت.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final (icon, tint) = switch (entry.kind) {
      ActivityKind.dose => (
          Icons.medication_outlined,
          entry.profileColorValue == null
              ? scheme.primary
              : Color(entry.profileColorValue!),
        ),
      ActivityKind.meal => (Icons.restaurant_outlined, scheme.primary),
      ActivityKind.health => (Icons.favorite_outline, scheme.tertiary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 46,
              child: Text(
                PersianUtils.formatTimeString(entry.timeKey),
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (entry.status != null) ...[
              const SizedBox(width: 8),
              StatusBadge(status: entry.status!, compact: true),
            ],
          ],
        ),
      ),
    );
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
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
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

/// نمودار مصرف: ستون‌های دوتایی (خورده شد / نخورده) به تفکیک ساعت، روز یا ماه.
class _ConsumptionChart extends StatelessWidget {
  const _ConsumptionChart({required this.bars});

  final List<ReportBar> bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // در راست‌چین، قدیمی‌تر سمت راست و جدیدتر سمت چپ قرار می‌گیرد.
    final n = bars.length;
    int xOf(int index) => isRtl ? n - 1 - index : index;

    final rodWidth = n <= 10 ? 14.0 : n <= 31 ? 7.0 : 4.0;
    final maxTotal =
        bars.fold<int>(0, (max, b) => b.total > max ? b.total : max);
    final maxY = maxTotal <= 4 ? 4.0 : (maxTotal + 1).toDouble();

    // برچسب‌ها در ستون‌های زیاد فاصله‌گذاری می‌شوند تا روی هم نیفتند.
    final labelStep = n <= 10 ? 1 : n <= 31 ? 5 : 12;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('روند مصرف', style: textTheme.titleSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => scheme.surfaceContainerHigh,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'خورده شد' : 'مصرف نشده';
                        return BarTooltipItem(
                          '${PersianUtils.toPersianDigits(rod.toY.round().toString())}\n$label',
                          textTheme.labelMedium!.copyWith(
                            color: scheme.onSurface,
                            height: 1.4,
                          ),
                          textDirection: TextDirection.rtl,
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final x = value.toInt();
                          if (x < 0 || x >= n) return const SizedBox.shrink();
                          final index = isRtl ? n - 1 - x : x;
                          if (index % labelStep != 0 && index != n - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bars[index].label,
                              style: textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < n; i++)
                      BarChartGroupData(
                        x: xOf(i),
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: bars[i].taken.toDouble(),
                            width: rodWidth,
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: bars[i].notTaken.toDouble(),
                            width: rodWidth,
                            color: const Color(0xFF3FB6F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: scheme.primary, label: 'خورده شد'),
                const SizedBox(width: 20),
                _LegendDot(color: const Color(0xFF3FB6F2), label: 'مصرف نشده'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
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
