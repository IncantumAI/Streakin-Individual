// lib/core/storage/session_database.dart
// The one open AppDatabase of the current session, published by SessionScope
// (never open a second handle — that was a past double-open bug).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:streakin/core/storage/app_database.dart';

class _SessionDbNotifier extends Notifier<AppDatabase?> {
  @override
  AppDatabase? build() => null;
  void set(AppDatabase db) => state = db;
  void clear() => state = null;
}

final sessionDatabaseProvider =
    NotifierProvider<_SessionDbNotifier, AppDatabase?>(_SessionDbNotifier.new);
