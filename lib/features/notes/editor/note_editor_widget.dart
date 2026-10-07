// lib/features/notes/editor/note_editor_widget.dart
// SuperEditor wrapper for Streakin notes.
// Handles: rendering, mobile toolbar, slash-command menu, autosave indicator,
// and tag '#' autocomplete.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/todo_bridge_impl.dart';
import 'package:streakin/features/notes/editor/note_autosave_service.dart';
import 'package:streakin/features/notes/editor/note_editor_controller.dart';
import 'package:streakin/features/notes/editor/tag_autocomplete.dart';

class NoteEditorWidget extends ConsumerStatefulWidget {
  const NoteEditorWidget({
    required this.controller,
    required this.autosave,
    required this.noteId,
    this.readOnly = false,
    super.key,
  });

  final NoteEditorController controller;
  final NoteAutosaveService autosave;
  /// The note's stable ID — needed for checkbox bridge operations.
  final String noteId;
  final bool readOnly;

  @override
  ConsumerState<NoteEditorWidget> createState() => _NoteEditorWidgetState();
}

class _NoteEditorWidgetState extends ConsumerState<NoteEditorWidget> {
  OverlayEntry? _slashOverlay;
  late TagAutocompleteController _tagAutocomplete;

  @override
  void initState() {
    super.initState();
    _tagAutocomplete = TagAutocompleteController(
      editor: widget.controller.editor,
      composer: widget.controller.composer,
      document: widget.controller.document,
      overlayKey: GlobalKey(),
    );
    widget.controller.addChangeListener(_onDocumentChanged);
    widget.autosave.addListener(_onAutosaveChanged);
  }

  @override
  void dispose() {
    _slashOverlay?.remove();
    _tagAutocomplete.dispose();
    widget.controller.removeChangeListener(_onDocumentChanged);
    widget.autosave.removeListener(_onAutosaveChanged);
    super.dispose();
  }

  void _onDocumentChanged() {
    _checkSlashTrigger();
    _tagAutocomplete.onDocumentChanged(context, ref);
  }

  void _onAutosaveChanged() {
    if (mounted) setState(() {});
  }

  void _checkSlashTrigger() {
    final selection = widget.controller.composer.selection;
    if (selection == null) return;
    final nodeId = selection.extent.nodeId;
    final node = widget.controller.document.getNodeById(nodeId);
    if (node is! TextNode) return;
    final offset = (selection.extent.nodePosition as TextNodePosition).offset;
    final text = node.text.text;
    if (offset > 0 && text.isNotEmpty && text[offset - 1] == '/') {
      _showSlashMenu(nodeId);
    } else {
      _hideSlashMenu();
    }
  }

  void _showSlashMenu(String nodeId) {
    if (_slashOverlay != null) return;
    _slashOverlay = OverlayEntry(
      builder: (_) => _SlashCommandMenu(
        onSelect: (blockType) => _insertBlock(nodeId, blockType),
        onDismiss: _hideSlashMenu,
      ),
    );
    Overlay.of(context).insert(_slashOverlay!);
  }

  void _hideSlashMenu() {
    _slashOverlay?.remove();
    _slashOverlay = null;
  }

