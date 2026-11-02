// lib/shared/widgets/settings_group.dart
//
// Grouped settings rows (iOS/Material 3 inset-grouped style): a rounded
// outlined surface with hairline dividers between rows.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/icons.dart';
import 'package:streakin/core/design/spacing.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/typography.dart';
import 'package:streakin/shared/widgets/section_header.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    required this.children,
    this.footer,
  });

  final String? title;
  final List<Widget> children;

  /// Helper text shown under the group.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(indent: AppSpace.lg + 32 + AppSpace.md, color: c.outline),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) SectionHeader(title!),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: c.outline),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.brLg,
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: rows),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xs,
              AppSpace.sm,
              AppSpace.xs,
              0,
            ),
            child: Text(footer!, style: context.text.bodySmall),
          ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  }) : _switchValue = null,
       _onSwitch = null,
       _chevron = false;

  /// Row with a trailing chevron that navigates.
  const SettingsTile.nav({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  }) : _switchValue = null,
       _onSwitch = null,
       _chevron = true;

  /// Row with a trailing switch; the whole row toggles it.
  const SettingsTile.toggle({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.enabled = true,
  }) : _switchValue = value,
       _onSwitch = onChanged,
       trailing = null,
       onTap = null,
       destructive = false,
       _chevron = false;

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;
  final bool? _switchValue;
  final ValueChanged<bool>? _onSwitch;
  final bool _chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? c.danger : c.text;
    final isSwitch = _switchValue != null;

    Widget? trailingWidget = trailing;
    if (isSwitch) {
      trailingWidget = Switch(
        value: _switchValue,
        onChanged: enabled ? _onSwitch : null,
      );
    } else if (_chevron) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: AppSpace.xs),
          ],
          Icon(
            AppIcons.chevronRight,
            size: AppSizes.iconMd,
            color: c.textMuted,
          ),
        ],
      );
    }

    final tap = !enabled
        ? null
        : isSwitch
        ? (_onSwitch == null ? null : () => _onSwitch(!_switchValue))
        : onTap;

    return MergeSemantics(
      child: InkWell(
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: destructive ? c.dangerSubtle : c.brandSubtle,
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: destructive ? c.danger : c.brandText,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.text.bodyLarge!.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpace.xxs),
                          Text(subtitle!, style: context.text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    trailingWidget,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered, width-limited scroll body for settings-style pages.
class ReadableListView extends StatelessWidget {
  const ReadableListView({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppSpace.pagePadding(constraints.maxWidth);
        return ListView(
          padding:
              padding ??
              EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, AppSpace.xxxl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpace.readableWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
