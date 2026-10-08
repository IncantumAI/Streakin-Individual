// lib/core/storage/identifiers.dart
//
// !! DO NOT RENAME THESE CONSTANTS !!
//
// These identifiers are permanently baked into encrypted data structures,
// secure storage keys, and cross-device share files. Changing them after
// first release would orphan existing encrypted data, invalidate stored
// quick-unlock secrets, or break import compatibility with earlier versions.
//
// A brand rename (app name change) must NEVER touch this file.
// See streakin_app_spec.md §19 for the full reasoning.

/// Stable internal identifiers — brand-neutral and version-locked.
class AppIdentifiers {
  AppIdentifiers._();

  // ── Database ──────────────────────────────────────────────────────────────
  /// SQLCipher database filename. Never rename.
  static const String dbFileName = 'core.db';

  // ── Keyring ───────────────────────────────────────────────────────────────
  /// Keyring file that stores DEK wrapped under KEK_pw and KEK_rk.
  static const String keyringFileName = 'keyring.bin';

  /// Magic header written into keyring.bin to detect file format.
  static const String keyringMagic = 'STRKRING1';

  // ── Secure storage keys ───────────────────────────────────────────────────
  /// Key under which device-bound DEK wrapping is stored.
  static const String ssKeyQuickUnlock = 'core.v1.qu';

  /// Failed-attempt counter for brute-force defence.
  static const String ssKeyFailedAttempts = 'core.v1.fa';

  /// Lockout-until timestamp (epoch ms as string).
  static const String ssKeyLockoutUntil = 'core.v1.lu';

  /// Device X25519 private key for pairing (sharing).
  static const String ssKeyDevicePrivateKey = 'core.v1.dpk';

  // ── SharedPreferences keys ────────────────────────────────────────────────
  /// Non-sensitive only. True once onboarding Step 3 is complete.
  static const String prefOnboardingDone = 'core.onboarding_done';

  /// Theme mode string: 'light' | 'dark' | 'system'.
  static const String prefThemeMode = 'core.theme_mode';

  /// Week start: 1=Mon, 7=Sun (ISO weekday).
  static const String prefWeekStart = 'core.week_start';

  /// Day boundary offset in minutes from midnight (default 0 = 00:00).
  static const String prefDayBoundaryMinutes = 'core.day_boundary_min';

  /// Motion setting: 'full' | 'reduced'.
  static const String prefMotionMode = 'core.motion_mode';

  /// Haptics enabled: bool as string 'true'/'false'.
  static const String prefHapticsEnabled = 'core.haptics';

  /// Whether biometric unlock is enabled (default false).
  static const String prefBiometricEnabled = 'core.biometric_enabled';

  /// Whether to count to-dos toward daily lock-in (default false).
  static const String prefCountTodosForLockIn = 'core.todos_lockin';

  /// Default reminder time offset in minutes from midnight.
  static const String prefDefaultReminderMinutes = 'core.default_reminder_min';

  // ── Notification channel IDs ──────────────────────────────────────────────
  /// Never rename channel IDs — Android uses these to persist user preferences.
  static const String channelHabitReminders = 'habit_reminders';
  static const String channelTodoReminders = 'todo_reminders';
  static const String channelNoteMentions = 'note_mention_reminders';
  static const String channelLockInNudge = 'lock_in_nudge';

  // ── Share container ───────────────────────────────────────────────────────
  /// Magic bytes written at offset 0 of every .ncx export file.
  /// MUST remain 'NCX1' regardless of any brand rename. See spec §10.1.
  static const String ncxMagic = 'NCX1';

  /// Current format version for .ncx containers.
  static const int ncxFormatVersion = 1;

  // ── HKDF domain labels ────────────────────────────────────────────────────
  /// Keep these stable — changing them would invalidate all existing encrypted data.
  static const String hkdfLabelDb = 'db';
  static const String hkdfLabelAttach = 'attach';
  static const String hkdfLabelVault = 'vault';
  static const String hkdfLabelShare = 'share';
}
