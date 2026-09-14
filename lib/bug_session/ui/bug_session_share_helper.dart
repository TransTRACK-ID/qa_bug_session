import '../kit/bug_session_config.dart';
import '../library/bug_session_catalog_entry.dart';
import 'bug_session_share_visual.dart';

Future<void> shareBugSessionCatalogEntry({
  required BugSessionConfig config,
  required BugSessionCatalogEntry entry,
}) async {
  final share = config.shareExport;
  final zipPath = entry.filePath;
  if (share == null || zipPath == null) {
    throw StateError('Export this session to a zip before sharing');
  }
  final videoPath = await resolveBugSessionShareVideoPath(
    zipPath: zipPath,
    videoSidecarPath: entry.videoSidecarPath,
  );
  await share(
    BugSessionShareExportRequest(
      zipPath: zipPath,
      videoPath: videoPath,
    ),
  );
}
