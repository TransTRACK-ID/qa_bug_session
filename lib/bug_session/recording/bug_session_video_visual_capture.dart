import 'dart:async';
import 'dart:typed_data';

import '../models/visual_evidence_frame.dart';
import 'bug_session_video_capture.dart';

/// Host-driven screen recording (typically GIF) for visual evidence.
class BugSessionVideoVisualCapture {
  BugSessionVideoVisualCapture({
    required BugSessionVideoCapture capture,
    Duration maxDuration = const Duration(minutes: 1),
  })  : _capture = capture,
        _maxDuration = maxDuration;

  final BugSessionVideoCapture _capture;
  final Duration _maxDuration;

  BugSessionVideoArtifact? _artifact;
  Timer? _maxTimer;
  bool _halted = false;
  bool _maxDurationLimitHeld = false;

  Future<void> start() async {
    await _beginRollingCapture(clearArtifact: true);
  }

  Future<void> _beginRollingCapture({required bool clearArtifact}) async {
    if (clearArtifact) {
      _artifact = null;
    }
    _halted = false;
    _maxTimer?.cancel();
    await _capture.start(maxDuration: _maxDuration);
    if (!_maxDurationLimitHeld) {
      _maxTimer = Timer(_maxDuration, () {
        unawaited(stop());
      });
    }
  }

  /// QA card testing: do not stop capture after [maxDuration] (often 1 minute).
  void holdMaxDurationLimit() {
    _maxDurationLimitHeld = true;
    _maxTimer?.cancel();
    _maxTimer = null;
  }

  void releaseMaxDurationLimit() {
    _maxDurationLimitHeld = false;
  }

  Future<void> waitForBufferedFrames({
    int minimum = 1,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await _deferrable?.waitForMinimumFrames(
      minimum: minimum,
      timeout: timeout,
    );
  }

  /// Stops frame capture only (no encode). For fast Shadowplay save.
  Future<void> haltCapture() async {
    _maxTimer?.cancel();
    _maxTimer = null;
    final deferrable = _deferrable;
    if (deferrable != null) {
      await deferrable.haltCapture();
      _halted = true;
      return;
    }
    await stop();
  }

  /// Encodes after [haltCapture], returns archive bytes, then restarts capture.
  /// Snapshot MP4 for QA issue upload, then resume rolling capture.
  Future<BugSessionVideoArtifact?> snapshotAndResume() async {
    await haltCapture();
    final artifact = await _deferrable?.finalizeCapture();
    _halted = false;
    await _beginRollingCapture(clearArtifact: true);
    return artifact;
  }

  /// Final MP4 when QA testing ends (no resume).
  Future<BugSessionVideoArtifact?> finalizeWithoutResume() async {
    await haltCapture();
    return _deferrable?.finalizeCapture();
  }

  Future<Map<String, Uint8List>> finalizeCaptureAndRestart() async {
    if (_deferrable != null && _halted) {
      _artifact = await _deferrable!.finalizeCapture();
      _halted = false;
      final files = toArchiveFiles();
      await _beginRollingCapture(clearArtifact: true);
      return files;
    }
    if (_artifact == null) {
      await stop();
      await _beginRollingCapture(clearArtifact: true);
    }
    return toArchiveFiles();
  }

  Future<void> stop() async {
    _maxTimer?.cancel();
    _maxTimer = null;
    _halted = false;
    _artifact = await _capture.stop();
  }

  BugSessionDeferrableVideoCapture? get _deferrable =>
      _capture is BugSessionDeferrableVideoCapture
          ? _capture as BugSessionDeferrableVideoCapture
          : null;

  List<VisualEvidenceFrame> toArchiveIndex() {
    final artifact = _artifact;
    if (artifact == null) {
      return const [];
    }
    return [
      VisualEvidenceFrame(
        timestampMs: 0,
        archivePath: 'visual/${artifact.archiveFileName}',
      ),
    ];
  }

  Map<String, Uint8List> toArchiveFiles() {
    final artifact = _artifact;
    if (artifact == null) {
      return const {};
    }
    return {
      'visual/${artifact.archiveFileName}': artifact.bytes,
    };
  }

  void discardCachedArtifact() {
    _artifact = null;
  }
}
