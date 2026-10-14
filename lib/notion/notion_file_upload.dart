import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'notion_api.dart';

/// Notion direct upload limit for single-part uploads.
const notionSmallFileUploadMaxBytes = 20 * 1024 * 1024;

/// Uploads [bytes] via Notion File Upload API and returns the `file_upload` id.
Future<String> notionUploadSmallFile(
  NotionClient client, {
  required Uint8List bytes,
  required String filename,
  String contentType = 'application/zip',
  void Function(double progress)? onUploadProgress,
}) async {
  if (bytes.isEmpty) {
    throw NotionApiException(
      code: 'empty_file',
      message: 'Cannot upload empty file',
    );
  }
  if (bytes.length > notionSmallFileUploadMaxBytes) {
    throw NotionApiException(
      code: 'file_too_large',
      message:
          'File exceeds Notion ${notionSmallFileUploadMaxBytes ~/ (1024 * 1024)} MB limit',
    );
  }

  final created = await client.request(
    'POST',
    '/file_uploads',
    body: {
      'filename': filename,
      'content_type': contentType,
    },
  );

  final uploadId = created['id']?.toString() ?? '';
  if (uploadId.isEmpty) {
    throw NotionApiException(
      code: 'file_upload',
      message: 'Notion file upload create returned no id',
    );
  }

  final sendPath = created['upload_url']?.toString();
  final sendUrl = sendPath != null && sendPath.startsWith('http')
      ? sendPath
      : '${client.config.baseUrl}/file_uploads/$uploadId/send';

  final dio = Dio();
  final form = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      bytes,
      filename: filename,
    ),
  });

  final response = await dio.post<Map<String, dynamic>>(
    sendUrl,
    data: form,
    options: Options(
      headers: {
        'Authorization': 'Bearer ${client.config.token}',
        'Notion-Version': client.config.apiVersion,
      },
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
    onSendProgress: onUploadProgress == null
        ? null
        : (sent, total) {
            if (total <= 0) {
              return;
            }
            onUploadProgress((sent / total).clamp(0.0, 1.0));
          },
  );

  final status = response.data?['status']?.toString();
  if (status != 'uploaded') {
    throw NotionApiException(
      code: 'file_upload',
      message: 'Notion file upload did not reach uploaded status',
    );
  }

  return uploadId;
}

Future<void> notionAppendFileUploadBlock(
  NotionClient client, {
  required String pageId,
  required String fileUploadId,
  String caption = 'BugSession replay — import in app',
}) async {
  await client.appendBlockChildren(
    blockId: pageId,
    children: [
      {
        'object': 'block',
        'type': 'file',
        'file': {
          'type': 'file_upload',
          'file_upload': {'id': fileUploadId},
          'caption': [
            {
              'type': 'text',
              'text': {'content': caption},
            },
          ],
        },
      },
    ],
  );
}
