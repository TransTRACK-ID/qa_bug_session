/// How a saved session was captured (distinct from catalog zip provenance).
enum BugSessionRecordingKind {
  instantReplay,
  fullRecord,
  qaNotionCard,
  imported,
}

extension BugSessionRecordingKindLabels on BugSessionRecordingKind {
  String get label => switch (this) {
        BugSessionRecordingKind.instantReplay => 'Instant Replay',
        BugSessionRecordingKind.fullRecord => 'Full Record',
        BugSessionRecordingKind.qaNotionCard => 'QA testing',
        BugSessionRecordingKind.imported => 'Imported',
      };
}

/// Resolves kind for legacy `index.json` rows without `recordingKind`.
BugSessionRecordingKind? inferBugSessionRecordingKind({
  required String displayName,
  required String catalogSourceName,
  String? recordingKindJson,
}) {
  if (recordingKindJson != null && recordingKindJson.isNotEmpty) {
    return BugSessionRecordingKind.values.byName(recordingKindJson);
  }
  if (displayName.startsWith('QA ·')) {
    return BugSessionRecordingKind.qaNotionCard;
  }
  if (catalogSourceName == 'imported') {
    return BugSessionRecordingKind.imported;
  }
  return null;
}
