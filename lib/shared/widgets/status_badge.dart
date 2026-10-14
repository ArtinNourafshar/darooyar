import 'package:flutter/material.dart';

import 'package:darooyar/features/schedule/dose_log.dart';

/// نشان وضعیت نوبت مصرف با رنگ‌بندی مات و خوانا.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final DoseStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground, icon) = switch (status) {
      DoseStatus.taken => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.check_circle_outline,
        ),
      DoseStatus.skipped => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.remove_circle_outline,
        ),
      DoseStatus.missed => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
      DoseStatus.upcoming => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.schedule,
        ),
    };

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 18, color: foreground),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: compact ? 12 : 13,
                ),
          ),
        ],
      ),
    );
  }
}
