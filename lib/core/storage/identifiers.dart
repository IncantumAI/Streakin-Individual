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

  /// Security settings (Phase 5).
  static const String prefWipeAfterFailures =
      'security.wipe_after_n'; // 0 = off
  static const String prefBlockScreenCapture = 'security.block_capture';
  static const String prefAutoLockSeconds = 'security.auto_lock_s';
  static const String prefIdleLockSeconds = 'security.idle_lock_s';
  static const String prefRecoveryVerifiedAt = 'security.recovery_verified_at';
  static const String prefVaultLockOnLeave = 'security.vault_lock_on_leave';

  /// Per-type notification toggles (default true).
  static const String prefNotifHabits = 'core.notif_habits';
  static const String prefNotifTodos = 'core.notif_todos';
  static const String prefNotifMentions = 'core.notif_mentions';
  static const String prefNotifLockInNudge = 'core.notif_lockin_nudge';

  /// 24-hour time format (default false → 12-hour).
  static const String prefTimeFormat24h = 'core.time_24h';

  /// Default reminder time offset in minutes from midnight.
  static const String prefDefaultReminderMinutes = 'core.default_reminder_min';

  // ── Notification channel IDs ──────────────────────────────────────────────
  /// Never rename channel IDs — Android uses these to persist user preferences.
  static const String channelHabitReminders = 'habit_reminders';
  static const String channelTodoReminders = 'todo_reminders';
  static const String channelNoteMentions = 'note_mention_reminders';
  static const String channelLockInNudge = 'lock_in_nudge';

  /// Goal reminder notification channel ID.
  static const String channelGoalCountdown = 'goal_countdown';

  // ── Profile keys ──────────────────────────────────────────────────────────
  static const String prefProfileName = 'core.profile_name';
  static const String prefProfileUsername = 'core.profile_username';
  static const String prefProfileBio = 'core.profile_bio';

  // ── Goal settings SharedPreferences keys ─────────────────────────────────
  static const String prefGoalReminderCadence = 'goals.reminder_cadence';
  static const String prefGoalReminderHour = 'goals.reminder_hour';
  static const String prefGoalReminderMinute = 'goals.reminder_minute';
  static const String prefGoalFinalStretch = 'goals.final_stretch';
  static const String prefGoalMilestoneAlerts = 'goals.milestone_alerts';
  static const String prefGoalCompletionAlert = 'goals.completion_alert';
  static const String prefGoalShowTitle = 'goals.show_title';
  static const String prefGoalShowAlignment = 'goals.show_alignment';
  static const String prefGoalSuppressIfDone = 'goals.suppress_if_done';
  static const String prefGoalCountFromStart = 'goals.count_from_start';

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
