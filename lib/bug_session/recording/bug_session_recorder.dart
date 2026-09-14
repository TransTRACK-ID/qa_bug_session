import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/bug_session.dart';
import '../models/diagnostic_event.dart';
import '../models/network_event.dart';
import '../models/recorded_action.dart';
import '../models/manifest.dart';
import '../runtime/bug_session_environment.dart';
import '../security/session_lock_validator.dart';
import 'interaction_recorder.dart';
import 'network_recorder.dart';
import 'bug_session_video_visual_capture.dart';
import 'bug_session_visual_capture.dart';
import '../shadowplay/bug_session_shadowplay_engine.dart';
import '../shadowplay/shadowplay_settings.dart';
import 'semantic_interaction_recorder.dart';

export 'semantic_interaction_recorder.dart';

enum BugSessionRecorderState {
  idle,
  recording,
  stopping,
  readyToExport,
}

/// Orchestrates interaction + network + diagnostics for one session.
class BugSessionRecorder extends ChangeNotifier {
  BugSessionRecorder({
    SemanticInteractionRecorder? semanticRecorder,
    NetworkRecorder? networkRecorder,
    BugSessionVisualCapture? visualCapture,
    BugSessionVideoVisualCapture? videoCapture,
    BugSessionShadowplaySettings shadowplaySettings =
        const BugSessionShadowplaySettings(),
  })  : semanticRecorder = semanticRecorder ?? SemanticInteractionRecorder(),
        networkRecorder = networkRecorder ?? InMemoryNetworkRecorder(),
        visualCapture = visualCapture,
        videoCapture = videoCapture,
        shadowplay = BugSessionShadowplayEngine(shadowplaySettings);

  final SemanticInteractionRecorder semanticRecorder;
  final NetworkRecorder networkRecorder;
  final BugSessionVisualCapture? visualCapture;
  final BugSessionVideoVisualCapture? videoCapture;
  final BugSessionShadowplayEngine shadowplay;

  InteractionRecorder get interactionRecorder => semanticRecorder;

  bool get isShadowplayActive => shadowplay.isActive;

  bool _shadowplayCaptureSuspended = false;

  /// True when inputs are recorded (not during replay / suspended buffer).
  bool get isCapturing =>
      isRecording ||
      (isShadowplayActive && !_shadowplayCaptureSuspended);

  bool get isShadowplayBuffering =>
      isShadowplayActive && !_shadowplayCaptureSuspended && !isRecording;

  /// Alias for recording taps/navigation from widgets and tests.
  SemanticInteractionRecorder get semantic => semanticRecorder;

  BugSessionRecorderState state = BugSessionRecorderState.idle;
  BugSession? lastSession;
  String? _sessionId;
  DateTime? _startedAt;
  Duration? _frozenRecordingElapsed;
  final List<DiagnosticEvent> _diagnostics = [];
  int? _diagStartMs;
  Map<String, Uint8List> _visualArchiveFiles = {};

  bool get isRecording => state == BugSessionRecorderState.recording;

  Duration? get recordingElapsed {
    if (state == BugSessionRecorderState.stopping) {
      return _frozenRecordingElapsed;
    }
    if (!isRecording) {
      return null;
    }
    final start = _startedAt;
    if (start == null) {
      return null;
    }
    return DateTime.now().toUtc().difference(start);
  }

  List<RecordedAction> get recordedActions => semanticRecorder.actions;

  List<DiagnosticEvent> get recordedDiagnostics =>
      List.unmodifiable(_diagnostics);

