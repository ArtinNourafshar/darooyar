import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/theme/app_gradients.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/meals/meal.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/schedule/dose_log.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';
import 'package:darooyar/shared/widgets/status_badge.dart';

/// برگهٔ «برنامهٔ غذایی»: پیشرفت امروز، فهرست وعده‌ها با یادآوری،
/// ویرایش/حذف/افزودن وعده با انتخاب‌گر ساعت.
class MealPlanView extends StatelessWidget {
  const MealPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    final meals = context.watch<MealProvider>();
    final scale = Scale.of(context);

    if (meals.loading && meals.meals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (meals.meals.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant_outlined,
        title: 'هنوز وعده‌ای ثبت نشده',
        message: 'وعده‌های پیش‌فرض (صبحانه، ناهار، شام) ساخته می‌شوند؛ '
            'می‌توانید وعده دلخواه اضافه کنید.',
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: scale.gutter, vertical: 12),
      children: [
        _TodayProgressCard(meals: meals),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'وعده‌های روزانه',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showEditDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('افزودن وعده'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final meal in meals.meals)
          _MealCard(
            meal: meal,
            statusOf: _statusOf(meals, meal),
            onToggle: (enabled) => _toggle(context, meal, enabled),
            onEdit: () => _showEditDialog(context, existing: meal),
            onDelete: () => _confirmDelete(context, meal),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  DoseStatus? _statusOf(MealProvider meals, MealTime meal) {
    final id = meal.id;
    if (id == null) return null;
    for (final slot in meals.slots) {
      if (slot.mealId == id) return slot.status;
    }
    return null;
  }

  Future<void> _toggle(
    BuildContext context,
    MealTime meal,
    bool enabled,
  ) async {
    final provider = context.read<MealProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.save(meal.copyWith(enabled: enabled));
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'خطا در ذخیرهٔ وعده')),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    MealTime? existing,
  }) async {
    final result = await showDialog<MealTime>(
      context: context,
      builder: (context) => _MealEditDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;

    final provider = context.read<MealProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.save(result);
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'خطا در ذخیرهٔ وعده')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, MealTime meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف وعدهٔ «${meal.name}»؟'),
        content: const Text('یادآوری این وعده حذف می‌شود.'),
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
    if (confirmed != true || !context.mounted) return;

    final provider = context.read<MealProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final id = meal.id;
    if (id == null) return;
    final ok = await provider.delete(id);
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'خطا در حذف وعده')),
      );
    }
  }
}

/// کارت پیشرفت وعده‌های امروز با گرادیان برند.
class _TodayProgressCard extends StatelessWidget {
  const _TodayProgressCard({required this.meals});

  final MealProvider meals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = PersianUtils.toPersianDigits;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'امروز ${p('${meals.eatenCount}')} از ${p('${meals.total}')} '
            'وعده ثبت شده',
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFF3A1B00),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: meals.progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFFFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF7A2F),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _CountChip(
                icon: Icons.error_outline,
                label: 'سپری شده بدون ثبت: ${p('${meals.missedCount}')}',
              ),
              _CountChip(
                icon: Icons.schedule,
                label: 'در انتظار: ${p('${meals.upcomingCount}')}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7A2B00)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF7A2B00),
              ),
        ),
      ],
    );
  }
}

/// کارت یک وعده: نام، ساعت، وضعیت امروز، یادآوری، ویرایش و حذف.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.statusOf,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MealTime meal;
  final DoseStatus? statusOf;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.restaurant_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ساعت ${PersianUtils.formatTimeString(meal.time)}'
                    '${meal.enabled ? '' : ' — یادآوری خاموش'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (statusOf != null) StatusBadge(status: statusOf!, compact: true),
            IconButton(
              tooltip: meal.enabled ? 'خاموش کردن یادآوری' : 'روشن کردن یادآوری',
              icon: Icon(
                meal.enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: meal.enabled ? scheme.primary : scheme.outline,
              ),
              onPressed: () => onToggle(!meal.enabled),
            ),
            IconButton(
              tooltip: 'ویرایش',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// دیالوگ افزودن/ویرایش وعده با انتخاب‌گر ساعت سیستم.
class _MealEditDialog extends StatefulWidget {
  const _MealEditDialog({this.existing});

  final MealTime? existing;

  @override
  State<_MealEditDialog> createState() => _MealEditDialogState();
}

class _MealEditDialogState extends State<_MealEditDialog> {
  late final TextEditingController _nameController;
  late TimeOfDay _time;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _time = _parseTime(existing?.time ?? '12:00');
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 12,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(widget.existing == null ? 'افزودن وعده' : 'ویرایش وعده'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'نام وعده'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('ساعت یادآوری'),
            subtitle: Text(PersianUtils.formatTimeString(timeLabel)),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('یادآوری فعال باشد'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(onPressed: _save, child: const Text('ذخیره')),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'ساعت وعده را انتخاب کنید',
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final timeKey =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();

    final existing = widget.existing;
    final meal = existing == null
        ? MealTime(
            name: name,
            time: timeKey,
            enabled: _enabled,
            // لحظهٔ ثبت: نوبت‌های پیش از این لحظه برای امروز ساخته نمی‌شوند.
            createdAt: PersianUtils.dateKey(now),
            createdTime: PersianUtils.timeKey(now),
          )
        : existing.copyWith(name: name, time: timeKey, enabled: _enabled);

    Navigator.pop(context, meal);
  }
}