  void _insertBlock(String nodeId, _SlashBlockType type) {
    _hideSlashMenu();
    final editor = widget.controller.editor;
    final node = widget.controller.document.getNodeById(nodeId);
    if (node is! TextNode) return;

    final selection = widget.controller.composer.selection;
    if (selection != null) {
      final offset = (selection.extent.nodePosition as TextNodePosition).offset;
      if (offset > 0) {
        editor.execute([
          DeleteContentRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(
                nodeId: nodeId,
                nodePosition: TextNodePosition(offset: offset - 1),
              ),
              end: DocumentPosition(
                nodeId: nodeId,
                nodePosition: TextNodePosition(offset: offset),
              ),
            ),
          ),
        ]);
      }
    }

    switch (type) {
      case _SlashBlockType.h1:
        editor.execute([ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: header1Attribution)]);
      case _SlashBlockType.h2:
        editor.execute([ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: header2Attribution)]);
      case _SlashBlockType.h3:
        editor.execute([ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: header3Attribution)]);
      case _SlashBlockType.bullet:
        editor.execute([ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.unordered)]);
      case _SlashBlockType.numbered:
        editor.execute([ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.ordered)]);
      case _SlashBlockType.task:
        editor.execute([ConvertParagraphToTaskRequest(nodeId: nodeId)]);
      case _SlashBlockType.divider:
        editor.execute([InsertNodeAfterNodeRequest(existingNodeId: nodeId, newNode: HorizontalRuleNode(id: _newId()))]);
      case _SlashBlockType.blockquote:
        editor.execute([ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: blockquoteAttribution)]);
    }
  }

  String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

  // ── Checkbox bridge ───────────────────────────────────────────────────────

  /// Called on long-press anywhere in the editor. Detects if the pressed
  /// position corresponds to a TaskNode and shows promote/demote menu.
  void _onLongPress(BuildContext context) {
    final selection = widget.controller.composer.selection;
    if (selection == null) return;
    final nodeId = selection.extent.nodeId;
    final node = widget.controller.document.getNodeById(nodeId);
    if (node is! TaskNode) return;

    final linkedTodoId = _linkedTodoId(nodeId);
    final isLinked = linkedTodoId != null;

    showModalBottomSheet(
      context: context,
      builder: (_) => _CheckboxBridgeSheet(
        isLinked: isLinked,
        taskText: node.text.text,
        onPromote: () => _promote(context, nodeId, node.text.text),
        onDemote: () => _demote(context, nodeId),
      ),
    );
  }

  /// Extract linkedTodoId from the domain block's attrs for a given nodeId.
  String? _linkedTodoId(String nodeId) {
    // We look up the block in the current domain document.
    final domain = widget.controller.toDomain();
    try {
      final block = domain.blocks.firstWhere((b) => b.id == nodeId);
      return block.attrs['linkedTodoId'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _promote(
      BuildContext context, String nodeId, String title) async {
    final bridge = ref.read(todoBridgeStateProvider);
    if (bridge == null) return;
    await bridge.promoteCheckbox(widget.noteId, nodeId, title);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added to To-do list')),
      );
    }
  }

  Future<void> _demote(BuildContext context, String nodeId) async {
    final bridge = ref.read(todoBridgeStateProvider);
    if (bridge == null) return;
    await bridge.demoteCheckbox(widget.noteId, nodeId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task unlinked from To-do list')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isIos = !kIsWeb && Platform.isIOS;

    return Column(
      children: [
        _AutosaveBar(state: widget.autosave.state),
        Expanded(
          child: GestureDetector(
            onLongPress: () => _onLongPress(context),
            child: SuperEditor(
              editor: widget.controller.editor,
              document: widget.controller.document,
              composer: widget.controller.composer,
              stylesheet: _buildStylesheet(colors),
              androidToolbarBuilder: isAndroid
                  ? (_) => _MobileToolbar(
                        editor: widget.controller.editor,
                        document: widget.controller.document,
                        composer: widget.controller.composer,
                      )
                  : null,
              iOSToolbarBuilder: isIos
                  ? (_) => _MobileToolbar(
                        editor: widget.controller.editor,
                        document: widget.controller.document,
                        composer: widget.controller.composer,
                      )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Stylesheet _buildStylesheet(AppColorTokens colors) {
    return defaultStylesheet.copyWith(
      documentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      addRulesAfter: [
        StyleRule(BlockSelector.all, (doc, node) => {
          Styles.textStyle: TextStyle(color: colors.text, fontSize: 16, height: 1.6),
        }),
        StyleRule(const BlockSelector('header1'), (doc, node) => {
          Styles.textStyle: TextStyle(color: colors.text, fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
        }),
        StyleRule(const BlockSelector('header2'), (doc, node) => {
          Styles.textStyle: TextStyle(color: colors.text, fontSize: 22, fontWeight: FontWeight.w600, height: 1.35),
        }),
        StyleRule(const BlockSelector('header3'), (doc, node) => {
          Styles.textStyle: TextStyle(color: colors.text, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
        }),
        StyleRule(const BlockSelector('blockquote'), (doc, node) => {
          Styles.textStyle: TextStyle(color: colors.textMuted, fontSize: 16, fontStyle: FontStyle.italic, height: 1.6),
        }),
      ],
    );
  }
}

// ── Autosave indicator ────────────────────────────────────────────────────────

class _AutosaveBar extends StatelessWidget {
  const _AutosaveBar({required this.state});
  final AutosaveState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, label, color) = switch (state) {
      AutosaveState.idle => (null, '', colors.textMuted),
      AutosaveState.pending => (Icons.edit_outlined, 'Unsaved changes', colors.textMuted),
      AutosaveState.saving => (Icons.sync, 'Saving…', colors.textMuted),
      AutosaveState.saved => (Icons.check_circle_outline, 'Saved', colors.success),
      AutosaveState.error => (Icons.error_outline, 'Save failed', colors.danger),
    };

    if (state == AutosaveState.idle) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == AutosaveState.saving)
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.textMuted))
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ── Mobile formatting toolbar ─────────────────────────────────────────────────

class _MobileToolbar extends StatelessWidget {
  const _MobileToolbar({required this.editor, required this.document, required this.composer});
  final Editor editor;
  final MutableDocument document;
  final MutableDocumentComposer composer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 44,
      color: colors.surfaceAlt,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _ToolbarButton(icon: Icons.format_bold, tooltip: 'Bold', onTap: _toggleBold),
            _ToolbarButton(icon: Icons.format_italic, tooltip: 'Italic', onTap: _toggleItalic),
            _ToolbarButton(icon: Icons.format_underline, tooltip: 'Underline', onTap: _toggleUnderline),
            _ToolbarButton(icon: Icons.format_strikethrough, tooltip: 'Strikethrough', onTap: _toggleStrikethrough),
            const _ToolbarDivider(),
            _ToolbarButton(icon: Icons.title, tooltip: 'Heading 1', onTap: () => _setBlockType(header1Attribution)),
            _ToolbarButton(icon: Icons.format_list_bulleted, tooltip: 'Bullet list', onTap: () => _convertToList(ListItemType.unordered)),
            _ToolbarButton(icon: Icons.format_list_numbered, tooltip: 'Numbered list', onTap: () => _convertToList(ListItemType.ordered)),
            _ToolbarButton(icon: Icons.check_box_outlined, tooltip: 'Task', onTap: _convertToTask),
            _ToolbarButton(icon: Icons.format_quote, tooltip: 'Blockquote', onTap: () => _setBlockType(blockquoteAttribution)),
          ],
        ),
      ),
    );
  }

  String? get _selectedNodeId => composer.selection?.extent.nodeId;

  void _toggleBold() {
    final sel = composer.selection;
    if (sel == null) return;
    editor.execute([ToggleTextAttributionsRequest(documentRange: sel, attributions: {boldAttribution})]);
  }

  void _toggleItalic() {
    final sel = composer.selection;
    if (sel == null) return;
    editor.execute([ToggleTextAttributionsRequest(documentRange: sel, attributions: {italicsAttribution})]);
  }

  void _toggleUnderline() {
    final sel = composer.selection;
    if (sel == null) return;
    editor.execute([ToggleTextAttributionsRequest(documentRange: sel, attributions: {underlineAttribution})]);
  }

  void _toggleStrikethrough() {
    final sel = composer.selection;
    if (sel == null) return;
    editor.execute([ToggleTextAttributionsRequest(documentRange: sel, attributions: {strikethroughAttribution})]);
  }

  void _setBlockType(Attribution type) {
    final id = _selectedNodeId;
    if (id == null) return;
    editor.execute([ChangeParagraphBlockTypeRequest(nodeId: id, blockType: type)]);
  }

  void _convertToList(ListItemType type) {
    final id = _selectedNodeId;
    if (id == null) return;
    editor.execute([ConvertParagraphToListItemRequest(nodeId: id, type: type)]);
  }

  void _convertToTask() {
    final id = _selectedNodeId;
    if (id == null) return;
    editor.execute([ConvertParagraphToTaskRequest(nodeId: id)]);
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Icon(icon, size: 20, color: colors.text),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: context.colors.outline);
  }
}

