import 'package:meta/meta.dart';

import 'diagnostic_event.dart';
import 'manifest.dart';
import 'network_event.dart';
import 'recorded_action.dart';
import 'visual_evidence_frame.dart';

/// Stable BugSession export model.
@immutable
class BugSession {
  const BugSession({
    required this.formatVersion,
    required this.manifest,
    required this.actions,
    required this.networkEvents,
    required this.diagnostics,
    this.visualEvidence = const [],
  });

  static const int supportedFormatVersion = 2;

  final int formatVersion;
  final BugSessionManifest manifest;
  final List<RecordedAction> actions;
  final List<NetworkEvent> networkEvents;
  final List<DiagnosticEvent> diagnostics;
  final List<VisualEvidenceFrame> visualEvidence;

  Map<String, Object?> toArchiveManifestJson() => {
        'formatVersion': formatVersion,
        ...manifest.toJson(),
      };
}
