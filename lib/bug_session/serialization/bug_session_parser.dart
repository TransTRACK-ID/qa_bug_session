import 'dart:convert';

import '../models/bug_session.dart';
import '../models/diagnostic_event.dart';
import '../models/manifest.dart';
import '../models/network_event.dart';
import '../models/recorded_action.dart';
import '../models/visual_evidence_frame.dart';

class BugSessionArchiveParser {
  BugSession parseParts({
    required String manifestJson,
    required String actionsJson,
    required String networkJson,
    required String diagnosticsJson,
    String? visualEvidenceJson,
  }) {
    final manifestMap =
        Map<String, Object?>.from(jsonDecode(manifestJson) as Map);
    final formatVersion = manifestMap['formatVersion'] as int?;
    if (formatVersion == null) {
      throw FormatException('Missing formatVersion');
    }
    if (formatVersion != 1 && formatVersion != BugSession.supportedFormatVersion) {
      throw FormatException(
        'Unsupported BugSession formatVersion: $formatVersion',
      );
    }

    final manifestFields = Map<String, Object?>.from(manifestMap);
    manifestFields.remove('formatVersion');

    final actionsList = (jsonDecode(actionsJson) as Map)['actions'] as List;
    final networkList = (jsonDecode(networkJson) as Map)['events'] as List;
    final diagList =
        (jsonDecode(diagnosticsJson) as Map)['diagnostics'] as List;

    final visualList = visualEvidenceJson == null
        ? const <VisualEvidenceFrame>[]
        : ((jsonDecode(visualEvidenceJson) as Map)['frames'] as List)
            .map(
              (e) => VisualEvidenceFrame.fromJson(
                Map<String, Object?>.from(e as Map),
              ),
            )
            .toList();

    return BugSession(
      formatVersion: formatVersion,
      manifest: BugSessionManifest.fromJson(manifestFields),
      actions: actionsList
          .map(
            (e) => RecordedAction.fromJson(Map<String, Object?>.from(e as Map)),
          )
          .toList(),
      networkEvents: networkList
          .map(
            (e) => NetworkEvent.fromJson(Map<String, Object?>.from(e as Map)),
          )
          .toList(),
      diagnostics: diagList
          .map(
            (e) =>
                DiagnosticEvent.fromJson(Map<String, Object?>.from(e as Map)),
          )
          .toList(),
      visualEvidence: visualList,
    );
  }
}
