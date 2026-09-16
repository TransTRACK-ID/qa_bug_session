import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/notion/notion.dart';

void main() {
  group('extractNotionPageId', () {
    test('parses dashed uuid', () {
      expect(
        extractNotionPageId('992ccba5-c5ad-831f-94a9-81194f60ec80'),
        '992ccba5-c5ad-831f-94a9-81194f60ec80',
      );
    });

    test('parses notion url slug', () {
      expect(
        extractNotionPageId(
          'https://www.notion.so/transtrack/My-Task-992ccba5c5ad831f94a981194f60ec80',
        ),
        '992ccba5-c5ad-831f-94a9-81194f60ec80',
      );
    });
  });

  group('ReadyToTestService', () {
    test('listTasks applies status, QA, and product filters', () async {
      final transport = _RecordingTransport({
        'GET /data_sources/ds-1': _schema(),
        'POST /data_sources/ds-1/query': {
          'object': 'list',
          'results': [
            {
              'id': 'page-1',
              'properties': {
                'Name': {
                  'title': [
                    {'plain_text': 'Login fix'},
                  ],
                },
                'Status': {
                  'status': {'name': 'Ready to Test'},
                },
                'Product domain': {
                  'select': {'name': 'Product A'},
                },
              },
            },
          ],
          'has_more': false,
        },
      });

      final client = NotionClient(
        const NotionApiConfig(token: 't', dataSourceId: 'ds-1'),
        transport: transport.request,
      );
      final service = ReadyToTestService(client);

      final tasks = await service.listTasks(
        const ReadyToTestConfig(
          qaUserId: 'qa-user-1',
          productDomain: 'Product A',
        ),
      );

      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'Login fix');
      expect(tasks.first.pageId, 'page-1');

      final queryBody = transport.bodies
          .singleWhere((e) => e.key.startsWith('POST'))
          .value as Map<String, dynamic>;
      final filter = queryBody['filter']! as Map<String, dynamic>;
      final and = filter['and'] as List;
      expect(and.length, 3);
      expect(and[1], {
        'property': 'QA',
        'people': {'contains': 'qa-user-1'},
      });
    });

    test('submitTodoChanges patches each block', () async {
      final transport = _RecordingTransport({});
      final client = NotionClient(
        const NotionApiConfig(token: 't', dataSourceId: 'ds-1'),
        transport: transport.request,
      );
      final service = ReadyToTestService(client);

      await service.submitTodoChanges({
        'block-a': true,
        'block-b': false,
      });

      expect(transport.bodies, hasLength(2));
      expect(transport.bodies[0].key, 'PATCH /blocks/block-a');
      expect(transport.bodies[0].value, {
        'to_do': {'checked': true},
      });
      expect(transport.bodies[1].key, 'PATCH /blocks/block-b');
      expect(transport.bodies[1].value, {
        'to_do': {'checked': false},
      });
    });

    test('loadTaskDetail maps todos from block tree', () async {
      final transport = _RecordingTransport({
        'GET /data_sources/ds-1': _schema(),
        'GET /pages/page-1': {
          'object': 'page',
          'id': 'page-1',
          'properties': {
            'Name': {
              'title': [
                {'plain_text': 'Task'},
              ],
            },
            'Status': {
              'status': {'name': 'Ready to Test'},
            },
          },
        },
        'GET /blocks/page-1/children?page_size=100': {
          'object': 'list',
          'results': [
            {
              'id': 'todo-1',
              'type': 'to_do',
              'has_children': false,
              'to_do': {
                'checked': false,
                'rich_text': [
                  {'plain_text': 'AC 1'},
                ],
              },
            },
          ],
          'has_more': false,
        },
      });

      final client = NotionClient(
        const NotionApiConfig(token: 't', dataSourceId: 'ds-1'),
        transport: transport.request,
      );
      final service = ReadyToTestService(client);

      final detail = await service.loadTaskDetail('page-1');
      expect(detail.task.title, 'Task');
      expect(detail.todos, hasLength(1));
      expect(detail.todos.first.blockId, 'todo-1');
      expect(detail.todos.first.text, 'AC 1');
      expect(detail.todos.first.checked, isFalse);
    });
  });
}

Map<String, dynamic> _schema() {
  return {
    'object': 'data_source',
    'properties': {
      'Name': {'type': 'title', 'id': 'title'},
      'Status': {
        'type': 'status',
        'status': {
          'options': [
            {'id': 's1', 'name': 'Ready to Test'},
          ],
        },
      },
      'Product domain': {'type': 'select', 'select': {'options': []}},
      'QA': {'type': 'people', 'people': {}},
    },
  };
}

class _RecordingTransport {
  _RecordingTransport(this._responses);

  final Map<String, Map<String, dynamic>> _responses;
  final bodies = <MapEntry<String, Map<String, dynamic>?>>[];

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final key = '$method $path';
    bodies.add(MapEntry(key, body));

    if (_responses.containsKey(key)) {
      return _responses[key]!;
    }

    if (method == 'PATCH' && path.startsWith('/blocks/')) {
      return {'object': 'block', 'id': path.split('/').last};
    }

    throw StateError('Unexpected request: $key');
  }
}
