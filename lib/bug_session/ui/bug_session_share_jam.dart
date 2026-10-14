import 'dart:io';
import 'dart:typed_data';

import '../../jam/jam_session_video_upload.dart';
import '../kit/bug_session_kit.dart';
import '../library/bug_session_catalog_entry.dart';
import 'bug_session_share_visual.dart';

/// Ensures a Jam URL exists for share/export when video is kept off-device.
Future<String?> ensureJamRecordingUrlForShare(
  BugSessionKit kit,
  BugSessionCatalogEntry entry,
) async {
  final existing = entry.jamShareUrl;
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }
  if (kit.config.includeVideoInSessionZip) {
    return null;
  }
  final bytes = await _readSessionVideoBytes(entry);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  final url = await uploadMp4BytesToJamIfConfigured(
    kit,
    mp4Bytes: bytes,
    title: entry.displayName,
  );
  if (url == null || url.isEmpty) {
    return null;
  }
  await kit.catalog.updateJamShareUrl(entry.sessionId, url);
  await kit.catalog.purgeVideoForSession(entry.sessionId);
  kit.recorder.discardLocalVideoAfterJamUpload();
  return url;
}

Future<Uint8List?> _readSessionVideoBytes(BugSessionCatalogEntry entry) async {
  final sidecar = entry.videoSidecarPath;
  if (sidecar != null) {
    final file = File(sidecar);
    if (await file.exists()) {
      return file.readAsBytes();
    }
  }
  final zipPath = entry.filePath;
  if (zipPath == null) {
    return null;
  }
  final videoPath = await resolveBugSessionShareVideoPath(
    zipPath: zipPath,
    videoSidecarPath: null,
  );
  if (videoPath == null) {
    return null;
  }
  final videoFile = File(videoPath);
  if (!await videoFile.exists()) {
    return null;
  }
  return videoFile.readAsBytes();
}
