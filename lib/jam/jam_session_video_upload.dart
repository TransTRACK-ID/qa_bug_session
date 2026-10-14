import 'dart:typed_data';

import '../bug_session/kit/bug_session_kit.dart';
import '../bug_session/recording/bug_session_video_capture.dart';
import 'jam_dev_client.dart';
import 'jam_dev_connection.dart';

/// Uploads [video] to Jam when Ready-to-Test credentials are stored.
Future<String?> uploadVideoToJamIfConfigured(
  BugSessionKit kit, {
  required BugSessionVideoArtifact video,
  required String title,
  void Function(double progress)? onProgress,
}) async {
  final store = kit.config.jamDevCredentialsStore;
  if (store == null) {
    return null;
  }
  final connection = await store.read();
  if (connection == null || !connection.isComplete) {
    return null;
  }
  return uploadVideoToJam(
    connection: connection,
    video: video,
    title: title,
    pageUrl: kit.config.currentRouteName?.call() ?? '',
    onProgress: onProgress,
  );
}

Future<String?> uploadVideoToJam({
  required JamDevConnection connection,
  required BugSessionVideoArtifact video,
  required String title,
  String pageUrl = '',
  void Function(double progress)? onProgress,
}) async {
  if (video.bytes.isEmpty) {
    return null;
  }
  final client = JamDevClient(
    personalAccessToken: connection.personalAccessToken,
    teamId: connection.teamId,
  );
  final result = await client.uploadVideo(
    mp4Bytes: video.bytes,
    title: title,
    url: pageUrl,
    width: video.width ?? 1080,
    height: video.height ?? 1920,
    onProgress: onProgress,
  );
  return result.shareUrl;
}

/// When [includeVideoInSessionZip] is false, uploads MP4 to Jam and drops local video.
Future<({Map<String, List<int>> archiveFiles, String? jamShareUrl})>
    finalizeSessionVideoForCatalog(
  BugSessionKit kit, {
  required Map<String, List<int>> visualArchiveFiles,
  required String title,
  void Function(double progress)? onJamUploadProgress,
}) async {
  if (kit.config.includeVideoInSessionZip || visualArchiveFiles.isEmpty) {
    return (archiveFiles: visualArchiveFiles, jamShareUrl: null);
  }
  List<int>? mp4Bytes;
  for (final entry in visualArchiveFiles.entries) {
    if (entry.key.toLowerCase().endsWith('.mp4')) {
      mp4Bytes = entry.value;
      break;
    }
  }
  mp4Bytes ??=
      visualArchiveFiles.values.isNotEmpty ? visualArchiveFiles.values.first : null;
  if (mp4Bytes == null || mp4Bytes.isEmpty) {
    return (archiveFiles: <String, List<int>>{}, jamShareUrl: null);
  }
  final jamUrl = await uploadMp4BytesToJamIfConfigured(
    kit,
    mp4Bytes: Uint8List.fromList(mp4Bytes),
    title: title,
    onProgress: onJamUploadProgress,
  );
  if (jamUrl == null || jamUrl.isEmpty) {
    return (archiveFiles: visualArchiveFiles, jamShareUrl: null);
  }
  kit.recorder.discardLocalVideoAfterJamUpload();
  return (archiveFiles: <String, List<int>>{}, jamShareUrl: jamUrl);
}

Future<String?> uploadMp4BytesToJamIfConfigured(
  BugSessionKit kit, {
  required Uint8List mp4Bytes,
  required String title,
  int width = 1080,
  int height = 1920,
  void Function(double progress)? onProgress,
}) async {
  if (mp4Bytes.isEmpty) {
    return null;
  }
  return uploadVideoToJamIfConfigured(
    kit,
    video: BugSessionVideoArtifact(
      bytes: mp4Bytes,
      archiveFileName: 'session.mp4',
      mimeType: 'video/mp4',
      width: width,
      height: height,
    ),
    title: title,
    onProgress: onProgress,
  );
}
