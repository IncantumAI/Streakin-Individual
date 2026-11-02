// lib/shared/widgets/empty_state.dart
//
// Shared empty state: icon badge, title, supporting message, optional action.
// Gently fades/slides in on first build (instant when motion is reduced).

import 'package:flutter/material.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/shared/widgets/fade_slide_in.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Smaller variant for use inside cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final badge = compact ? 48.0 : 72.0;
    return FadeSlideIn(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: c.brandSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: compact ? AppSizes.iconLg : AppSizes.iconXl,
                    color: c.brandText,
                  ),
                ),
                SizedBox(height: compact ? AppSpace.md : AppSpace.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: compact
                      ? context.text.titleSmall
                      : context.text.titleMedium,
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ],
                if (action != null) ...[
                  SizedBox(height: compact ? AppSpace.md : AppSpace.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
