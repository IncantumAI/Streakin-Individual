// lib/features/notes/editor/note_templates.dart
// Built-in note templates. Spec §4.4.2.
// Templates are pre-filled NoteDocuments — fully editable after creation.

import 'package:uuid/uuid.dart';
import 'package:streakin/features/notes/domain/note.dart';
import 'package:streakin/features/notes/domain/note_document.dart';

const _uuid = Uuid();
String _id() => _uuid.v4();

/// Metadata shown in the template picker sheet.
class NoteTemplateInfo {
  const NoteTemplateInfo({
    required this.kind,
    required this.label,
    required this.description,
  });
  final NoteTemplateKind kind;
  final String label;
  final String description;
}

const List<NoteTemplateInfo> kAllTemplates = [
  NoteTemplateInfo(
    kind: NoteTemplateKind.blank,
    label: 'Blank',
    description: 'Start with an empty note.',
  ),
  NoteTemplateInfo(
    kind: NoteTemplateKind.whatHappenedToday,
    label: 'What happened today?',
    description: 'A free-form daily journal entry.',
  ),
  NoteTemplateInfo(
    kind: NoteTemplateKind.whatDidYouLearnToday,
    label: 'What did you learn today?',
    description: 'Capture your learnings as bullet points.',
  ),
  NoteTemplateInfo(
    kind: NoteTemplateKind.summaryOfTheDay,
    label: 'Summary of the day',
    description: 'Wins, misses, and tomorrow\'s priorities.',
  ),
  NoteTemplateInfo(
    kind: NoteTemplateKind.whereDidYouFallBack,
    label: 'Where did you fall back?',
    description: 'Reflect on what slipped and why.',
  ),
  NoteTemplateInfo(
    kind: NoteTemplateKind.brainstorm,
    label: 'Brainstorm',
    description: 'Central question + free bullet ideas.',
  ),
];

/// Build the initial [NoteDocument] for a given template kind.
NoteDocument buildTemplate(NoteTemplateKind kind) {
  switch (kind) {
    case NoteTemplateKind.blank:
      return NoteDocument([
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
      ]);

    case NoteTemplateKind.whatHappenedToday:
      return NoteDocument([
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading2,
          text: 'What happened today?',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
      ]);

    case NoteTemplateKind.whatDidYouLearnToday:
      return NoteDocument([
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading2,
          text: 'What did you learn today?',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
      ]);

    case NoteTemplateKind.summaryOfTheDay:
      return NoteDocument([
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading2,
          text: 'Summary of the day',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.heading3, text: 'Wins'),
        NoteBlock(id: _id(), kind: NoteBlockKind.task),
        NoteBlock(id: _id(), kind: NoteBlockKind.heading3, text: 'Misses'),
        NoteBlock(id: _id(), kind: NoteBlockKind.task),
        NoteBlock(id: _id(), kind: NoteBlockKind.heading3, text: 'Tomorrow'),
        NoteBlock(id: _id(), kind: NoteBlockKind.task),
      ]);

    case NoteTemplateKind.whereDidYouFallBack:
      return NoteDocument([
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading2,
          text: 'Where did you fall back?',
        ),
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading3,
          text: 'What slipped?',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
        NoteBlock(id: _id(), kind: NoteBlockKind.heading3, text: 'Why?'),
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading3,
          text: 'One small fix',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.task),
      ]);

    case NoteTemplateKind.brainstorm:
      return NoteDocument([
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading2,
          text: 'Central question',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
        NoteBlock(id: _id(), kind: NoteBlockKind.heading3, text: 'Ideas'),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
        NoteBlock(id: _id(), kind: NoteBlockKind.bulletItem),
        NoteBlock(
          id: _id(),
          kind: NoteBlockKind.heading3,
          text: 'Related notes',
        ),
        NoteBlock(id: _id(), kind: NoteBlockKind.paragraph),
      ]);
  }
}

/// Returns the suggested title for a template.
String templateTitle(NoteTemplateKind kind) => switch (kind) {
  NoteTemplateKind.blank => '',
  NoteTemplateKind.whatHappenedToday => 'What happened today?',
  NoteTemplateKind.whatDidYouLearnToday => 'What did I learn today?',
  NoteTemplateKind.summaryOfTheDay => 'Summary of the day',
  NoteTemplateKind.whereDidYouFallBack => 'Where did I fall back?',
  NoteTemplateKind.brainstorm => 'Brainstorm',
};
