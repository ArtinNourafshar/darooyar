import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/backup/backup_service.dart';
import 'package:darooyar/core/notifications/notification_service.dart';
import 'package:darooyar/core/settings/settings_repository.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/health/health_provider.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/meals/meal_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';

/// انتخاب‌گر اقدام‌های بخش «امروز»: صدای زنگ (۳ گزینه) + پشتیبان‌گیری/بازیابی.
///
/// - صدای زنگ: انتخاب فوری و اعمال روی همهٔ زنگ‌های آینده.
/// - بکاپ: خروجی JSON در پوشهٔ گزارش‌ها + نمایش مسیر.
/// - بازیابی: انتخاب فایل + تأیید جایگزینی کامل + بارگذاری مجدد همهٔ بخش‌ها.
class TodayToolsMenu extends StatefulWidget {
  const TodayToolsMenu({super.key});

  @override
  State<TodayToolsMenu> createState() => _TodayToolsMenuState();
}

class _ToolAction {
  const _ToolAction.backup()
      : sound = null,
        restore = false;
  const _ToolAction.restore()
      : sound = null,
        restore = true;
  const _ToolAction.sound(this.sound) : restore = false;

  final int? sound;
  final bool restore;
}

class _TodayToolsMenuState extends State<TodayToolsMenu> {
  int _alarmSound = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSound());
  }

  Future<void> _loadSound() async {
    try {
      final value =
          await const SettingsRepository().get(SettingKeys.alarmSound);
      final index = int.tryParse(value ?? '') ?? 1;
      if (mounted) setState(() => _alarmSound = index);
    } catch (_) {
      // مقدار پیش‌فرض همان ۱ است.
    }
  }

  Future<void> _applySound(int index) async {
    try {
      await const SettingsRepository().set(SettingKeys.alarmSound, '$index');
      await NotificationService.instance.setAlarmSound(index);
    } catch (_) {}
    if (mounted) setState(() => _alarmSound = index);
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final path = await const BackupService().exportToFile();
      messenger.showSnackBar(
        SnackBar(content: Text('فایل بکاپ ذخیره شد:\n$path')),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('خطا در بکاپ‌گیری: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.pickFiles(
      dialogTitle: 'انتخاب فایل بکاپ دارویار',
      type: FileType.any,
    );
    if (picked.isEmpty) return;
    final path = picked.first.path;
    if (path == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بازیابی اطلاعات'),
        content: const Text(
          'همهٔ اطلاعات فعلی برنامه (افراد، داروها، وعده‌ها، گزارش‌ها و '
          'تنظیمات) با محتوای فایل بکاپ جایگزین می‌شود.\n\nادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بله، بازیابی شود'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await const BackupService().restoreFromFile(path);

      // بارگذاری مجدد به‌ترتیب (جلوگیری از تداخل زمان‌بندی زنگ‌ها).
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<ProfileProvider>().load();
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<MedicationProvider>().load();
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<MealProvider>().load();
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<ScheduleProvider>().load();
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<HealthProvider>().load();
      if (!mounted) throw const BackupException('صفحه بسته شد.');
      await context.read<ReportProvider>().load();

      messenger.showSnackBar(
        const SnackBar(content: Text('اطلاعات با موفقیت بازیابی شد.')),
      );
    } on BackupException catch (e) {
      if (e.message != 'صفحه بسته شد.') {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('خطا در بازیابی: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ToolAction>(
      tooltip: 'تنظیمات و پشتیبان‌گیری',
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert),
      enabled: !_busy,
      onSelected: (action) {
        if (action.sound != null) {
          _applySound(action.sound!);
        } else if (action.restore) {
          _restoreBackup();
        } else {
          _exportBackup();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<_ToolAction>(
          enabled: false,
          child: Text(
            'صدای زنگ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (var i = 1; i <= 3; i++)
          CheckedPopupMenuItem<_ToolAction>(
            value: _ToolAction.sound(i),
            checked: _alarmSound == i,
            child: Text('زنگ ${PersianUtils.toPersianDigits('$i')}'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<_ToolAction>(
          value: _ToolAction.backup(),
          child: Row(
            children: [
              Icon(Icons.save_alt_outlined, size: 20),
              SizedBox(width: 10),
              Text('پشتیبان‌گیری از اطلاعات'),
            ],
          ),
        ),
        const PopupMenuItem<_ToolAction>(
          value: _ToolAction.restore(),
          child: Row(
            children: [
              Icon(Icons.settings_backup_restore_outlined, size: 20),
              SizedBox(width: 10),
              Text('بازیابی اطلاعات'),
            ],
          ),
        ),
      ],
    );
  }
}
