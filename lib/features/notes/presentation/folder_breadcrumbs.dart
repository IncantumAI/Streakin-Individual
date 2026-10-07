// lib/features/notes/presentation/folder_breadcrumbs.dart
// Breadcrumb row shown above the note list. Tapping a crumb navigates up.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/folder_tree.dart';
import 'package:streakin/features/notes/application/note_providers.dart';

class FolderBreadcrumbs extends ConsumerWidget {
  const FolderBreadcrumbs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = ref.watch(activeFolderIdProvider);
    if (folderId == null) return const SizedBox.shrink();

    final foldersAsync = ref.watch(foldersProvider);
    return foldersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (folders) {
        final crumbs = buildBreadcrumbs(folders, folderId);
        if (crumbs.isEmpty) return const SizedBox.shrink();

        final colors = context.colors;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Root / Inbox
              _Crumb(
                label: 'Inbox',
                onTap: () =>
                    ref.read(activeFolderIdProvider.notifier).set(null),
              ),
              ...crumbs.map((c) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_right,
                          size: 16, color: colors.textMuted),
                      _Crumb(
                        label: c.name,
                        isLast: c.id == crumbs.last.id,
                        onTap: () => ref
                            .read(activeFolderIdProvider.notifier)
                            .set(c.id),
                      ),
                    ],
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, this.isLast = false, required this.onTap});
  final String label;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isLast ? colors.text : colors.brand,
          fontWeight: isLast ? FontWeight.w500 : FontWeight.normal,
          decoration: isLast ? null : TextDecoration.underline,
          decorationColor: colors.brand,
        ),
      ),
    );
  }
}
