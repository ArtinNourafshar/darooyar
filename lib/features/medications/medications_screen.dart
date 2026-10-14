import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:darooyar/core/responsive/responsive.dart';
import 'package:darooyar/core/utils/persian_utils.dart';
import 'package:darooyar/features/medications/medication.dart';
import 'package:darooyar/features/medications/medication_edit_screen.dart';
import 'package:darooyar/features/medications/medication_provider.dart';
import 'package:darooyar/features/profiles/profile_provider.dart';
import 'package:darooyar/shared/widgets/empty_state.dart';

/// صفحهٔ «داروها»: فهرست داروهای هر فرد + افزودن/ویرایش/حذف.
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key, this.onGoToProfiles});

  /// پرش به بخش «افراد» وقتی هنوز فردی ثبت نشده است.
  final VoidCallback? onGoToProfiles;

  @override
  Widget build(BuildContext context) {
    final profilesProvider = context.watch<ProfileProvider>();
    final medicationsProvider = context.watch<MedicationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('داروها')),
      body: ContentMaxWidth(
        child: Builder(
          builder: (context) {
            if (profilesProvider.profiles.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.sizeOf(context).height * 0.08,
                    ),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: 'ابتدا فردی ثبت کنید',
                      message:
                          'دارو متعلق به یک فرد است. در بخش «افراد» اعضای '
                          'خانواده را اضافه کنید، سپس داروهای هر نفر را '
                          'ثبت کنید.',
                      actionLabel: 'افزودن فرد',
                      onAction: onGoToProfiles,
                    ),
                  ),
                ],
              );
            }

            if (medicationsProvider.loading &&
                medicationsProvider.medications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final profiles = profilesProvider.profiles;
            final scale = Scale.of(context);

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: scale.gutter,
                vertical: 16,
              ),
              children: [
                for (final profile in profiles) ...[
                  _ProfileSection(
                    profileName: profile.name,
                    profileColor: profile.colorValue,
                    profileId: profile.id!,
                    count: medicationsProvider.countForProfile(profile.id!),
                    meds: medicationsProvider.forProfile(profile.id!),
                  ),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
      floatingActionButton: profilesProvider.profiles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('افزودن دارو'),
            ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final profiles = context.read<ProfileProvider>().profiles;
    if (profiles.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicationEditScreen(profiles: profiles),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.profileName,
    required this.profileColor,
    required this.profileId,
    required this.count,
    required this.meds,
  });

  final String profileName;
  final int profileColor;
  final int profileId;
  final int count;
  final List<Medication> meds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scale = Scale.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(profileColor),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(profileName, style: textTheme.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                PersianUtils.toPersianDigits('$count دارو'),
                style: textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (meds.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.medication_liquid_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'برای این فرد هنوز دارویی ثبت نشده است.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnCount(
                constraints.maxWidth,
                scale.maxGridColumns,
              );
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.1 : 2.4,
                children: [
                  for (final med in meds)
                    _MedicationCard(medication: med),
                ],
              );
            },
          ),
      ],
    );
  }

  int _columnCount(double width, int maxColumns) {
    if (width >= 900) return maxColumns.clamp(1, 3);
    if (width >= 620) return maxColumns.clamp(1, 2);
    return 1;
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final times = medication.times;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medication.name,
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'ویرایش',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'دوز: ${medication.dose}',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final time in times)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          PersianUtils.formatTimeString(time),
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final profiles = context.read<ProfileProvider>().profiles;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicationEditScreen(
          profiles: profiles,
          medication: medication,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<MedicationProvider>();
    final name = medication.name;
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
    if (confirmed == true && medication.id != null) {
      await provider.delete(medication.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('داروی «$name» حذف شد')),
        );
      }
    }
  }
}
