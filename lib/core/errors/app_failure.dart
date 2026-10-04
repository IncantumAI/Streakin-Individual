// lib/core/errors/app_failure.dart
//
// Typed failure hierarchy. No raw exceptions cross layer boundaries.
// Spec §14: "Typed failures (sealed class AppFailure) at layer boundaries."

/// Base sealed class for all application failures.
/// Widgets receive these — never raw Dart exceptions or stack traces.
sealed class AppFailure {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Cryptographic operation failed — wrong key, tampered data, bad params.
final class CryptoFailure extends AppFailure {
  const CryptoFailure(super.message);
}

/// Database operation failed — open error, query error, migration error.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message);
}

/// File validation failed — bad type, magic mismatch, structure invalid.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// Authentication / lock failure — wrong password, biometric rejected.
final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// Network-related failure (should never occur in release — no INTERNET permission).
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

/// Notification scheduling / permission failure.
final class NotificationFailure extends AppFailure {
  const NotificationFailure(super.message);
}

/// An unexpected / unclassified failure. Used only at the outermost boundary.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message);
}
