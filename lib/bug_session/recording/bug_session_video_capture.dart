import 'dart:typed_data';

/// Host-provided screen recording (GIF/MP4) for a BugSession.
abstract interface class BugSessionVideoCapture {
  Future<void> start({required Duration maxDuration});

  Future<BugSessionVideoArtifact?> stop();
}

/// Shadowplay save: halt capture without blocking encode on the UI thread.
abstract interface class BugSessionDeferrableVideoCapture
    implements BugSessionVideoCapture {
  Future<void> haltCapture();

  Future<BugSessionVideoArtifact?> finalizeCapture();

  /// Waits until at least [minimum] frames are buffered or [timeout] elapses.
  Future<void> waitForMinimumFrames({
    int minimum = 1,
    Duration timeout = const Duration(seconds: 6),
  });
}

class BugSessionVideoArtifact {
  const BugSessionVideoArtifact({
    required this.bytes,
    required this.archiveFileName,
    required this.mimeType,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String archiveFileName;
  final String mimeType;
  final int? width;
  final int? height;
}
