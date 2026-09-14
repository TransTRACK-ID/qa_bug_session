import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves a shareable video file: sidecar on disk, or extracted from the zip.
Future<String?> resolveBugSessionShareVideoPath({
  required String zipPath,
  String? videoSidecarPath,
}) async {
  if (videoSidecarPath != null) {
    final sidecar = File(videoSidecarPath);
    if (await sidecar.exists() && await sidecar.length() > 0) {
      return videoSidecarPath;
    }
  }

  final zipFile = File(zipPath);
  if (!await zipFile.exists()) {
    return null;
  }

  final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
  ArchiveFile? visual;
  for (final file in archive.files) {
    final name = file.name.toLowerCase();
    if (name == 'visual/session.mp4' || name == 'visual/session.gif') {
      visual = file;
      break;
    }
  }
  if (visual == null) {
    return null;
  }

  final content = visual.content;
  if (content is! List<int> || content.isEmpty) {
    return null;
  }

  final ext = visual.name.toLowerCase().endsWith('.mp4') ? 'mp4' : 'gif';
  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/bug_session_share_${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await out.writeAsBytes(Uint8List.fromList(content), flush: true);
  return out.path;
}

String bugSessionShareVideoMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp4')) {
    return 'video/mp4';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  return 'application/octet-stream';
}
