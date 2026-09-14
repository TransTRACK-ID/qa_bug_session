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
}

class BugSessionVideoArtifact {
  const BugSessionVideoArtifact({
    required this.bytes,
    required this.archiveFileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String archiveFileName;
  final String mimeType;
}
