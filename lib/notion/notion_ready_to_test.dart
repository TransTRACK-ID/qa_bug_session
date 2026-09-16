// Ready to Test queue: filtered list, read-only detail, to-do checkbox updates.

import 'notion_api.dart';

/// Filter and property names for the QA "Ready to Test" Notion view.
class ReadyToTestConfig {
  const ReadyToTestConfig({
    required this.qaUserId,
    this.statusEquals = 'Ready to Test',
    this.productDomain,
    this.statusPropertyName = 'Status',
    this.productPropertyName = 'Product domain',
    this.qaPropertyName = 'QA',
  });

  /// Notion people-property user id for the assigned QA.
  final String qaUserId;

  final String statusEquals;
  final String? productDomain;
  final String statusPropertyName;
  final String productPropertyName;
  final String qaPropertyName;
}

class ReadyToTestTask {
  const ReadyToTestTask({
    required this.pageId,
    required this.title,
    required this.status,
    this.productDomain,
  });

  final String pageId;
  final String title;
  final String status;
  final String? productDomain;
}

/// A block in task body; only [NotionTodoBlock] is mutable via API.
sealed class NotionBodyBlock {
  const NotionBodyBlock();
}

class NotionParagraphBlock extends NotionBodyBlock {
  const NotionParagraphBlock({required this.text});

  final String text;
}

class NotionHeadingBlock extends NotionBodyBlock {
  const NotionHeadingBlock({required this.level, required this.text});

  final int level;
  final String text;
}

class NotionBulletedBlock extends NotionBodyBlock {
  const NotionBulletedBlock({required this.text});

  final String text;
}

class NotionTodoBlock extends NotionBodyBlock {
  const NotionTodoBlock({
    required this.blockId,
    required this.text,
    required this.checked,
  });

  final String blockId;
  final String text;
  final bool checked;
}

class ReadyToTestTaskDetail {
  const ReadyToTestTaskDetail({
    required this.task,
    required this.bodyBlocks,
  });

  final ReadyToTestTask task;
  final List<NotionBodyBlock> bodyBlocks;

  List<NotionTodoBlock> get todos =>
      bodyBlocks.whereType<NotionTodoBlock>().toList();
}

class _StatusPropertyInfo {
  _StatusPropertyInfo({required this.name, required this.type});

  final String name;
  final String type;
}

/// High-level operations for the Ready to Test workflow.
class ReadyToTestService {
  ReadyToTestService(this._client);

  final NotionClient _client;

  Future<List<ReadyToTestTask>> listTasks(ReadyToTestConfig config) async {
    final schema = await _client.getDataSourceSchema();
    final titleProp = _findTitlePropertyName(schema);
    final statusInfo = _resolveStatusProperty(schema, config.statusPropertyName);

    final andFilters = <Map<String, dynamic>>[
      _statusFilter(statusInfo.name, statusInfo.type, config.statusEquals),
      {
        'property': config.qaPropertyName,
        'people': {'contains': config.qaUserId},
      },
    ];

    if (config.productDomain != null && config.productDomain!.isNotEmpty) {
      andFilters.add(
        _productFilter(config.productPropertyName, config.productDomain!),
      );
    }

    final filter = andFilters.length == 1
        ? andFilters.single
        : {'and': andFilters};

    final pages = await _client.queryDataSource(filter: filter);

    return pages.map((page) {
      final props = page['properties'] as Map<String, dynamic>? ?? {};
      return ReadyToTestTask(
        pageId: page['id']?.toString() ?? '',
        title: _readTitle(props, titleProp),
        status: _readStatus(props, statusInfo.name, statusInfo.type),
        productDomain: _readSelectName(props, config.productPropertyName),
      );
    }).toList();
  }

  Future<ReadyToTestTaskDetail> loadTaskDetail(
    String pageId, {
    ReadyToTestConfig? configForMeta,
  }) async {
    final resolvedId = extractNotionPageId(pageId) ?? pageId;
    final schema = await _client.getDataSourceSchema();
    final titleProp = _findTitlePropertyName(schema);

    final page = await _client.getPage(resolvedId);
    final props = page['properties'] as Map<String, dynamic>? ?? {};

    final cfg = configForMeta ?? const ReadyToTestConfig(qaUserId: '');
    final statusInfo = _resolveStatusProperty(schema, cfg.statusPropertyName);

    final task = ReadyToTestTask(
      pageId: resolvedId,
      title: _readTitle(props, titleProp),
      status: _readStatus(props, statusInfo.name, statusInfo.type),
      productDomain: _readSelectName(props, cfg.productPropertyName),
    );

    final bodyBlocks = await _loadBlocksRecursive(resolvedId);

    return ReadyToTestTaskDetail(task: task, bodyBlocks: bodyBlocks);
  }

  /// Applies checkbox changes only; keys are Notion block ids.
  Future<void> submitTodoChanges(Map<String, bool> blockIdToChecked) async {
    for (final entry in blockIdToChecked.entries) {
      await _client.updateTodoChecked(entry.key, entry.value);
    }
  }

  Future<List<NotionBodyBlock>> _loadBlocksRecursive(String blockId) async {
    final children = await _client.listBlockChildren(blockId);
    final blocks = <NotionBodyBlock>[];

    for (final child in children) {
      blocks.addAll(await _mapBlock(child));
    }

    return blocks;
  }