// ── Slash command menu ────────────────────────────────────────────────────────

enum _SlashBlockType { h1, h2, h3, bullet, numbered, task, divider, blockquote }

class _SlashCommandMenu extends StatelessWidget {
  const _SlashCommandMenu({required this.onSelect, required this.onDismiss});
  final void Function(_SlashBlockType) onSelect;
  final VoidCallback onDismiss;

  static const _items = [
    (type: _SlashBlockType.h1,         icon: Icons.title,                  label: 'Heading 1'),
    (type: _SlashBlockType.h2,         icon: Icons.title,                  label: 'Heading 2'),
    (type: _SlashBlockType.h3,         icon: Icons.title,                  label: 'Heading 3'),
    (type: _SlashBlockType.bullet,     icon: Icons.format_list_bulleted,   label: 'Bullet list'),
    (type: _SlashBlockType.numbered,   icon: Icons.format_list_numbered,   label: 'Numbered list'),
    (type: _SlashBlockType.task,       icon: Icons.check_box_outlined,     label: 'Task'),
    (type: _SlashBlockType.blockquote, icon: Icons.format_quote,           label: 'Blockquote'),
    (type: _SlashBlockType.divider,    icon: Icons.horizontal_rule,        label: 'Divider'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        GestureDetector(onTap: onDismiss, child: const SizedBox.expand()),
        Positioned(
          bottom: 100,
          left: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: colors.surface,
            child: Container(
              width: 220,
              decoration: BoxDecoration(border: Border.all(color: colors.outline), borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Text('Insert block', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted)),
                  ),
                  ..._items.map((item) => InkWell(
                        onTap: () => onSelect(item.type),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(item.icon, size: 18, color: colors.brand),
                              const SizedBox(width: 10),
                              Text(item.label, style: TextStyle(fontSize: 14, color: colors.text)),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Checkbox bridge action sheet ──────────────────────────────────────────────

class _CheckboxBridgeSheet extends StatelessWidget {
  const _CheckboxBridgeSheet({
    required this.isLinked,
    required this.taskText,
    required this.onPromote,
    required this.onDemote,
  });

  final bool isLinked;
  final String taskText;
  final VoidCallback onPromote;
  final VoidCallback onDemote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = taskText.isEmpty ? 'Task' : taskText;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              isLinked ? 'Linked to To-do list' : 'Plain checkbox',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (!isLinked)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.add_task, color: colors.brand),
                title: Text('Promote to task',
                    style: TextStyle(color: colors.text)),
                subtitle: Text('Add to To-do list and keep in sync',
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  onPromote();
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.link_off, color: colors.danger),
                title: Text('Demote to plain checkbox',
                    style: TextStyle(color: colors.text)),
                subtitle: Text('Unlink from To-do list (task will be deleted)',
                    style: TextStyle(color: colors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  onDemote();
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.close, color: colors.textMuted),
              title:
                  Text('Cancel', style: TextStyle(color: colors.textMuted)),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
