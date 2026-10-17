import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/bmi_calculator.dart';
import 'package:darooyar/features/health/health_metric.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';

/// برگهٔ «شاخص‌های بدن»: انتخاب فرد، کارت BMI/قد، شبکهٔ ثبت شاخص‌ها،
/// نمودار ۳۰ روزه و فهرست آخرین ثبت‌ها با امکان حذف.
class BodyMetricsView extends StatefulWidget {
  const BodyMetricsView({super.key});

  @override
  State<BodyMetricsView> createState() => _BodyMetricsViewState();
}

class _BodyMetricsViewState extends State<BodyMetricsView> {
  /// شاخصِ انتخاب‌شده برای نمودار و فهرست ثبت‌ها.
  String _metricKey = HealthMetric.weight.dbKey;

  @override
  void initState() {
    super.initState();
    // تاریخچهٔ شاخص پیش‌فرض پس از اولین فریم بارگذاری می‌شود.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  void _loadHistory() {
    if (!mounted) return;
    final health = context.read<HealthProvider>();
    if (health.profileId == null) return;
    if (health.historyOf(_metricKey).isEmpty) {
      health.loadHistory(_metricKey);
    }
  }

  void _selectMetric(String key) {
    if (_metricKey == key) return;
    setState(() => _metricKey = key);
    final health = context.read<HealthProvider>();
    if (health.historyOf(key).isEmpty) {
      health.loadHistory(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final scale = Scale.of(context);
    final metric = HealthMetric.fromDbKey(_metricKey);

    if (health.profiles.isEmpty) {
      if (health.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const EmptyState(
        icon: Icons.favorite_outline,
        title: 'هنوز فردی ثبت نشده',
        message: 'شاخص‌های سلامت متعلق به یک فرد است؛ ابتدا در بخش «افراد» '
            'اعضای خانواده را اضافه کنید.',
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: scale.gutter, vertical: 12),
      children: [
        _buildProfileChips(health),
        const SizedBox(height: 12),
        _buildBmiCard(health),
        const SizedBox(height: 16),
        _buildMetricGrid(health, metric),
        const SizedBox(height: 16),
        if (metric != null) ...[
          _buildChartCard(health, metric),
          const SizedBox(height: 16),
        ],
        _buildRecentList(health, metric),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── انتخاب فرد ─────────────────────────────────────────────────────

  Widget _buildProfileChips(HealthProvider health) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final profile in health.profiles)
          ChoiceChip(
            label: Text(profile.name),
            selected: profile.id == health.profileId,
            avatar: CircleAvatar(
              backgroundColor: Color(profile.colorValue),
            ),
            onSelected: (_) => _select(profile),
          ),
      ],
    );
  }

  Future<void> _select(Profile profile) async {
    final health = context.read<HealthProvider>();
    if (health.profileId == profile.id) return;
    await health.selectProfile(profile.id);
    // پس از تعویض فرد، تاریخچهٔ شاخص انتخابی برای فرد جدید بارگذاری شود.
    if (mounted) _loadHistory();
  }

  // ── کارت BMI و قد ──────────────────────────────────────────────────

  Widget _buildBmiCard(HealthProvider health) {
    final bmi = health.bmi;
    final height = health.heightCm;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'شاخص تودهٔ بدنی (BMI)',
                  style: textTheme.titleSmall
                      ?.copyWith(color: const Color(0xFF7A2B00)),
                ),
                const SizedBox(height: 6),
                Text(
                  bmi == null
                      ? '—'
                      : BmiCalculator.format(bmi.value),
                  style: textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF3A1B00),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bmi == null
                      ? 'برای محاسبه، وزن و قد لازم است.'
                      : '${bmi.category.label} — ${bmi.category.advice}',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A2B00),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const Icon(Icons.height, color: Color(0xFF7A2B00)),
              const SizedBox(height: 4),
              Text(
                height == null
                    ? '—'
                    : PersianUtils.toPersianDigits(
                        '${height.round()} سانتی',
                      ),
                style: textTheme.labelLarge
                    ?.copyWith(color: const Color(0xFF3A1B00)),
              ),
              TextButton(
                onPressed: () => _showHeightDialog(health),
                child: Text(height == null ? 'ثبت قد' : 'ویرایش قد'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showHeightDialog(HealthProvider health) async {
    final controller = TextEditingController(
      text: health.heightCm == null
          ? ''
          : PersianUtils.toPersianDigits('${health.heightCm!.round()}'),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قد (سانتی‌متر)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'مثلاً ۱۷۰'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = _parseNumber(controller.text);
              if (parsed != null && parsed >= 50 && parsed <= 250) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    if (value != null) {
      await health.setHeight(value);
    }
  }

  // ── شبکهٔ شش شاخص ─────────────────────────────────────────────────

  Widget _buildMetricGrid(HealthProvider health, HealthMetric? selected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in HealthMetric.values)
              SizedBox(
                width: width,
                child: _MetricCard(
                  metric: metric,
                  latest: health.latest[metric.dbKey],
                  selected: metric == selected,
                  onTap: () => _showAddLogDialog(health, metric),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showAddLogDialog(
    HealthProvider health,
    HealthMetric metric,
  ) async {
    final controller1 = TextEditingController();
    final controller2 = TextEditingController();
    var sleepQuality = 3;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('ثبت ${metric.label}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller1,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: switch (metric) {
                      HealthMetric.bloodPressure => 'سیستول (بالا)',
                      HealthMetric.sleep => 'ساعت خواب',
                      _ => 'مقدار (${metric.unit})',
                    },
                  ),
                ),
                if (metric.hasSecondValue &&
                    metric != HealthMetric.sleep) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller2,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'دیاستول (پایین)',
                    ),
                  ),
                ],
                if (metric == HealthMetric.sleep) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'کیفیت خواب: ${PersianUtils.toPersianDigits('$sleepQuality')} از ۵',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Slider(
                    value: sleepQuality.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: PersianUtils.toPersianDigits('$sleepQuality'),
                    onChanged: (v) =>
                        setDialogState(() => sleepQuality = v.round()),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                final v1 = _parseNumber(controller1.text);
                if (v1 == null || v1 <= 0) return;

                double? v2;
                if (metric == HealthMetric.sleep) {
                  v2 = sleepQuality.toDouble();
                } else if (metric == HealthMetric.bloodPressure) {
                  v2 = _parseNumber(controller2.text);
                  if (v2 == null || v2 <= 0) return;
                }
                Navigator.pop(context, true);
                _save(health, metric, v1, v2);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    controller1.dispose();
    controller2.dispose();
  }

  Future<void> _save(
    HealthProvider health,
    HealthMetric metric,
    double value1,
    double? value2,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await health.addLog(
      metric: metric,
      value1: value1,
      value2: value2,
    );
    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(health.error ?? 'خطا در ثبت شاخص')),
      );
    }
    // نمودار همیشه با شاخص انتخابی همگام است.
    if (mounted && metric.dbKey == _metricKey) {
      await context.read<HealthProvider>().loadHistory(_metricKey);
    }
  }

  // ── نمودار ۳۰ روزه ─────────────────────────────────────────────────

  Widget _buildChartCard(HealthProvider health, HealthMetric metric) {
    final history = health.historyOf(metric.dbKey);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(metric.icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'روند ۳۰ روزهٔ ${metric.label}',
                    style: textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.length < 2)
              Text(
                'برای نمودار دست‌کم دو ثبت لازم است.',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              SizedBox(
                height: 200,
                child: _LineChart(metric: metric, history: history),
              ),
            // انتخابگر شاخص نمودار
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in HealthMetric.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == metric,
                    onSelected: (_) => _selectMetric(m.dbKey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── آخرین ثبت‌ها ──────────────────────────────────────────────────

  Widget _buildRecentList(HealthProvider health, HealthMetric? metric) {
    if (metric == null) return const SizedBox.shrink();
    final history = health.historyOf(metric.dbKey);
    if (history.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final recent = history.reversed.take(30).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('آخرین ثبت‌ها', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final log in recent)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(metric.icon, color: scheme.primary),
              title: Text(_formatValue(metric, log)),
              subtitle: Text(
                '${PersianUtils.formatJalaliFromDateKey(log.logDate)} — '
                '${PersianUtils.formatTimeString(log.logTime)}',
              ),
              trailing: IconButton(
                tooltip: 'حذف ثبت',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(health, log),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(HealthProvider health, HealthLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ثبت؟'),
        content: const Text('این ثبت برای همیشه حذف می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || log.id == null) return;

    await health.deleteLog(log.id!);
    if (mounted) {
      await context.read<HealthProvider>().loadHistory(_metricKey);
    }
  }

  String _formatValue(HealthMetric metric, HealthLog log) {
    final p = PersianUtils.toPersianDigits;
    switch (metric) {
      case HealthMetric.bloodPressure:
        return '${p(log.value1.round().toString())}/'
            '${p((log.value2 ?? 0).round().toString())} mmHg';
      case HealthMetric.sleep:
        return '${p(log.value1.toStringAsFixed(1))} ساعت — '
            'کیفیت ${p((log.value2 ?? 0).round().toString())} از ۵';
      default:
        final digits = (metric == HealthMetric.weight ||
                metric == HealthMetric.bodyFat)
            ? 1
            : 0;
        return '${p(log.value1.toStringAsFixed(digits))} ${metric.unit}';
    }
  }
}

/// کارت یک شاخص در شبکه.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.latest,
    required this.selected,
    required this.onTap,
  });

  final HealthMetric metric;
  final HealthLog? latest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String value;
    if (latest == null) {
      value = 'ثبت نشده';
    } else {
      final p = PersianUtils.toPersianDigits;
      value = switch (metric) {
        HealthMetric.bloodPressure =>
          '${p(latest!.value1.round().toString())}/${p((latest!.value2 ?? 0).round().toString())}',
        HealthMetric.sleep =>
          '${p(latest!.value1.toStringAsFixed(1))} ساعت',
        _ => p(latest!.value1.toStringAsFixed(
            (metric == HealthMetric.weight || metric == HealthMetric.bodyFat)
                ? 1
                : 0,
          )),
      };
    }

    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                metric.icon,
                size: 22,
                color: selected ? scheme.onPrimaryContainer : scheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                metric.label,
                style: textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: latest == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نمودار خطی ۳۰ روزه (برای فشار خون دو خط: سیستول/دیاستول).
class _LineChart extends StatelessWidget {
  const _LineChart({required this.metric, required this.history});

  final HealthMetric metric;
  final List<HealthLog> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // در راست‌چین، قدیمی‌تر سمت راست و جدیدتر سمت چپ قرار می‌گیرد.
    final n = history.length;
    double xOf(int index) => isRtl ? (n - 1 - index).toDouble() : index.toDouble();

    final primarySpots = [
      for (var i = 0; i < n; i++) FlSpot(xOf(i), history[i].value1),
    ];
    final secondarySpots = metric.hasSecondValue
        ? [
            for (var i = 0; i < n; i++)
              if (history[i].value2 != null)
                FlSpot(xOf(i), history[i].value2!),
          ]
        : const <FlSpot>[];

    final allValues = [
      ...primarySpots.map((s) => s.y),
      ...secondarySpots.map((s) => s.y),
    ];
    var minY = allValues.reduce((a, b) => a < b ? a : b);
    var maxY = allValues.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.2 < 1 ? 1.0 : (maxY - minY) * 0.2;
    minY -= pad;
    maxY += pad;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble().clamp(1, double.infinity),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (n / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= n) {
                  return const SizedBox.shrink();
                }
                final parts = history[index].logDate.split('-');
                if (parts.length != 3) return const SizedBox.shrink();
                final day = int.tryParse(parts[2]) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    PersianUtils.toPersianDigits('$day'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: primarySpots,
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: scheme.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.08),
            ),
          ),
          if (secondarySpots.length >= 2)
            LineChartBarData(
              spots: secondarySpots,
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 3,
              color: const Color(0xFF3FB6F2),
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

/// تبدیل متن ورودی کاربر (با ارقام فارسی/عربی) به عدد.
double? _parseNumber(String raw) {
  final normalized = raw
      .trim()
      .replaceAll('٫', '.')
      .replaceAll('،', '')
      .replaceAll(',', '')
      .replaceAll(' ', '');
  final buffer = StringBuffer();
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const latin = '0123456789';
  for (final ch in normalized.split('')) {
    final fi = fa.indexOf(ch);
    final ai = ar.indexOf(ch);
    buffer.write(fi != -1 ? latin[fi] : ai != -1 ? latin[ai] : ch);
  }
  return double.tryParse(buffer.toString());
}
