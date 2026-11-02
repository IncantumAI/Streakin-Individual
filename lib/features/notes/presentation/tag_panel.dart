// lib/features/notes/presentation/tag_panel.dart
// Tag filter panel — shown below the folder tree in the sidebar.
// Displays all unique tags as chips; tapping one filters the note list.
// Spec §4.4.1 (tags), §4.4.3 (sort by tag).

import 'package:streakin/core/design/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';

class TagPanel extends ConsumerWidget {
  const TagPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final activeTag = ref.watch(activeTagFilterProvider);
    final colors = context.colors;

    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: colors.outline, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (activeTag != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          ref.read(activeTagFilterProvider.notifier).set(null),
                      child: Text(
                        'Clear',
                        style: TextStyle(fontSize: 11, color: colors.brand),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) {
                  final isActive = tag == activeTag;
                  return _TagChip(
                    tag: tag,
                    isActive: isActive,
                    onTap: () {
                      final notifier = ref.read(
                        activeTagFilterProvider.notifier,
                      );
                      if (isActive) {
                        notifier.set(null);
                      } else {
                        notifier.set(tag);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.isActive,
    required this.onTap,
  });

  final String tag;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? colors.brand.withValues(alpha: 0.15)
              : colors.surfaceAlt,
          border: Border.all(color: isActive ? colors.brand : colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.tagIcon,
              size: 12,
              color: isActive ? colors.brand : colors.textMuted,
            ),
            const SizedBox(width: 3),
            Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? colors.brand : colors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
