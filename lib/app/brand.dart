// lib/app/brand.dart
// TODO(rename): Update all values when rebranding.
// Run: grep -r "TODO(rename)" lib/ android/ windows/ linux/ to find all markers.

/// Single source of truth for brand-visible strings.
///
/// Do NOT put stable internal identifiers here (DB filename, keyring strings,
/// SharedPreferences keys, notification channel IDs). Those live in
/// core/storage/identifiers.dart and must never follow a brand rename.
class Brand {
  Brand._();

  // TODO(rename): App display name shown in UI, splash, about screen.
  static const String appName = 'Streakin';

  // TODO(rename): Short tagline shown on onboarding.
  static const String tagline = 'Build habits. Think in notes.';

  // TODO(rename): Support / contact string.
  static const String supportEmail = 'support@incantum.in';

  // TODO(rename): About screen — company name.
  static const String companyName = 'Incantum';

  // TODO(rename): Window / tray title on desktop.
  static const String windowTitle = 'Streakin';

  // TODO(rename): Share sheet text prefix for exports.
  static const String exportSheetText = 'Share Streakin backup';
}
