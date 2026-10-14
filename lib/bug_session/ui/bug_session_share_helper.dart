import '../kit/bug_session_config.dart';
import '../kit/bug_session_kit.dart';
import '../library/bug_session_catalog_entry.dart';
import 'bug_session_share_jam.dart';
import 'bug_session_share_visual.dart';

Future<void> shareBugSessionCatalogEntry({
  required BugSessionKit kit,
  required BugSessionCatalogEntry entry,
}) async {
  final config = kit.config;
  final share = config.shareExport;
  final zipPath = entry.filePath;
  if (share == null || zipPath == null) {
    throw StateError('Export this session to a zip before sharing');
  }

  final jamRecordingUrl = config.includeVideoInSessionZip
      ? entry.jamShareUrl
      : await ensureJamRecordingUrlForShare(kit, entry);

  final videoPath = config.includeVideoInSessionZip
      ? await resolveBugSessionShareVideoPath(
          zipPath: zipPath,
          videoSidecarPath: entry.videoSidecarPath,
        )
      : null;

  await share(
    BugSessionShareExportRequest(
      zipPath: zipPath,
      videoPath: videoPath,
      jamRecordingUrl: jamRecordingUrl,
    ),
  );
}
