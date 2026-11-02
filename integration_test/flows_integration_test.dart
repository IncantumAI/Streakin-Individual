// integration_test/flows_integration_test.dart
// Spec §15.3 flows #1–#4, exercised through the real Drift repositories,
// use-cases and the notification reconciler (fake scheduler) on an in-memory
// database. UI-level onboarding is covered manually per phase_1 checklist.
//
// Run: flutter test integration_test/flows_integration_test.dart

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

import 'package:streakin/core/notifications/notification_reconciler.dart';
import 'package:streakin/core/storage/app_database.dart' show AppDatabase;
import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/habits/application/habit_providers.dart';
import 'package:streakin/features/habits/data/drift_habit_repository.dart';
import 'package:streakin/features/habits/data/habit_dao.dart';
import 'package:streakin/features/habits/domain/habit.dart';
import 'package:streakin/features/habits/domain/streak_engine.dart';
import 'package:streakin/features/notes/application/todo_bridge_impl.dart';
import 'package:streakin/features/notes/data/drift_date_mention_source.dart';
import 'package:streakin/features/notes/data/drift_note_repository.dart';
import 'package:streakin/features/notes/data/note_dao.dart';
import 'package:streakin/features/notes/domain/date_mention_parser.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';
import 'package:streakin/features/notes/editor/date_mention_picker.dart';
import 'package:streakin/features/notes/graph/graph_model.dart';
import 'package:streakin/features/todos/data/drift_todo_repository.dart';
import 'package:streakin/features/todos/data/todo_dao.dart';

const _uuid = Uuid();

class _NoOpFts extends NoteFtsDao {
  _NoOpFts(super.db);
  @override
  Future<void> index(String noteId, String title, String plainText) async {}
  @override
  Future<void> remove(String noteId) async {}
}

class _FakeScheduler implements NotificationScheduler {
  final Map<int, PlannedNotification> scheduled = {};
  @override
  Future<void> init() async {}
  @override
  Future<List<({int id, String? payload})>> pending() async => [
    for (final n in scheduled.values) (id: n.id, payload: n.payload),
  ];
  @override
  Future<void> schedule(PlannedNotification n) async => scheduled[n.id] = n;
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

Note _note(String title, String body) => Note(
  id: _uuid.v4(),
  title: title,
  body: body,
  createdAt: DateTime(2026, 10, 7),
  updatedAt: DateTime(2026, 10, 7),
  hlc: '2026-10-07T00:00:00.000Z-0000-test',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftNoteRepository noteRepo;
  late DriftTodoRepository todoRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = DriftNoteRepository(NoteDao(db), _NoOpFts(db));
    todoRepo = DriftTodoRepository(TodoDao(db));
  });

  tearDown(() => db.close());

  test('#1 create habit → check → lock-in → streak = 1', () async {
    final habitRepo = DriftHabitRepository(HabitDao(db));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(habitRepositoryStateProvider.notifier).set(habitRepo);

    final today = LocalDate.today();
    final habit = Habit(
      id: _uuid.v4(),
      name: 'Read',
      iconIndex: 0,
      accentIndex: 0,
      scheduleMask: ScheduleMask.every,
      startDate: today,
      sortOrder: 0,
      restTokensPerWeek: 1,
      hlc: '2026-10-07T00:00:00.000Z-0000-test',
    );
    await habitRepo.save(habit);
    await container.read(habitUseCasesProvider).checkHabit(habit.id);

    expect(await habitRepo.watchDayLock(today).first, isNotNull);
    final logs = await habitRepo.fetchLogsForHabits([
      habit.id,
    ], DateRange(start: today, end: today));
    expect(
      const StreakEngine().currentStreak(habit, logs[habit.id] ?? [], today),
      1,
    );
  });

  test('#2 note → [[link]] → backlink → graph edge', () async {
    final target = _note('Target', '[]');
    await noteRepo.saveNote(target);
    final source = _note(
      'Source',
      NoteDocument([
        const NoteBlock(
          id: 'b1',
          kind: NoteBlockKind.paragraph,
          text: 'see [[Target]]',
        ),
      ]).toJson(),
    );
    await noteRepo.saveNote(source);

    final backlinks = await noteRepo.watchBacklinks(target.id).first;
    expect(backlinks.map((n) => n.id), [source.id]);

    final out = await noteRepo.watchOutgoingLinks(source.id).first;
    final graph = buildGraph(
      notes: [
        GraphNoteRef(id: source.id, title: 'Source'),
        GraphNoteRef(id: target.id, title: 'Target'),
      ],
      links: {source.id: out.map((n) => n.id).toSet()},
      isVaultLocked: (_) => true,
    );
    expect(graph.edges.single.from, source.id);
    expect(graph.edges.single.to, target.id);
  });

  test(
    '#3 checkbox → promote → complete from to-do → checkbox updates',
    () async {
      final bridge = TodoBridgeImpl(noteRepo: noteRepo, todoRepo: todoRepo);
      const blockId = 'task1';
      final note = _note(
        'Tasks',
        NoteDocument([
          const NoteBlock(
            id: blockId,
            kind: NoteBlockKind.task,
            text: 'Buy milk',
          ),
        ]).toJson(),
      );
      await noteRepo.saveNote(note);

      await bridge.promoteCheckbox(note.id, blockId, 'Buy milk');
      final todo = (await todoRepo.watchBySourceBlock(note.id, blockId).first)!;
      expect(await bridge.watchCheckboxState(note.id, blockId).first, isFalse);

      await todoRepo.complete(todo.id); // completed from the to-do list
      expect(await bridge.watchCheckboxState(note.id, blockId).first, isTrue);

      await bridge.setCheckboxDone(note.id, blockId, false); // ticked in note
      expect((await todoRepo.getById(todo.id))!.isDone, isFalse);
    },
  );

  test(
    '#4 @tomorrow 5pm → mention row → notification → delete chip → removed',
    () async {
      final now = DateTime(2026, 10, 7, 12);
      final m = const DateMentionParser().parse('tomorrow 5pm', now: now);
      final chip = dateChipText(m);

      final habitRepo = DriftHabitRepository(HabitDao(db));
      final scheduler = _FakeScheduler();
      final reconciler = NotificationReconciler(
        habitRepo: habitRepo,
        todoRepo: todoRepo,
        mentionSource: DriftDateMentionSource(NoteDao(db)),
        scheduler: scheduler,
        settings: () async => const ReconcilerSettings(),
        clock: () => now,
      );

      final note = _note(
        'Plan',
        NoteDocument([
          NoteBlock(
            id: 'b1',
            kind: NoteBlockKind.paragraph,
            text: 'Call $chip',
          ),
        ]).toJson(),
      );
      await noteRepo.saveNote(note);
      await reconciler.reconcile();
      expect(
        scheduler.scheduled.values.map((n) => n.payload),
        contains('date_mention:${note.id}'),
      );

      // Delete the chip → mention row gone → notification cancelled.
      await noteRepo.saveNote(
        note.copyWith(
          body: NoteDocument([
            const NoteBlock(
              id: 'b1',
              kind: NoteBlockKind.paragraph,
              text: 'Call',
            ),
          ]).toJson(),
        ),
      );
      await reconciler.reconcile();
      expect(
        scheduler.scheduled.values.map((n) => n.payload),
        isNot(contains('date_mention:${note.id}')),
      );
    },
  );
}
