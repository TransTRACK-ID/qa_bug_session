import '../comparison/session_comparator.dart';
import '../models/bug_session.dart';
import '../models/recorded_action.dart';
import '../recording/interaction_recorder.dart';
import '../recording/network_recorder.dart';
import '../recording/semantic_interaction_recorder.dart';
import '../runtime/bug_session_environment.dart';
import '../security/credential_injector.dart';
import '../security/session_lock_validator.dart';
import 'replay_failure.dart';
import 'replay_result.dart';

class CompatibilityWarning {
  CompatibilityWarning(this.message);
  final String message;
}

/// Live-backend replay (Section 16–17). Never substitutes recorded responses.
class BugSessionReplayer {
  BugSessionReplayer({
    InteractionRecorder? interactionRecorder,
    NetworkRecorder? replayNetworkRecorder,
    this.credentialInjector,
    SessionLockValidator? lockValidator,
    SessionComparator? comparator,
    this.validateUserIdentityOnReplay = false,
    this.restoreSessionAfterReplay = false,
    this.replayBootstrap,
    this.prepareForReplay,
  })  : interactionRecorder =
            interactionRecorder ?? SemanticInteractionRecorder(),
        replayNetworkRecorder =
            replayNetworkRecorder ?? InMemoryNetworkRecorder(),
        lockValidator = lockValidator ?? SessionLockValidator(),
        comparator = comparator ?? SessionComparator();

  final InteractionRecorder interactionRecorder;
  final NetworkRecorder replayNetworkRecorder;
  final CredentialInjector? credentialInjector;
  final SessionLockValidator lockValidator;
  final SessionComparator comparator;
  final bool validateUserIdentityOnReplay;
  final bool restoreSessionAfterReplay;
  final Future<void> Function(BugSession session)? replayBootstrap;
  final Future<void> Function(BugSession session)? prepareForReplay;

  List<CompatibilityWarning> compatibilityWarnings(
    BugSession session,
    BugSessionEnvironment current,
  ) {
    final warnings = <CompatibilityWarning>[];
    if (session.manifest.appVersion != current.appVersion ||
        session.manifest.buildNumber != current.buildNumber) {
      warnings.add(
        CompatibilityWarning(
          'Session was recorded on ${session.manifest.appVersion} '
          '(${session.manifest.buildNumber}). Current app: '
          '${current.appVersion} (${current.buildNumber}). '
          'Replay may behave differently.',
        ),
      );
    }
    if (session.manifest.environment != null &&
        current.environment != null &&
        session.manifest.environment != current.environment) {
      warnings.add(
        CompatibilityWarning(
          'Recorded environment: ${session.manifest.environment}. '
          'Current environment: ${current.environment}.',
        ),
      );
    }
    return warnings;
  }

  Future<SessionLockValidationResult> validateImportLock({
    required BugSession session,
    required BugSessionEnvironment current,
    required String resolvedUserId,
    bool? validateUserIdentity,
  }) async {
    return lockValidator.validate(
      lock: session.manifest.lock,
      sessionId: session.manifest.sessionId,
      runningPackageId: current.packageId,
      runningAppVersion: current.appVersion,
      runningBuildNumber: current.buildNumber,
      resolvedUserId: resolvedUserId,
      validateUserIdentity:
          validateUserIdentity ?? validateUserIdentityOnReplay,
    );
  }

  Future<ReplayResult> replay({
    required BugSession session,
    required BugSessionEnvironment current,
    Duration targetTimeout = const Duration(seconds: 10),
    void Function(String message)? onLockFailureFlash,
    bool Function()? shouldStop,
  }) async {
    final injector = credentialInjector;
    if (injector == null) {
      throw StateError('CredentialInjector is required for replay');
    }

    await prepareForReplay?.call(session);

    replayNetworkRecorder.startSession('replay-${session.manifest.sessionId}');
    if (replayNetworkRecorder is InMemoryNetworkRecorder) {
      (replayNetworkRecorder as InMemoryNetworkRecorder).markSessionClockStart();
    }

    await replayBootstrap?.call(session);

    await injector.inject(
      session.manifest.credential,
      user: session.manifest.user,
    );
    var resolvedUserId = await injector.resolveUserId();
    if (validateUserIdentityOnReplay &&
        resolvedUserId != session.manifest.user.userId) {
      final refreshed =
          await injector.tryRefresh(session.manifest.credential);
      if (refreshed) {
        resolvedUserId = await injector.resolveUserId();
      }
    }

    final lockResult = await validateImportLock(
      session: session,
      current: current,
      resolvedUserId: resolvedUserId,
    );
    if (!lockResult.isValid) {
      onLockFailureFlash?.call(lockResult.flashMessage());
      await injector.restorePreviousSession();
      throw ReplayBlockedException(lockResult.flashMessage());
    }

    if (validateUserIdentityOnReplay &&
        session.manifest.user.userId.isNotEmpty &&
        resolvedUserId != session.manifest.user.userId) {
      onLockFailureFlash?.call(lockResult.flashMessage());
      await injector.restorePreviousSession();
      throw CredentialInjectionException(
        'Identity after credential injection does not match recorded user.',
      );
    }

    var succeeded = 0;
    ReplayFailure? failure;
    var cancelled = false;
    try {
      succeeded = await interactionRecorder.replay(
        RecordedActions(actions: session.actions),
        targetTimeout: targetTimeout,
        shouldStop: shouldStop,
        onActionFailed: (action, error) {
          failure = ReplayFailure(
            actionIndex: succeeded,
            action: action,
            reason: error.toString(),
          );
        },
      );
      cancelled = shouldStop?.call() == true &&
          succeeded < session.actions.length &&
          failure == null;
    } catch (e) {
      failure ??= ReplayFailure(
        actionIndex: succeeded,
        action: session.actions[succeeded],
        reason: e.toString(),
      );
    } finally {
      replayNetworkRecorder.stopSession();
      if (restoreSessionAfterReplay) {
        await injector.restorePreviousSession();
      }
    }

    if (failure != null) {
      return ReplayResult(
        actionsAttempted: session.actions.length,
        actionsSucceeded: succeeded,
        replayNetworkEvents: replayNetworkRecorder.getEvents(),
        failure: failure,
      );
    }

    if (cancelled) {
      return ReplayResult(
        actionsAttempted: session.actions.length,
        actionsSucceeded: succeeded,
        replayNetworkEvents: replayNetworkRecorder.getEvents(),
        cancelled: true,
      );
    }

    final comparison = comparator.compare(
      originalNetwork: session.networkEvents,
      replayNetwork: replayNetworkRecorder.getEvents(),
    );

    return ReplayResult(
      actionsAttempted: session.actions.length,
      actionsSucceeded: succeeded,
      replayNetworkEvents: replayNetworkRecorder.getEvents(),
      comparison: comparison,
    );
  }
}

class ReplayBlockedException implements Exception {
  ReplayBlockedException(this.flashMessage);
  final String flashMessage;

  @override
  String toString() => flashMessage;
}