  void recordDiagnostic(String type, String message, {String? stackTrace}) {
    if (isShadowplayActive) {
      final start = shadowplay.elapsedMs();
      shadowplay.recordDiagnostic(
        DiagnosticEvent(
          timestampMs: start,
          type: type,
          message: message,
          stackTrace: stackTrace,
        ),
      );
    }
    if (!isRecording) return;
    final start = _diagStartMs ?? DateTime.now().millisecondsSinceEpoch;
    _diagStartMs ??= start;
    _diagnostics.add(
      DiagnosticEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch - start,
        type: type,
        message: message,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> startShadowplay() async {
    if (isRecording) {
      throw StateError('Stop classic recording before Shadowplay');
    }
    shadowplay.start();
    if (networkRecorder is InMemoryNetworkRecorder) {
      (networkRecorder as InMemoryNetworkRecorder)
        ..startSession('shadowplay-live')
        ..markSessionClockStart();
    }
    visualCapture?.start();
    await videoCapture?.start();
    notifyListeners();
  }

  void recordShadowplayAction(RecordedAction action) {
    if (!isShadowplayActive || _shadowplayCaptureSuspended) {
      return;
    }
    shadowplay.recordAction(action);
  }

  Future<void> suspendShadowplayCapture() async {
    _shadowplayCaptureSuspended = true;
    await pauseShadowplayRollingVideo();
    notifyListeners();
  }

  Future<void> resumeShadowplayCapture() async {
    _shadowplayCaptureSuspended = false;
    if (isShadowplayActive && !isRecording) {
      await videoCapture?.start();
    }
    notifyListeners();
  }

  void mirrorNetworkToShadowplay(NetworkEvent event) {
    if (!isShadowplayActive || _shadowplayCaptureSuspended) {
      return;
    }
    shadowplay.recordNetwork(event);
  }

  /// Stops rolling media capture only (no encode). Call before naming a clip.
  Future<void> haltShadowplayMediaForSave() async {
    if (!isShadowplayActive) {
      throw StateError('Shadowplay is not active');
    }
    state = BugSessionRecorderState.stopping;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    await videoCapture?.haltCapture();
    await visualCapture?.stop();
  }

  /// Builds a clip session after [haltShadowplayMediaForSave] and restarts Shadowplay.
  Future<BugSession> buildShadowplayClipSession(
    BugSessionEnvironment environment,
  ) async {
    if (!isShadowplayActive) {
      throw StateError('Shadowplay is not active');
    }
    _visualArchiveFiles = const {};
    final snap = shadowplay.snapshot();
    final sessionId = _newSessionId();
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      snap.startedAtMs,
      isUtc: true,
    );
    final stoppedAt = DateTime.now().toUtc();

    final lock = BugSessionLock(
      packageId: environment.packageId,
      appVersion: environment.appVersion,
      buildNumber: environment.buildNumber,
      userId: environment.user.userId,
      lockChecksum: SessionLockValidator.computeLockChecksum(
        packageId: environment.packageId,
        appVersion: environment.appVersion,
        buildNumber: environment.buildNumber,
        userId: environment.user.userId,
        sessionId: sessionId,
      ),
    );

    final manifest = BugSessionManifest(
      sessionId: sessionId,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      appVersion: environment.appVersion,
      buildNumber: environment.buildNumber,
      platform: environment.platform,
      osVersion: environment.osVersion,
      deviceModel: environment.deviceModel,
      environment: environment.environment,
      user: environment.user,
      credential: environment.credential,
      lock: lock,
    );

    final visualIndex = [
      ...?visualCapture?.toArchiveIndex(),
      ...?videoCapture?.toArchiveIndex(),
    ];
    final session = BugSession(
      formatVersion: BugSession.supportedFormatVersion,
      manifest: manifest,
      actions: snap.actions,
      networkEvents: snap.networkEvents,
      diagnostics: snap.diagnostics,
      visualEvidence: visualIndex,
    );

    lastSession = session;
    state = BugSessionRecorderState.idle;
    networkRecorder.stopSession();
    shadowplay.start();
    if (networkRecorder is InMemoryNetworkRecorder) {
      (networkRecorder as InMemoryNetworkRecorder)
        ..startSession('shadowplay-live')
        ..markSessionClockStart();
    }
    await _resumeShadowplayMediaAfterClipSave();
    notifyListeners();
    return session;
  }

  /// Restores rolling capture after save was aborted or failed mid-flight.
  Future<void> recoverFromHaltedShadowplaySave() async {
    if (!isShadowplayActive) {
      return;
    }
    if (state != BugSessionRecorderState.stopping) {
      return;
    }
    state = BugSessionRecorderState.idle;
    shadowplay.start();
    await _resumeShadowplayMediaAfterClipSave();
    notifyListeners();
  }

  Future<void> _resumeShadowplayMediaAfterClipSave() async {
    if (_shadowplayCaptureSuspended || isRecording) {
      return;
    }
    visualCapture?.start();
    await resumeShadowplayRollingVideo();
  }

  Future<BugSession> saveShadowplaySnapshot(
    BugSessionEnvironment environment,
  ) async {
    await haltShadowplayMediaForSave();
    return buildShadowplayClipSession(environment);
  }

  /// Finishes deferred video encode after [haltShadowplayMediaForSave].
  Future<Map<String, Uint8List>> finalizeDeferredVideoCapture() async {
    final files = await videoCapture?.finalizeCaptureAndRestart() ?? const {};
    if (files.isNotEmpty) {
      _visualArchiveFiles = files;
    }
    return files;
  }

  /// Stops rolling Shadowplay video only (events buffer keeps running).
  Future<void> pauseShadowplayRollingVideo() async {
    if (!isShadowplayActive) {
      return;
    }
    await videoCapture?.haltCapture();
  }

  /// Restarts rolling Shadowplay video after manual record.
  Future<void> resumeShadowplayRollingVideo() async {
    if (!isShadowplayActive || isRecording) {
      return;
    }
    await videoCapture?.start();
  }

  Future<void> start({String? sessionId}) async {
    if (state == BugSessionRecorderState.recording) {
      throw StateError('Already recording');
    }
    await suspendShadowplayCapture();
    _sessionId = sessionId ?? _newSessionId();
    _startedAt = DateTime.now().toUtc();
    _frozenRecordingElapsed = null;
    _diagnostics.clear();
    _diagStartMs = DateTime.now().millisecondsSinceEpoch;
    state = BugSessionRecorderState.recording;
    await semanticRecorder.start(_sessionId!);
    networkRecorder.startSession(_sessionId!);
    if (networkRecorder is InMemoryNetworkRecorder) {
      (networkRecorder as InMemoryNetworkRecorder).markSessionClockStart();
    }
    visualCapture?.start();
    unawaited(videoCapture?.start());
    notifyListeners();
  }

  Future<BugSession> stop(BugSessionEnvironment environment) async {
    if (state != BugSessionRecorderState.recording) {
      throw StateError('Not recording');
    }
    final startedAt = _startedAt;
    if (startedAt != null) {
      _frozenRecordingElapsed =
          DateTime.now().toUtc().difference(startedAt);
    }
    state = BugSessionRecorderState.stopping;
    notifyListeners();
    await visualCapture?.stop();
    await videoCapture?.stop();
    _visualArchiveFiles = {
      ...?visualCapture?.toArchiveFiles(),
      ...?videoCapture?.toArchiveFiles(),
    };
    final actions = await semanticRecorder.stop();
    networkRecorder.stopSession();
    final stoppedAt = DateTime.now().toUtc();
    final sessionId = _sessionId!;

    final lock = BugSessionLock(
      packageId: environment.packageId,
      appVersion: environment.appVersion,
      buildNumber: environment.buildNumber,
      userId: environment.user.userId,
      lockChecksum: SessionLockValidator.computeLockChecksum(
        packageId: environment.packageId,
        appVersion: environment.appVersion,
        buildNumber: environment.buildNumber,
        userId: environment.user.userId,
        sessionId: sessionId,
      ),
    );

    final manifest = BugSessionManifest(
      sessionId: sessionId,
      startedAt: _startedAt!,
      stoppedAt: stoppedAt,
      appVersion: environment.appVersion,
      buildNumber: environment.buildNumber,
      platform: environment.platform,
      osVersion: environment.osVersion,
      deviceModel: environment.deviceModel,
      environment: environment.environment,
      user: environment.user,
      credential: environment.credential,
      lock: lock,
    );

    final visualIndex = [
      ...?visualCapture?.toArchiveIndex(),
      ...?videoCapture?.toArchiveIndex(),
    ];
    final session = BugSession(
      formatVersion: BugSession.supportedFormatVersion,
      manifest: manifest,
      actions: actions.actions,
      networkEvents: networkRecorder.getEvents(),
      diagnostics: List.unmodifiable(_diagnostics),
      visualEvidence: visualIndex,
    );

    lastSession = session;
    state = BugSessionRecorderState.readyToExport;
    _sessionId = null;
    _startedAt = null;
    _frozenRecordingElapsed = null;
    notifyListeners();
    return session;
  }

  /// Restores [lastSession] after app restart (from on-disk catalog).
  void restoreLastSession(BugSession session) {
    lastSession = session;
    if (state == BugSessionRecorderState.idle) {
      state = BugSessionRecorderState.readyToExport;
    }
    notifyListeners();
  }

  /// Clears [lastSession] after stop; does not remove catalog entries.
  void discardLastSession() {
    lastSession = null;
    if (state == BugSessionRecorderState.readyToExport) {
      state = BugSessionRecorderState.idle;
    }
    notifyListeners();
  }

  void resetToIdle() {
    state = BugSessionRecorderState.idle;
    lastSession = null;
    notifyListeners();
  }

  Map<String, Uint8List> takeVisualArchiveFiles() {
    final files = _visualArchiveFiles;
    _visualArchiveFiles = {};
    return files;
  }

  String _newSessionId() {
    final now = DateTime.now().toUtc();
    return 'bug-session-${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch}';
  }
}
