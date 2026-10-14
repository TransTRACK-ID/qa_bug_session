import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/bug_session/library/bug_session_catalog_entry.dart';
import 'package:qa_bug_session/bug_session/library/bug_session_export_filename.dart';
import 'package:qa_bug_session/bug_session/library/bug_session_recording_kind.dart';

void main() {
  group('BugSessionCatalogEntry recordingKind', () {
    test('round-trips through JSON', () {
      final started = DateTime.utc(2026, 3, 1, 12);
      final entry = BugSessionCatalogEntry(
        sessionId: 's1',
        displayName: 'Clip A',
        source: BugSessionCatalogSource.recorded,
        startedAt: started,
        actionCount: 2,
        appVersion: '1.0',
        buildNumber: '1',
        recordingKind: BugSessionRecordingKind.instantReplay,
      );
      final restored = BugSessionCatalogEntry.fromJson(entry.toJson());
      expect(restored.recordingKind, BugSessionRecordingKind.instantReplay);
      expect(restored.recordingKindLabel, 'Instant Replay');
    });

    test('infers QA testing from legacy display name', () {
      final json = <String, Object?>{
        'sessionId': 's2',
        'displayName': 'QA · Fix login',
        'source': 'recorded',
        'startedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'actionCount': 1,
        'appVersion': '1',
        'buildNumber': '1',
      };
      final entry = BugSessionCatalogEntry.fromJson(json);
      expect(entry.recordingKind, BugSessionRecordingKind.qaNotionCard);
    });

    test('legacy row without kind uses Saved session label', () {
      final json = <String, Object?>{
        'sessionId': 's3',
        'displayName': '2026-01-01 10:00 · 3 actions',
        'source': 'recorded',
        'startedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'actionCount': 3,
        'appVersion': '1',
        'buildNumber': '1',
      };
      final entry = BugSessionCatalogEntry.fromJson(json);
      expect(entry.recordingKind, isNull);
      expect(entry.recordingKindLabel, BugSessionCatalogEntry.savedSessionLabel);
    });
  });

  group('bugSessionExportZipBasename', () {
    test('uses display name and BugSesh suffix', () {
      final name = bugSessionExportZipBasename(
        sessionId: 'abc',
        displayName: 'My Clip',
        startedAt: DateTime.utc(2026, 1, 1),
      );
      expect(name, 'My Clip_BugSesh.zip');
    });

    test('disambiguates with session tail', () {
      final name = bugSessionExportZipBasename(
        sessionId: 'long-session-id-12345678',
        displayName: 'My Clip',
        startedAt: DateTime.utc(2026, 1, 1),
        disambiguateSuffix: '12345678',
      );
      expect(name, 'My Clip-12345678_BugSesh.zip');
    });
  });
}
