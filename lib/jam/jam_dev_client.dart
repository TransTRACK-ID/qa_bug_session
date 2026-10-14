import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class JamDevException implements Exception {
  JamDevException(this.message);

  final String message;

  @override
  String toString() => 'JamDevException: $message';
}

class JamUploadResult {
  const JamUploadResult({
    required this.jamId,
    required this.shareUrl,
  });

  final String jamId;
  final String shareUrl;
}

/// Jam.dev video upload via GraphQL (same flow as the official CLI).
class JamDevClient {
  JamDevClient({
    required this.personalAccessToken,
    required this.teamId,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                headers: {
                  'Authorization': 'Bearer $personalAccessToken',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final String personalAccessToken;
  final String teamId;
  final Dio _dio;

  static const _graphqlUrl = 'https://graphql.jam.dev/graphql';

  Future<JamUploadResult> uploadVideo({
    required Uint8List mp4Bytes,
    required String title,
    String url = '',
    int width = 1080,
    int height = 1920,
    void Function(double progress)? onProgress,
  }) async {
    void report(double value) => onProgress?.call(value.clamp(0.0, 1.0));
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/qa_bug_session_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await file.writeAsBytes(mp4Bytes, flush: true);

    try {
      final videoKey = 'video-${DateTime.now().millisecondsSinceEpoch}';
      final posterKey = 'poster-${DateTime.now().millisecondsSinceEpoch}';
      final posterBytes = await _firstFrameJpegPlaceholder();

      report(0.02);
      final registration = await _graphql(
        '''
mutation bulkRegisterMedia(\$teamId: String!, \$items: [MediaRegistrationItemInput!]!) {
  bulkRegisterMedia(teamId: \$teamId, items: \$items) {
    items {
      key
      uploadUrl
      extraHeaders { name value }
      media { id }
    }
  }
}
''',
        {
          'teamId': teamId,
          'items': [
            {
              'key': videoKey,
              'type': 'Video',
              'contentType': 'video/mp4',
              'uncompressedBytes': mp4Bytes.length,
            },
            {
              'key': posterKey,
              'type': 'Screenshot',
              'contentType': 'image/jpeg',
              'uncompressedBytes': posterBytes.length,
            },
          ],
        },
      );

      final items =
          registration['data']?['bulkRegisterMedia']?['items'] as List? ?? [];
      if (items.length < 2) {
        throw JamDevException('Jam media registration failed');
      }

      final videoItem = items[0] as Map<String, dynamic>;
      final posterItem = items[1] as Map<String, dynamic>;

      report(0.05);
      await _putMedia(
        uploadUrl: videoItem['uploadUrl']?.toString() ?? '',
        headers: _extraHeaders(videoItem),
        bytes: mp4Bytes,
        contentType: 'video/mp4',
        onBytesProgress: (p) => report(0.05 + 0.70 * p),
      );

      report(0.75);
      await _putMedia(
        uploadUrl: posterItem['uploadUrl']?.toString() ?? '',
        headers: _extraHeaders(posterItem),
        bytes: posterBytes,
        contentType: 'image/jpeg',
        onBytesProgress: (p) => report(0.75 + 0.05 * p),
      );

      final videoMediaId = videoItem['media']?['id']?.toString() ?? '';
      final posterMediaId = posterItem['media']?['id']?.toString() ?? '';

      final pageUrl = url.trim().isEmpty ? 'about:blank' : url.trim();
      final durationMs = _estimateDurationMs(mp4Bytes.length);

      report(0.80);
      final createResult = await _graphql(
        '''
mutation createVideo(\$jam: CreateVideoInput!, \$comment: BasicCommentInput!) {
  createVideo(jam: \$jam, comment: \$comment) {
    ... on BaseJam { id }
  }
}
''',
        {
          'jam': {
            'teamId': teamId,
            'url': pageUrl,
            'title': title,
            'clientInfo': {
              'browser': {'name': 'QA Bug Session', 'version': '1.4.0'},
              'os': {
                'name': Platform.operatingSystem,
                'version': Platform.operatingSystemVersion,
              },
              'screenDimensions': {'width': width, 'height': height},
              'jamClient': {'version': '1.4.0'},
              'other': <Map<String, dynamic>>[],
            },
            'data': {
              'mediaId': videoMediaId,
              'posterImageMediaId': posterMediaId,
              'durationMs': durationMs,
              'width': width,
              'height': height,
              'viewport': 'tab',
              'recordingSurface': 'screen',
              'micEnabled': false,
            },
          },
          'comment': {'message': '', 'attachments': <Map<String, dynamic>>[]},
        },
      );

      final jamNode = createResult['data']?['createVideo'] as Map?;
      final jamId = jamNode?['id']?.toString() ?? '';
      if (jamId.isEmpty) {
        throw JamDevException('Jam createVideo returned no id');
      }

      report(1);
      return JamUploadResult(
        jamId: jamId,
        shareUrl: 'https://jam.dev/c/$jamId',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final detail = body is Map
          ? body['message']?.toString() ?? body.toString()
          : body?.toString();
      final message = status != null
          ? 'Jam upload failed (HTTP $status): ${detail ?? e.message}'
          : (e.message ?? 'Jam upload failed');
      developer.log(message, name: 'JamDev', level: 1000, error: e);
      throw JamDevException(message);
    } finally {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } on Object {
          // ignore cleanup errors
        }
      }
    }
  }

  Future<Map<String, dynamic>> _graphql(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _graphqlUrl,
      data: {'query': query, 'variables': variables},
    );
    final data = response.data;
    if (data == null) {
      throw JamDevException('Empty GraphQL response');
    }
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map
          ? first['message']?.toString()
          : first.toString();
      final resolved = message ?? 'GraphQL error';
      developer.log(resolved, name: 'JamDev', level: 1000);
      throw JamDevException(resolved);
    }
    return data;
  }

  Map<String, String> _extraHeaders(Map<String, dynamic> item) {
    final headers = <String, String>{};
    final extra = item['extraHeaders'] as List? ?? [];
    for (final header in extra) {
      if (header is Map) {
        final name = header['name']?.toString();
        final value = header['value']?.toString();
        if (name != null && value != null) {
          headers[name] = value;
        }
      }
    }
    return headers;
  }

  Future<void> _putMedia({
    required String uploadUrl,
    required Map<String, String> headers,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onBytesProgress,
  }) async {
    if (uploadUrl.isEmpty) {
      throw JamDevException('Missing Jam upload URL');
    }
    final dio = Dio();
    try {
      await dio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
            ...headers,
          },
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
        onSendProgress: onBytesProgress == null
            ? null
            : (sent, total) {
                if (total <= 0) {
                  return;
                }
                onBytesProgress(sent / total);
              },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw JamDevException(
        status != null
            ? 'Jam media PUT failed (HTTP $status)'
            : 'Jam media PUT failed',
      );
    }
  }

  int _estimateDurationMs(int byteLength) {
    return (byteLength / 250000).clamp(1000, 600000).round();
  }

  /// Minimal JPEG placeholder when ffmpeg is unavailable on device.
  Future<Uint8List> _firstFrameJpegPlaceholder() async {
    return Uint8List.fromList(base64Decode(_minimalJpegBase64));
  }
}

const _minimalJpegBase64 =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQBAQAAAAAAAAAAAAAAAAAAAAD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGfAP/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQMBAT8Cf//EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQIBAT8Cf//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEABj8Cf//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEABj8Cf//Z';
