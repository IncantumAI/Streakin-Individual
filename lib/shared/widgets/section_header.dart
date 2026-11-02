// lib/shared/widgets/section_header.dart

import 'package:flutter/material.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';

/// Small uppercase section label with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.xs,
      AppSpace.xl,
      AppSpace.xs,
      AppSpace.sm,
    ),
  });

  final String title;

  /// Usually a [TextButton] such as "See all".
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: AppTypography.overline.copyWith(color: c.textMuted),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
