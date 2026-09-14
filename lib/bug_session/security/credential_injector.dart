import '../models/manifest.dart';

/// Injects QA credentials for replay (Strategy C, Section 10).
abstract interface class CredentialInjector {
  /// Persists QA session material into the app's normal auth storage.
  Future<void> inject(
    BugSessionCredential credential, {
    BugSessionUser? user,
  });

  /// Resolves the backend user id after injection (e.g. profile / whoami).
  Future<String> resolveUserId();

  /// Attempt refresh when access token expired; return false if unrecoverable.
  Future<bool> tryRefresh(BugSessionCredential credential);

  /// Restores the developer's session after replay completes.
  Future<void> restorePreviousSession();
}

class CredentialInjectionException implements Exception {
  CredentialInjectionException(this.message);

  final String message;

  @override
  String toString() => 'CredentialInjectionException: $message';
}
