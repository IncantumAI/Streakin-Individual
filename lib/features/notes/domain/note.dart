// lib/features/notes/domain/note.dart
// Note domain entity.

/// Supported note template kinds.
enum NoteTemplateKind {
  blank,
  whatHappenedToday,
  whatDidYouLearnToday,
  summaryOfTheDay,
  whereDidYouFallBack,
  brainstorm,
}

extension NoteTemplateKindExt on NoteTemplateKind {
  String get serialized => switch (this) {
    NoteTemplateKind.blank => 'blank',
    NoteTemplateKind.whatHappenedToday => 'what_happened_today',
    NoteTemplateKind.whatDidYouLearnToday => 'what_did_you_learn_today',
    NoteTemplateKind.summaryOfTheDay => 'summary_of_the_day',
    NoteTemplateKind.whereDidYouFallBack => 'where_did_you_fall_back',
    NoteTemplateKind.brainstorm => 'brainstorm',
  };

  static NoteTemplateKind fromString(String s) => switch (s) {
    'what_happened_today' => NoteTemplateKind.whatHappenedToday,
    'what_did_you_learn_today' => NoteTemplateKind.whatDidYouLearnToday,
    'summary_of_the_day' => NoteTemplateKind.summaryOfTheDay,
    'where_did_you_fall_back' => NoteTemplateKind.whereDidYouFallBack,
    'brainstorm' => NoteTemplateKind.brainstorm,
    _ => NoteTemplateKind.blank,
  };
}

class Note {
  const Note({
    required this.id,
    this.folderId,
    required this.title,
    this.templateKind = NoteTemplateKind.blank,
    required this.body,
    this.isPinned = false,
    this.vaultId,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String? folderId; // null = Root Inbox
  final String title;
  final NoteTemplateKind templateKind;

  /// Block-JSON string for unlocked notes. Encrypted base-64 for vault notes.
  final String body;
  final bool isPinned;
  final String? vaultId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String hlc;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Note copyWith({
    String? id,
    String? folderId,
    bool clearFolderId = false,
    String? title,
    NoteTemplateKind? templateKind,
    String? body,
    bool? isPinned,
    String? vaultId,
    bool clearVaultId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? hlc,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Note(
      id: id ?? this.id,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      templateKind: templateKind ?? this.templateKind,
      body: body ?? this.body,
      isPinned: isPinned ?? this.isPinned,
      vaultId: clearVaultId ? null : (vaultId ?? this.vaultId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: hlc ?? this.hlc,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Note && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
