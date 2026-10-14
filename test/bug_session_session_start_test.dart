import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

void main() {
  test('bugSessionParseSessionStartActiveTab reads optional field', () {
    final payload = jsonEncode({
      'name': 'NavbarRoute',
      'label': 'session_start',
      'activeTab': 'HistoryRoute',
    });
    expect(bugSessionParseSessionStartActiveTab(payload), 'HistoryRoute');
    expect(
      bugSessionParseSessionStartActiveTab(
        jsonEncode({'name': 'NavbarRoute', 'label': 'session_start'}),
      ),
      isNull,
    );
  });
}
