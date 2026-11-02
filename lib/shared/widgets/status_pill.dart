// lib/shared/widgets/status_pill.dart

import 'package:flutter/material.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';

enum PillTone { neutral, brand, success, warning, danger }

/// Compact rounded label. Never encodes meaning by colour alone: always
/// carries text, optionally an icon.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
    this.color,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;

  /// Custom accent (e.g. habit colour); overrides [tone].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg) = color != null
        ? (color!.withValues(alpha: 0.14), c.text)
        : switch (tone) {
            PillTone.neutral => (c.surfaceAlt, c.textMuted),
            PillTone.brand => (c.brandSubtle, c.brandText),
            PillTone.success => (c.successSubtle, c.success),
            PillTone.warning => (c.warningSubtle, c.warning),
            PillTone.danger => (c.dangerSubtle, c.danger),
          };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs + 1,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color ?? fg),
            const SizedBox(width: AppSpace.xs),
          ],
          Text(
            label,
            style: context.text.labelMedium!.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
