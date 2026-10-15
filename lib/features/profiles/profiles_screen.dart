import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/features/reports/report_provider.dart';
import 'package:darooyar/features/schedule/schedule_provider.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';

/// رنگ‌های قابل انتخاب برای شناسایی افراد (پالت مات).
const List<int> kProfileColors = [
  0xFF16706B,
  0xFF3F6FA8,
  0xFF8A5A9E,
  0xFFB06A3B,
  0xFF4E7D3F,
  0xFFA8485C,
  0xFF5B6470,
  0xFF96733F,
];

/// صفحهٔ «افراد»: اعضای خانواده + افزودن/ویرایش/حذف.
class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('افراد')),
      body: ContentMaxWidth(
        child: Builder(
          builder: (context) {
            if (provider.loading && provider.profiles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.profiles.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.sizeOf(context).height * 0.08,
                    ),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: 'هنوز فردی ثبت نشده',
                      message:
                          'برای هر عضو خانواده یک فرد بسازید تا داروهایش را '
                          'جداگانه پیگیری کنید.',
                      actionLabel: 'افزودن فرد',
                      onAction: () => _showEditor(context),
                    ),
                  ),
                ],
              );
            }

            final scale = Scale.of(context);
            return ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: scale.gutter,
                vertical: 16,
              ),
              itemCount: provider.profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final profile = provider.profiles[index];
                return _ProfileCard(
                  profile: profile,
                  medicationCount:
                      provider.medicationCounts[profile.id] ?? 0,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: provider.profiles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('افزودن فرد'),
            ),
    );
  }

  static Future<void> _showEditor(BuildContext context, [Profile? profile]) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ProfileEditorDialog(profile: profile),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.medicationCount});

  final Profile profile;
  final int medicationCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: profile.color,
              child: Text(
                profile.name.isNotEmpty ? profile.name.characters.first : '؟',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    PersianUtils.toPersianDigits(
                      '$medicationCount دارو ثبت‌شده',
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'ویرایش',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ProfileEditorDialog(profile: profile),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline, color: scheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    // پرووایدرها پیش از await گرفته می‌شوند؛ چون پس از حذف، این کارت از
    // درخت حذف می‌شود و context دیگر قابل استفاده نیست.
    final provider = context.read<ProfileProvider>();
    final medications = context.read<MedicationProvider>();
    final schedule = context.read<ScheduleProvider>();
    final report = context.read<ReportProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فرد؟'),
        content: Text(
          'فرد «${profile.name}»، همهٔ داروها و سابقهٔ مصرف او حذف می‌شود. '
          'این عمل قابل بازگشت نیست.',
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
    if (confirmed == true && profile.id != null) {
      final ok = await provider.delete(profile.id!);
      if (ok) {
        // حذف فرد، داروها و سوابقش را با ON DELETE CASCADE از پایگاه‌داده
        // پاک می‌کند؛ کش سایر پرووایدرها باید هم‌زمان تازه شود تا یادآوری‌های
        // داروهای حذف‌شده دوباره زمان‌بندی نشوند و آمار گزارش درست بماند.
        medications.load();
        schedule.load();
        report.load();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فرد «${profile.name}» حذف شد')),
        );
      }
    }
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({this.profile});

  final Profile? profile;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _color;
  bool _saving = false;

  bool get _isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _color = widget.profile?.colorValue ?? kProfileColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(_isEditing ? 'ویرایش فرد' : 'افزودن فرد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'نام فرد',
                  hintText: 'مثلاً مادر، سارا، امیر…',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'نام فرد را وارد کنید';
                  }
                  if (value.trim().length > 30) {
                    return 'نام نباید بیش از ۳۰ حرف باشد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('رنگ شناسایی', style: textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colorValue in kProfileColors)
                    _colorOption(colorValue),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEditing ? 'ذخیره' : 'افزودن'),
        ),
      ],
    );
  }

  Widget _colorOption(int colorValue) {
    final selected = _color == colorValue;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _color = colorValue),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<ProfileProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    bool ok;
    if (_isEditing) {
      ok = await provider.update(
        widget.profile!.copyWith(name: name, colorValue: _color),
      );
    } else {
      ok = await provider.add(name: name, colorValue: _color);
    }

    // اگر کاربر هنگام ذخیره، دیالوگ را با ضربه بیرون بسته باشد، mounted
    // false می‌شود؛ در این حالت نباید pop زده شود چون صفحهٔ زیرین برمی‌گردد.
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (_isEditing ? 'فرد به‌روزرسانی شد' : 'فرد اضافه شد')
              : (provider.error ?? 'خطا در ذخیره فرد'),
        ),
      ),
    );
    if (ok) navigator.pop();
    setState(() => _saving = false);
  }
}
