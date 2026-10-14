import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/notion/ready_to_test_connection_import.dart';

void main() {
  test('parses flat JSON with snake_case keys', () {
    final parsed = parseReadyToTestConnectionImport('''
{
  "notion_token": "ntn_abc",
  "data_source_id": "ds-1",
  "qa_user_id": "user-1",
  "jam_personal_access_token": "jam_pat_xyz",
  "jam_team_id": "team-1",
  "product_domain": "Mobile"
}
''');
    expect(parsed.notionToken, 'ntn_abc');
    expect(parsed.dataSourceId, 'ds-1');
    expect(parsed.qaUserId, 'user-1');
    expect(parsed.jamPersonalAccessToken, 'jam_pat_xyz');
    expect(parsed.jamTeamId, 'team-1');
    expect(parsed.productDomain, 'Mobile');
  });

  test('parses nested notion and jam objects', () {
    final parsed = parseReadyToTestConnectionImport('''
{
  "notion": {
    "token": "ntn_nested",
    "data_source_id": "ds-2",
    "user_id": "qa-2"
  },
  "jam": {
    "jam_pat": "pat_nested",
    "group_jam": "group-2"
  }
}
''');
    expect(parsed.notionToken, 'ntn_nested');
    expect(parsed.dataSourceId, 'ds-2');
    expect(parsed.qaUserId, 'qa-2');
    expect(parsed.jamPersonalAccessToken, 'pat_nested');
    expect(parsed.jamTeamId, 'group-2');
  });

  test('rejects empty object', () {
    expect(
      () => parseReadyToTestConnectionImport('{}'),
      throwsA(isA<ReadyToTestConnectionImportException>()),
    );
  });
}
