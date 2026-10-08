// lib/features/notes/presentation/note_editor_screen.dart
// Full-screen note editor. Handles title editing, autosave lifecycle,
// and backlinks panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/features/notes/application/note_providers.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/editor/note_autosave_service.dart';
import 'package:streakin/features/notes/editor/note_editor_controller.dart';
import 'package:streakin/features/notes/editor/note_editor_widget.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({required this.noteId, super.key});
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  NoteEditorController? _editorController;
  NoteAutosaveService? _autosave;
  late TextEditingController _titleController;
  bool _initialised = false;
  bool _backlinksExpanded = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save immediately when the app goes to background.
    if (state == AppLifecycleState.paused) {
      _autosave?.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dismiss keyboard before tearing down the editor to avoid
    // super_editor's SoftwareKeyboardController trying to detach from a
    // defunct widget (FlutterError on back navigation).
    FocusManager.instance.primaryFocus?.unfocus();
    _autosave?.saveNow(); // Save on navigate away.
    _titleController.dispose();
    _editorController?.dispose();
    _autosave?.dispose();
    super.dispose();
  }

  void _init(Note note) {
    if (_initialised) return;
    _initialised = true;

    final doc = NoteDocument.fromJson(note.body);
    _titleController.text = note.title;

    _editorController = NoteEditorController(initialDocument: doc);
    _autosave = NoteAutosaveService(
      repository: ref.read(noteRepositoryProvider),
      noteId: note.id,
    );

    _editorController!.addChangeListener(() {
      _autosave!.onContentChanged(
        _editorController!.toDomain(),
        _titleController.text,
      );
    });

    _titleController.addListener(() {
      if (_editorController != null) {
        _autosave!.onContentChanged(
          _editorController!.toDomain(),
          _titleController.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteProvider(widget.noteId));
    final colors = context.colors;

    return noteAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator.adaptive())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (note) {
        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text('Note not found.',
                  style: TextStyle(color: colors.textMuted)),
            ),
          );
        }

        // Initialise editor on first data.
        _init(note);

        final ctrl = _editorController!;
        final autosave = _autosave!;

        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: BackButton(color: colors.text),
            titleSpacing: 0,
            title: TextField(
              controller: _titleController,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.text),
              decoration: InputDecoration(
                hintText: 'Untitled',
                hintStyle: TextStyle(color: colors.textMuted),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.next,
            ),
            actions: [
              // Toggle backlinks panel
              IconButton(
                icon: Icon(
                  Icons.link,
                  color: _backlinksExpanded ? colors.brand : colors.textMuted,
                ),
                tooltip: 'Backlinks',
                onPressed: () =>
                    setState(() => _backlinksExpanded = !_backlinksExpanded),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: NoteEditorWidget(
                  controller: ctrl,
                  autosave: autosave,
                  noteId: widget.noteId,
                ),
              ),
              if (_backlinksExpanded)
                _BacklinksPanel(noteId: widget.noteId),
            ],
          ),
        );
      },
    );
  }
}

// ── Backlinks panel ───────────────────────────────────────────────────────────

class _BacklinksPanel extends ConsumerWidget {
  const _BacklinksPanel({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final backlinksAsync = ref.watch(backlinksProvider(noteId));

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Backlinks',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted),
            ),
          ),
          Expanded(
            child: backlinksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) =>
                  Center(child: Text('Error', style: TextStyle(color: colors.danger))),
              data: (links) {
                if (links.isEmpty) {
                  return Center(
                    child: Text(
                      'No notes link to this yet.',
                      style: TextStyle(fontSize: 13, color: colors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: links.length,
                  itemBuilder: (context, i) {
                    final note = links[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.article_outlined,
                          size: 18, color: colors.brand),
                      title: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: TextStyle(fontSize: 14, color: colors.text),
                      ),
                      onTap: () {
                        // Navigate to backlink source note.
                        // Use push so user can go back.
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              NoteEditorScreen(noteId: note.id),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
