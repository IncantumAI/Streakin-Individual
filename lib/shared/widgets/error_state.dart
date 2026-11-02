// lib/shared/widgets/error_state.dart
//
// Friendly error presentation with retry. The raw error is logged (redacted
// by AppLogger) instead of being shown to the user.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/core/logging/app_logger.dart';
import 'package:streakin/shared/widgets/fade_slide_in.dart';

final _log = AppLogger.get('ErrorState');

class ErrorState extends StatelessWidget {
  ErrorState({
    super.key,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.title = 'Something went wrong',
    this.message = 'We couldn’t load this right now. Your data is safe.',
  }) : compact = false {
    _logOnce();
  }

  /// Single-line variant for use inside cards and lists.
  ErrorState.inline({
    super.key,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.title = 'Couldn’t load',
    this.message,
  }) : compact = true {
    _logOnce();
  }

  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String title;
  final String? message;
  final bool compact;

  void _logOnce() {
    if (error != null) _log.warning('UI error state', error, stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(AppIcons.errorOutline, size: AppSizes.iconMd, color: c.danger),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                message == null ? title : '$title · $message',
                style: context.text.bodySmall,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return FadeSlideIn(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.dangerSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.errorOutline, size: 28, color: c.danger),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpace.xl),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(AppIcons.autorenew, size: AppSizes.iconMd),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
