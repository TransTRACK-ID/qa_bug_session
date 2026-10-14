import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/notion/notion_issue_service.dart';
import 'package:qa_bug_session/notion/notion_schema_helpers.dart';

void main() {
  test('matchSelectOption ignores spacing and case', () {
    final match = matchSelectOption(
      [
        {'id': 'abc', 'name': 'Archived'},
      ],
      'archived',
    );
    expect(match?['id'], 'abc');
  });

  test('mobilePrefixedIssueTitle adds prefix once', () {
    expect(mobilePrefixedIssueTitle('Login fails'), '[Mobile] Login fails');
    expect(
      mobilePrefixedIssueTitle('[Mobile] Login fails'),
      '[Mobile] Login fails',
    );
  });

  test('sorts todo order conceptually via normalize', () {
    expect(
      normalizeNotionKey('Parent task'),
      normalizeNotionKey('parenttask'),
    );
  });

  test('peoplePropertyForCreateFromParent keeps users and groups', () {
    expect(
      peoplePropertyForCreateFromParent({
        'people': [
          {'object': 'user', 'id': 'user-1'},
          {'object': 'group', 'id': 'group-1'},
        ],
      }),
      {
        'people': [
          {'id': 'user-1'},
          {'object': 'group', 'id': 'group-1'},
        ],
      },
    );
    expect(
      peoplePropertyForCreateFromParent({
        'people': [
          {'object': 'user', 'id': 'user-1'},
        ],
      }),
      {
        'people': [
          {'id': 'user-1'},
        ],
      },
    );
  });

  test('peoplePropertyForCreateFromParent keeps multiple groups', () {
    expect(
      peoplePropertyForCreateFromParent({
        'people': [
          {'object': 'group', 'id': 'group-a'},
          {'object': 'group', 'id': 'group-b'},
        ],
      }),
      {
        'people': [
          {'object': 'group', 'id': 'group-a'},
          {'object': 'group', 'id': 'group-b'},
        ],
      },
    );
  });
}
