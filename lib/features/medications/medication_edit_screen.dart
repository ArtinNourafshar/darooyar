import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile.dart';

/// فرم افزودن/ویرایش دارو: نام، دوز، فردِ صاحب دارو و زمان‌های مصرف.
class MedicationEditScreen extends StatefulWidget {
  const MedicationEditScreen({
    super.key,
    required this.profiles,
    this.medication,
  });

  final List<Profile> profiles;

  /// در حالت ویرایش مقدار دارد.
  final Medication? medication;

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late int _profileId;
  late List<String> _times;
  bool _saving = false;

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameController = TextEditingController(text: med?.name ?? '');
    _doseController = TextEditingController(text: med?.dose ?? '');
    _profileId = med?.profileId ??
        (widget.profiles.isNotEmpty ? widget.profiles.first.id! : 0);
    _times = [...?med?.times];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش دارو' : 'افزودن دارو'),
      ),
      body: ContentMaxWidth(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Scale.of(context).maxFormWidth == double.infinity
                ? 16
                : 0,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Scale.of(context).maxFormWidth,
              ),
              child: _form(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مشخصات دارو', style: textTheme.titleMedium),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'نام دارو',
              hintText: 'مثلاً استامینوفن',
              prefixIcon: Icon(Icons.medication_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'نام دارو را وارد کنید';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _doseController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'دوز مصرف',
              hintText: 'مثلاً ۱ قرص یا ۵ میلی‌لیتر',
              prefixIcon: Icon(Icons.science_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'دوز مصرف را وارد کنید';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _profileId,
            decoration: const InputDecoration(
              labelText: 'متعلق به',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              for (final profile in widget.profiles)
                DropdownMenuItem<int>(
                  value: profile.id,
                  child: Text(profile.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _profileId = value);
            },
            validator: (value) =>
                value == null ? 'فرد را انتخاب کنید' : null,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Text('زمان‌های مصرف', style: textTheme.titleMedium)),
              FilledButton.tonalIcon(
                onPressed: _pickTime,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('افزودن ساعت'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_times.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'حداقل یک زمان مصرف اضافه کنید تا یادآوری ساخته شود.',
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _times.length; i++)
                  _timeChip(context, _times[i], i),
              ],
            ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving
                ? 'در حال ذخیره…'
                : _isEditing
                    ? 'ذخیره تغییرات'
                    : 'ثبت دارو'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              label: Text(
                'حذف دارو',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _timeChip(BuildContext context, String time, int index) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 18),
          const SizedBox(width: 6),
          Text(
            PersianUtils.formatTimeString(time),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          IconButton(
            tooltip: 'حذف ساعت',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: () => setState(() => _times.removeAt(index)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (picked == null) return;
    final timeKey =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    if (_times.contains(timeKey)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'ساعت ${PersianUtils.formatTimeString(timeKey)} قبلاً ثبت شده است',
          ),
        ),
      );
      return;
    }
    setState(() {
      _times.add(timeKey);
      _times.sort();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک زمان مصرف اضافه کنید')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<MedicationProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final times = [..._times]..sort();

    bool ok;
    if (_isEditing) {
      final updated = widget.medication!.copyWith(
        name: _nameController.text.trim(),
        dose: _doseController.text.trim(),
        profileId: _profileId,
        times: times,
      );
      ok = await provider.update(updated);
    } else {
      ok = await provider.add(Medication(
        profileId: _profileId,
        name: _nameController.text.trim(),
        dose: _doseController.text.trim(),
        times: times,
        createdAt: PersianUtils.dateKey(DateTime.now()),
      ));
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (_isEditing ? 'دارو به‌روزرسانی شد' : 'دارو ثبت شد')
              : (provider.error ?? 'خطا در ذخیره دارو'),
        ),
      ),
    );
    if (ok) navigator.pop();
    setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final name = widget.medication!.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف دارو؟'),
        content: Text(
          'داروی «$name» و سابقهٔ مصرف آن حذف می‌شود. این عمل قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final provider = context.read<MedicationProvider>();
    final navigator = Navigator.of(context);
    final ok = await provider.delete(widget.medication!.id!);
    if (!mounted) return;
    if (ok) navigator.pop();
    setState(() => _saving = false);
  }
}