  Future<List<NotionBodyBlock>> _mapBlock(Map<String, dynamic> block) async {
    final type = block['type']?.toString() ?? '';
    final id = block['id']?.toString() ?? '';
    final hasChildren = block['has_children'] == true;

    final mapped = <NotionBodyBlock>[];

    switch (type) {
      case 'paragraph':
        mapped.add(
          NotionParagraphBlock(
            text: plainTextFromRichText(
              (block['paragraph'] as Map?)?['rich_text'] as List?,
            ),
          ),
        );
      case 'heading_1':
        mapped.add(
          NotionHeadingBlock(
            level: 1,
            text: plainTextFromRichText(
              (block['heading_1'] as Map?)?['rich_text'] as List?,
            ),
          ),
        );
      case 'heading_2':
        mapped.add(
          NotionHeadingBlock(
            level: 2,
            text: plainTextFromRichText(
              (block['heading_2'] as Map?)?['rich_text'] as List?,
            ),
          ),
        );
      case 'heading_3':
        mapped.add(
          NotionHeadingBlock(
            level: 3,
            text: plainTextFromRichText(
              (block['heading_3'] as Map?)?['rich_text'] as List?,
            ),
          ),
        );
      case 'bulleted_list_item':
        mapped.add(
          NotionBulletedBlock(
            text: plainTextFromRichText(
              (block['bulleted_list_item'] as Map?)?['rich_text'] as List?,
            ),
          ),
        );
      case 'to_do':
        final todo = block['to_do'] as Map<String, dynamic>? ?? {};
        mapped.add(
          NotionTodoBlock(
            blockId: id,
            text: plainTextFromRichText(todo['rich_text'] as List?),
            checked: todo['checked'] == true,
          ),
        );
      default:
        break;
    }

    if (hasChildren && type != 'child_page' && type != 'child_database') {
      mapped.addAll(await _loadBlocksRecursive(id));
    }

    return mapped;
  }

  static String _findTitlePropertyName(Map<String, dynamic> schema) {
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    for (final entry in properties.entries) {
      final type = (entry.value as Map?)?['type'];
      if (type == 'title') return entry.key;
    }
    throw NotionApiException(
      code: 'schema',
      message: 'No title property found on data source',
    );
  }

  static _StatusPropertyInfo _resolveStatusProperty(
    Map<String, dynamic> schema,
    String preferredName,
  ) {
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};

    if (properties.containsKey(preferredName)) {
      final type = properties[preferredName]['type']?.toString();
      if (type == 'status' || type == 'select') {
        return _StatusPropertyInfo(name: preferredName, type: type!);
      }
    }

    for (final entry in properties.entries) {
      if ((entry.value as Map?)?['type'] == 'status') {
        return _StatusPropertyInfo(name: entry.key, type: 'status');
      }
    }

    for (final entry in properties.entries) {
      if ((entry.value as Map?)?['type'] == 'select' &&
          entry.key.toLowerCase() == 'status') {
        return _StatusPropertyInfo(name: entry.key, type: 'select');
      }
    }

    throw NotionApiException(
      code: 'schema',
      message: 'No status or select Status property found',
    );
  }

  static Map<String, dynamic> _statusFilter(
    String propertyName,
    String propertyType,
    String statusName,
  ) {
    return {
      'property': propertyName,
      propertyType: {'equals': statusName},
    };
  }

  static Map<String, dynamic> _productFilter(
    String propertyName,
    String productName,
  ) {
    return {
      'property': propertyName,
      'select': {'equals': productName},
    };
  }

  static String _readTitle(Map<String, dynamic> props, String titleProp) {
    final titleData = props[titleProp]?['title'] as List?;
    return plainTextFromRichText(titleData);
  }

  static String _readStatus(
    Map<String, dynamic> props,
    String statusProp,
    String type,
  ) {
    final value = props[statusProp]?[type] as Map?;
    return value?['name']?.toString() ?? '';
  }

  static String? _readSelectName(Map<String, dynamic> props, String propName) {
    final value = props[propName]?['select'] as Map?;
    return value?['name']?.toString();
  }
}

/// Status updates (same behaviour as the `nts` CLI status command).
class NotionTaskStatusService {
  NotionTaskStatusService(this._client);

  final NotionClient _client;

  Future<void> updateStatus({
    required String pageId,
    required String newStatus,
    String? statusPropertyOverride,
  }) async {
    final resolvedId = extractNotionPageId(pageId) ?? pageId;
    final schema = await _client.getDataSourceSchema();
    final info = ReadyToTestService._resolveStatusProperty(
      schema,
      statusPropertyOverride ?? 'Status',
    );

    final options = _statusOptions(schema, info.name, info.type);
    Map<String, String>? match;
    for (final option in options) {
      if (_normalizeStatus(option['name']!) ==
          _normalizeStatus(newStatus)) {
        match = option;
        break;
      }
    }

    if (match == null) {
      throw NotionApiException(
        code: 'unknown_status',
        message: 'Unknown status: $newStatus',
      );
    }

    await _client.updatePageSelectOrStatus(
      pageId: resolvedId,
      propertyName: info.name,
      propertyType: info.type,
      optionId: match['id']!,
    );
  }

  static List<Map<String, String>> _statusOptions(
    Map<String, dynamic> schema,
    String name,
    String type,
  ) {
    final prop = schema['properties'][name][type] as Map?;
    final options = prop?['options'] as List? ?? [];
    return [
      for (final opt in options)
        if (opt is Map)
          {
            'id': opt['id']?.toString() ?? '',
            'name': opt['name']?.toString() ?? '',
          },
    ];
  }

  static String _normalizeStatus(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}
