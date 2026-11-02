// lib/features/notes/presentation/notes_layout.dart
// Responsive notes layout:
//   < 1024px : mobile/tablet — folder sidebar in a Drawer
//   ≥ 1024px : desktop — 3-pane (folders | note list | editor)
//              Left pane width is resizable and persisted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/presentation/folder_sidebar.dart';

const String _kLeftPaneWidthKey = 'notes_left_pane_width';
const double _kMinPaneWidth = 160.0;
const double _kMaxPaneWidth = 320.0;
const double _kDefaultPaneWidth = 220.0;

// ── Left pane width provider (Riverpod 3 NotifierProvider) ────────────────────

class _LeftPaneWidthNotifier extends Notifier<double> {
  @override
  double build() {
    _load();
    return _kDefaultPaneWidth;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_kLeftPaneWidthKey) ?? _kDefaultPaneWidth;
    state = w.clamp(_kMinPaneWidth, _kMaxPaneWidth);
  }

  Future<void> set(double width) async {
    state = width.clamp(_kMinPaneWidth, _kMaxPaneWidth);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLeftPaneWidthKey, state);
  }
}

final leftPaneWidthProvider = NotifierProvider<_LeftPaneWidthNotifier, double>(
  _LeftPaneWidthNotifier.new,
);

// ── Notes layout widget ───────────────────────────────────────────────────────

class NotesLayout extends ConsumerWidget {
  const NotesLayout({required this.noteList, this.editor, super.key});

  final Widget noteList;
  final Widget? editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) {
      return _DesktopLayout(noteList: noteList, editor: editor);
    }
    return noteList;
  }
}

// ── Desktop 3-pane ────────────────────────────────────────────────────────────

class _DesktopLayout extends ConsumerStatefulWidget {
  const _DesktopLayout({required this.noteList, this.editor});
  final Widget noteList;
  final Widget? editor;

  @override
  ConsumerState<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<_DesktopLayout> {
  double _dragStartX = 0;
  double _dragStartWidth = 0;

  @override
  Widget build(BuildContext context) {
    final leftWidth = ref.watch(leftPaneWidthProvider);
    final colors = context.colors;

    return Row(
      children: [
        // Pane 1: Folder sidebar
        SizedBox(
          width: leftWidth,
          child: Container(
            color: colors.surfaceAlt,
            child: const FolderSidebar(),
          ),
        ),

        // Resize handle
        GestureDetector(
          onHorizontalDragStart: (d) {
            _dragStartX = d.globalPosition.dx;
            _dragStartWidth = leftWidth;
          },
          onHorizontalDragUpdate: (d) {
            final delta = d.globalPosition.dx - _dragStartX;
            ref
                .read(leftPaneWidthProvider.notifier)
                .set(_dragStartWidth + delta);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: Container(
              width: 5,
              color: AppColors.transparent,
              child: VerticalDivider(width: 1, color: colors.outline),
            ),
          ),
        ),

        // Pane 2: Note list
        Expanded(
          flex: widget.editor != null ? 1 : 2,
          child: Container(color: colors.surface, child: widget.noteList),
        ),

        // Pane 3: Editor (only when a note is open on desktop)
        if (widget.editor != null) ...[
          VerticalDivider(width: 1, color: colors.outline),
          Expanded(flex: 2, child: widget.editor!),
        ],
      ],
    );
  }
}
