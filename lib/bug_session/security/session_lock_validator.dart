import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/manifest.dart';

/// Hard gate: package + exact version/build + user identity (Section 11).
class SessionLockValidator {
  static String computeLockChecksum({
    required String packageId,
    required String appVersion,
    required String buildNumber,
    required String userId,
    required String sessionId,
  }) {
    final payload =
        '$packageId|$appVersion|$buildNumber|$userId|$sessionId';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static bool verifyChecksum(BugSessionLock lock, String sessionId) {
    final expected = computeLockChecksum(
      packageId: lock.packageId,
      appVersion: lock.appVersion,
      buildNumber: lock.buildNumber,
      userId: lock.userId,
      sessionId: sessionId,
    );
    return expected == lock.lockChecksum;
  }

  SessionLockValidationResult validate({
    required BugSessionLock lock,
    required String sessionId,
    required String runningPackageId,
    required String runningAppVersion,
    required String runningBuildNumber,
    required String resolvedUserId,
    bool validateUserIdentity = true,
  }) {
    final failures = <SessionLockFailure>[];

    if (!verifyChecksum(lock, sessionId)) {
      failures.add(SessionLockFailure.tampered());
    }
    if (lock.packageId != runningPackageId) {
      failures.add(
        SessionLockFailure.packageMismatch(
          expected: lock.packageId,
          actual: runningPackageId,
        ),
      );
    }
    if (lock.appVersion != runningAppVersion ||
        lock.buildNumber != runningBuildNumber) {
      failures.add(
        SessionLockFailure.versionMismatch(
          expectedVersion: lock.appVersion,
          expectedBuild: lock.buildNumber,
          actualVersion: runningAppVersion,
          actualBuild: runningBuildNumber,
        ),
      );
    }
    if (validateUserIdentity &&
        lock.userId.isNotEmpty &&
        lock.userId != resolvedUserId) {
      failures.add(SessionLockFailure.userMismatch());
    }

    return SessionLockValidationResult(failures: failures);
  }
}

enum SessionLockFailureKind {
  tampered,
  packageMismatch,
  versionMismatch,
  userMismatch,
}

class SessionLockFailure {
  const SessionLockFailure._(this.kind, this.message);

  factory SessionLockFailure.tampered() => const SessionLockFailure._(
        SessionLockFailureKind.tampered,
        'Session lock checksum is invalid (manifest may have been edited).',
      );

  factory SessionLockFailure.packageMismatch({
    required String expected,
    required String actual,
  }) =>
      SessionLockFailure._(
        SessionLockFailureKind.packageMismatch,
        'Package mismatch: expected $expected, got $actual',
      );

  factory SessionLockFailure.versionMismatch({
    required String expectedVersion,
    required String expectedBuild,
    required String actualVersion,
    required String actualBuild,
  }) =>
      SessionLockFailure._(
        SessionLockFailureKind.versionMismatch,
        'Version mismatch: session recorded on $expectedVersion ($expectedBuild), '
        'current app is $actualVersion ($actualBuild)',
      );

  factory SessionLockFailure.userMismatch() => const SessionLockFailure._(
        SessionLockFailureKind.userMismatch,
        'User mismatch: session belongs to a different account than the one '
        'currently authenticated',
      );

  final SessionLockFailureKind kind;
  final String message;
}

class SessionLockValidationResult {
  const SessionLockValidationResult({required this.failures});

  final List<SessionLockFailure> failures;

  bool get isValid => failures.isEmpty;

  String flashMessage() {
    if (isValid) return '';
    final lines = failures.map((f) => f.message).join('\n');
    return '⚠️ Cannot replay this BugSession\n$lines';
  }
}
