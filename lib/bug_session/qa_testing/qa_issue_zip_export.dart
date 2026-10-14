import 'dart:typed_data';

import '../export/bug_session_export_writer.dart';
import '../library/bug_session_export_filename.dart';
import '../../notion/notion_api.dart';
import '../../notion/notion_file_upload.dart';
import '../kit/bug_session_kit.dart';
import '../runtime/bug_session_environment.dart';
import 'qa_issue_screenshoot.dart';

class QaIssueAttachmentBundle {
  const QaIssueAttachmentBundle({
    required this.screenshootSection,
    this.notionFileUploadId,
  });

  final String screenshootSection;
  final String? notionFileUploadId;
}

Future<({Uint8List bytes, String filename})> exportQaIssueReplayZip(
  BugSessionKit kit,
) async {
  final env = await _environment(kit);
  final session = kit.recorder.buildInProgressSnapshot(env);
  final filename = bugSessionExportZipBasename(
    sessionId: session.manifest.sessionId,
    displayName: kit.qaTesting.title ?? 'QA issue',
    startedAt: session.manifest.startedAt,
  );
  final writer = BugSessionExportWriter();
  return (bytes: writer.toZipBytes(session), filename: filename);
}

/// Resolves Screenshoot text and optional Notion file upload id for the zip.
Future<QaIssueAttachmentBundle> buildQaIssueAttachmentBundle({
  required BugSessionKit kit,
  required NotionClient notion,
  required String jamUrl,
  required Uint8List zipBytes,
  required String zipFilename,
  void Function(double progress)? onNotionUploadProgress,
}) async {
  final hostUpload = kit.config.uploadIssueZipBytes;
  if (hostUpload != null) {
    try {
      final url = await hostUpload(zipBytes);
      if (url != null && url.trim().isNotEmpty) {
        return QaIssueAttachmentBundle(
          screenshootSection: formatQaIssueScreenshootSection(
            jamUrl: jamUrl,
            bugSessionZipUrl: url.trim(),
          ),
        );
      }
    } on Object {
      // Fall through to Notion upload.
    }
  }

  try {
    final uploadId = await notionUploadSmallFile(
      notion,
      bytes: zipBytes,
      filename: zipFilename,
      onUploadProgress: onNotionUploadProgress,
    );
    return QaIssueAttachmentBundle(
      screenshootSection: formatQaIssueScreenshootSection(
        jamUrl: jamUrl,
        bugSessionZipAttachedToPage: true,
      ),
      notionFileUploadId: uploadId,
    );
  } on Object {
    return QaIssueAttachmentBundle(
      screenshootSection: formatQaIssueScreenshootSection(jamUrl: jamUrl),
    );
  }
}

Future<void> attachQaIssueZipToNotionPage({
  required NotionClient notion,
  required String issuePageId,
  required String fileUploadId,
}) async {
  await notionAppendFileUploadBlock(
    notion,
    pageId: issuePageId,
    fileUploadId: fileUploadId,
  );
}

Future<BugSessionEnvironment> _environment(BugSessionKit kit) async {
  await kit.config.refreshEnvironment?.call();
  final env = kit.config.environmentBuilder?.call();
  if (env == null) {
    throw StateError('BugSession environment is not configured');
  }
  return env;
}
