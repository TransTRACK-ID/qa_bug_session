import 'dart:convert';

import 'ready_to_test_connection.dart';
import '../jam/jam_dev_connection.dart';

/// Parsed credentials from a single JSON blob (flat or nested `notion` / `jam`).
class ReadyToTestConnectionImport {
  const ReadyToTestConnectionImport({
    this.notionToken,
    this.dataSourceId,
    this.qaUserId,
    this.productDomain,
    this.statusEquals,
    this.statusPropertyName,
    this.productPropertyName,
    this.qaPropertyName,
    this.jamPersonalAccessToken,
    this.jamTeamId,
  });

  final String? notionToken;
  final String? dataSourceId;
  final String? qaUserId;
  final String? productDomain;
  final String? statusEquals;
  final String? statusPropertyName;
  final String? productPropertyName;
  final String? qaPropertyName;
  final String? jamPersonalAccessToken;
  final String? jamTeamId;

  bool get hasAnyField =>
      [notionToken, dataSourceId, qaUserId, productDomain, jamPersonalAccessToken, jamTeamId]
          .any((v) => v != null && v.trim().isNotEmpty);

  ReadyToTestConnection mergeNotion(
    ReadyToTestSetupDefaults defaults, {
    required String token,
    required String dataSourceId,
    required String qaUserId,
    String? productDomain,
  }) {
    return ReadyToTestConnection(
      token: token,
      dataSourceId: dataSourceId,
      qaUserId: qaUserId,
      productDomain: productDomain,
      statusEquals: statusEquals ?? defaults.statusEquals,
      statusPropertyName: statusPropertyName ?? defaults.statusPropertyName,
      productPropertyName: productPropertyName ?? defaults.productPropertyName,
      qaPropertyName: qaPropertyName ?? defaults.qaPropertyName,
    );
  }

  JamDevConnection? jamConnection() {
    final pat = jamPersonalAccessToken?.trim() ?? '';
    final team = jamTeamId?.trim() ?? '';
    if (pat.isEmpty && team.isEmpty) {
      return null;
    }
    return JamDevConnection(
      personalAccessToken: pat,
      teamId: team,
    );
  }
}

class ReadyToTestConnectionImportException implements Exception {
  ReadyToTestConnectionImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Example shape QA can paste (keys are flexible; see parser).
const readyToTestConnectionImportExampleJson = '''
{
  "notion_token": "ntn_…",
  "data_source_id": "c2046e5d-68c6-440d-83b3-4fdb2c1cefb6",
  "qa_user_id": "223d872b-594c-8189-b6f5-000289706377",
  "product_domain": "Product A",
  "jam_personal_access_token": "jam_pat_…",
  "jam_team_id": "240214cc-9ec4-4aa6-a9a5-c2cd34b7e272"
}
''';

ReadyToTestConnectionImport parseReadyToTestConnectionImport(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw ReadyToTestConnectionImportException('Paste a JSON object first.');
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (e) {
    throw ReadyToTestConnectionImportException('Invalid JSON: ${e.message}');
  }

  if (decoded is! Map) {
    throw ReadyToTestConnectionImportException(
      'JSON must be an object, not ${decoded.runtimeType}.',
    );
  }

  final root = _stringKeyMap(decoded);
  final notion = _nestedMap(root, ['notion', 'notion_api', 'notionApi']);
  final jam = _nestedMap(root, ['jam', 'jam_dev', 'jamDev']);

  final token = _firstString([root, notion], [
    'notion_token',
    'notionToken',
    'integration_token',
    'integrationToken',
    'token',
    'ntn_token',
  ]);

  final dataSourceId = _firstString([
    root,
    notion,
  ], [
    'data_source_id',
    'dataSourceId',
    'data_source',
    'dataSource',
    'datasource_id',
  ]);

  final qaUserId = _firstString([
    root,
    notion,
  ], [
    'qa_user_id',
    'qaUserId',
    'user_id',
    'userId',
    'notion_user_id',
    'notionUserId',
    'qa_id',
  ]);

  final productDomain = _firstString([
    root,
    notion,
  ], [
    'product_domain',
    'productDomain',
    'product',
    'product_filter',
  ]);

  final statusEquals = _firstString([root, notion], [
    'status_equals',
    'statusEquals',
    'ready_status',
    'notion_ready_status',
  ]);

  final statusPropertyName = _firstString([root, notion], [
    'status_property_name',
    'statusPropertyName',
    'notion_status_property',
  ]);

  final productPropertyName = _firstString([root, notion], [
    'product_property_name',
    'productPropertyName',
    'notion_product_property',
  ]);

  final qaPropertyName = _firstString([root, notion], [
    'qa_property_name',
    'qaPropertyName',
    'notion_qa_property',
  ]);

  final jamPat = _firstString([
    root,
    jam,
  ], [
    'jam_personal_access_token',
    'jamPersonalAccessToken',
    'jam_token',
    'jamToken',
    'jam_pat',
    'jamPat',
    'personal_access_token',
    'personalAccessToken',
    'pat',
  ]);

  final jamTeam = _firstString([
    root,
    jam,
  ], [
    'jam_team_id',
    'jamTeamId',
    'team_id',
    'teamId',
    'group_jam',
    'groupJam',
    'jam_group_id',
    'jamGroupId',
  ]);

  final result = ReadyToTestConnectionImport(
    notionToken: token,
    dataSourceId: dataSourceId,
    qaUserId: qaUserId,
    productDomain: productDomain,
    statusEquals: statusEquals,
    statusPropertyName: statusPropertyName,
    productPropertyName: productPropertyName,
    qaPropertyName: qaPropertyName,
    jamPersonalAccessToken: jamPat,
    jamTeamId: jamTeam,
  );

  if (!result.hasAnyField) {
    throw ReadyToTestConnectionImportException(
      'No recognized keys. Use notion_token, data_source_id, qa_user_id, '
      'jam_personal_access_token, jam_team_id (or nested notion / jam objects).',
    );
  }

  return result;
}

Map<String, dynamic>? _nestedMap(
  Map<String, dynamic> root,
  List<String> keys,
) {
  for (final key in keys) {
    final value = root[key];
    if (value is Map) {
      return _stringKeyMap(value);
    }
  }
  return null;
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

String? _firstString(List<Map<String, dynamic>?> maps, List<String> keys) {
  for (final map in maps) {
    if (map == null) continue;
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}
