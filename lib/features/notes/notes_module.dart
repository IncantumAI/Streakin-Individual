// lib/features/notes/notes_module.dart
// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC BOUNDARY for the Notes feature module.
//
// RULE: Code outside lib/features/notes/ MAY ONLY import this file.
//       It must NEVER import any file under:
//         lib/features/notes/domain/
//         lib/features/notes/data/
//         lib/features/notes/application/
//       (except the interfaces exported here)
//
// This boundary is enforced by the CI lint rule added in Track 3A.
// ═══════════════════════════════════════════════════════════════════════════

// ── Routing ───────────────────────────────────────────────────────────────────
export 'presentation/notes_routes.dart' show notesRoutes;

// ── Calendar integration ──────────────────────────────────────────────────────
export 'application/notes_calendar_source.dart'
    show NotesCalendarSource, notesCalendarEntriesProvider, notesDateMentionsByDateProvider;

// ── Dashboard integration ─────────────────────────────────────────────────────
export 'domain/dashboard_section_provider.dart'
    show DashboardSectionProvider, RecentNoteItem, PinnedNoteItem;
export 'application/notes_dashboard_provider.dart'
    show NotesDashboardProvider, recentNotesProvider, pinnedNotesProvider;

// ── Phase 4 bridge interface (stub — implemented in Phase 4 todo module) ──────
export 'domain/todo_bridge.dart' show TodoBridge;
export 'application/todo_bridge_impl.dart'
    show TodoBridgeImpl, todoBridgeStateProvider, todoBridgeProvider;

// ── Riverpod providers (needed by SessionScope and AppShell) ──────────────────
export 'application/note_providers.dart'
    show
        noteRepositoryStateProvider,
        attachmentRepositoryStateProvider,
        ftsRepositoryStateProvider;
