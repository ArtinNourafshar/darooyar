import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/health/widgets/body_metrics_view.dart';
import 'package:darooyar/features/health/widgets/water_view.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';

/// صفحهٔ «سلامت» با دو برگه: «شاخص‌های بدن» و «نوشیدن آب».
///
/// (برنامهٔ غذایی اکنون سکشن جداگانهٔ خودش — «وعده‌ها» — را دارد.)
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  /// برگهٔ انتخاب‌شده: ۰ = شاخص‌های بدن، ۱ = نوشیدن آب.
  int _tab = 0;
  bool _initialLoadStarted = false;

  @override
  void initState() {
    super.initState();
    // بارگذاری اولیه بعد از اولین فریم تا listenerها نصب شده باشند.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  void _initialLoad() {
    if (_initialLoadStarted || !mounted) return;
    _initialLoadStarted = true;

    final health = context.read<HealthProvider>();
    if (health.latest.isEmpty && !health.loading) {
      health.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final scale = Scale.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سلامت')),
      body: ContentMaxWidth(
        child: health.profiles.isEmpty
            ? _buildEmptyProfiles(health)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: scale.gutter,
                      vertical: 12,
                    ),
                    child: _buildSegmented(context),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      children: const [BodyMetricsView(), WaterView()],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSegmented(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SegmentedButton<int>(
      segments: const [
        ButtonSegment<int>(
          value: 0,
          label: Text('شاخص‌های بدن'),
          icon: Icon(Icons.favorite_outline),
        ),
        ButtonSegment<int>(
          value: 1,
          label: Text('نوشیدن آب'),
          icon: Icon(Icons.water_drop_outlined),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (selection) =>
          setState(() => _tab = selection.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
      ),
    );
  }

  /// حالت نبودِ فرد: پیام راهنما بدون اقدام (افراد در بخش خودش مدیریت می‌شوند).
  Widget _buildEmptyProfiles(HealthProvider health) {
    if (health.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const EmptyState(
      icon: Icons.favorite_outline,
      title: 'هنوز فردی ثبت نشده',
      message:
          'شاخص‌های سلامت متعلق به یک فرد است. در بخش «افراد» اعضای خانواده را '
          'اضافه کنید، سپس شاخص‌های هر نفر را ثبت کنید.',
    );
  }
}
