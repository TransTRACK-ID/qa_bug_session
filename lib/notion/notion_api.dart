// Low-level Notion REST helpers (API version 2025-09-03 data sources).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

/// Credentials and defaults for Notion API calls.
class NotionApiConfig {
  const NotionApiConfig({
    required this.token,
    required this.dataSourceId,
    this.apiVersion = '2025-09-03',
    this.baseUrl = 'https://api.notion.com/v1',
  });

  final String token;
  final String dataSourceId;
  final String apiVersion;
  final String baseUrl;
}

/// Thrown when Notion returns `{object: "error", ...}`.
class NotionApiException implements Exception {
  NotionApiException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'NotionApiException($code): $message';
}

/// HTTP transport for [NotionClient]. Override in tests.
typedef NotionTransport = Future<Map<String, dynamic>> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
});

/// Minimal Notion client: auth, data-source query, pages, blocks.
class NotionClient {
  NotionClient(
    this.config, {
    this._dio,
    @visibleForTesting this._transport,
  });

  final NotionApiConfig config;
  final Dio? _dio;
  final NotionTransport? _transport;

  Dio get _client {
    final configured = _dio;
    if (configured != null) return configured;
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        headers: {
          'Authorization': 'Bearer ${config.token}',
          'Notion-Version': config.apiVersion,
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return dio;
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final transport = _transport;
    if (transport != null) {
      return transport(method, path, body: body);
    }

    final response = await _client.request<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(method: method),
    );

    final data = response.data;
    if (data == null) {
      throw NotionApiException(
        code: 'empty_response',
        message: 'Empty response from Notion ($method $path)',
      );
    }

    if (data['object'] == 'error') {
      throw NotionApiException(
        code: data['code']?.toString() ?? 'unknown',
        message: data['message']?.toString() ?? 'Unknown Notion API error',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> getDataSourceSchema() {
    return request('GET', '/data_sources/${config.dataSourceId}');
  }

  Future<Map<String, dynamic>> getUsersMe() {
    return request('GET', '/users/me');
  }

  Future<Map<String, dynamic>> getPage(String pageId) {
    return request('GET', '/pages/$pageId');
  }

  Future<List<Map<String, dynamic>>> queryDataSource({
    Map<String, dynamic>? filter,
    Map<String, dynamic>? sorts,
  }) async {
    final body = <String, dynamic>{};
    if (filter != null) body['filter'] = filter;
    if (sorts != null) body['sorts'] = sorts;

    final results = <Map<String, dynamic>>[];
    String? cursor;

    while (true) {
      final pageBody = Map<String, dynamic>.from(body);
      if (cursor != null) pageBody['start_cursor'] = cursor;

      final response = await request(
        'POST',
        '/data_sources/${config.dataSourceId}/query',
        body: pageBody.isEmpty ? null : pageBody,
      );

      final pageResults = response['results'];
      if (pageResults is List) {
        for (final item in pageResults) {
          if (item is Map<String, dynamic>) results.add(item);
        }
      }

      final hasMore = response['has_more'] == true;
      cursor = response['next_cursor']?.toString();
      if (!hasMore || cursor == null || cursor.isEmpty) break;
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> listBlockChildren(String blockId) async {
    final results = <Map<String, dynamic>>[];
    String? cursor;

    while (true) {
      final path = cursor == null
          ? '/blocks/$blockId/children?page_size=100'
          : '/blocks/$blockId/children?page_size=100&start_cursor=$cursor';

      final response = await request('GET', path);
      final pageResults = response['results'];
      if (pageResults is List) {
        for (final item in pageResults) {
          if (item is Map<String, dynamic>) results.add(item);
        }
      }

      final hasMore = response['has_more'] == true;
      cursor = response['next_cursor']?.toString();
      if (!hasMore || cursor == null || cursor.isEmpty) break;
    }

    return results;
  }

  Future<void> updateTodoChecked(String blockId, bool checked) async {
    await request(
      'PATCH',
      '/blocks/$blockId',
      body: {
        'to_do': {'checked': checked},
      },
    );
  }

  Future<void> updatePageSelectOrStatus({
    required String pageId,
    required String propertyName,
    required String propertyType,
    required String optionId,
  }) async {
    await request(
      'PATCH',
      '/pages/$pageId',
      body: {
        'properties': {
          propertyName: {
            propertyType: {'id': optionId},
          },
        },
      },
    );
  }
}

/// Extracts a dashed UUID from a bare id, dashed UUID, or Notion URL slug.
String? extractNotionPageId(String input) {
  var pathPart = input.split('#').first.split('?').first;
  if (pathPart.endsWith('/')) {
    pathPart = pathPart.substring(0, pathPart.length - 1);
  }
  final lastSegment = pathPart.contains('/')
      ? pathPart.substring(pathPart.lastIndexOf('/') + 1)
      : pathPart;

  String? hex;
  final candidate = lastSegment.replaceAll('-', '');
  if (RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(candidate)) {
    hex = candidate.toLowerCase();
  } else {
    final lastToken = lastSegment.contains('-')
        ? lastSegment.substring(lastSegment.lastIndexOf('-') + 1)
        : lastSegment;
    if (RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(lastToken)) {
      hex = lastToken.toLowerCase();
    }
  }

  if (hex == null) return null;

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

String plainTextFromRichText(List<dynamic>? richText) {
  if (richText == null || richText.isEmpty) return '';
  final buffer = StringBuffer();
  for (final segment in richText) {
    if (segment is Map && segment['plain_text'] != null) {
      buffer.write(segment['plain_text']);
    }
  }
  return buffer.toString();
}

String encodePrettyJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}
