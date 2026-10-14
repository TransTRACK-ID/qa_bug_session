// Create/update QA bug cards and fill template body sections.

import 'notion_api.dart';
import 'notion_ready_to_test.dart';
import 'qa_notion_status_names.dart';
import 'notion_schema_helpers.dart';
import 'qa_bug_template_config.dart';

class QaIssueFieldValues {
  const QaIssueFieldValues({
    required this.title,
    required this.module,
    required this.precondition,
    required this.stepReproduce,
    required this.expected,
    required this.actual,
    required this.screenshootSection,
  });

  final String title;
  final String module;
  final String precondition;
  final String stepReproduce;
  final String expected;
  final String actual;

  /// Jam link + BugSession zip URL / attachment note for the Screenshoot section.
  final String screenshootSection;
}

/// Ensures new bug cards are tagged as mobile QA findings in Notion.
String mobilePrefixedIssueTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return '[Mobile]';
  }
  if (trimmed.startsWith('[Mobile]')) {
    return trimmed;
  }
  return '[Mobile] $trimmed';
}

class NotionIssueService {
  NotionIssueService(
    this._client, {
    this.templateConfig = const QaBugTemplateConfig(),
  });

  final NotionClient _client;
  final QaBugTemplateConfig templateConfig;

  Future<Map<String, dynamic>> loadPage(String pageId) {
    final resolved = extractNotionPageId(pageId) ?? pageId;
    return _client.getPage(resolved);
  }

  Future<bool> isChildBugCard(String pageId) async {
    final page = await loadPage(pageId);
    final schema = await _client.getDataSourceSchema();
    final props = parseDataSourceProperties(schema);
    final parentProp = findProperty(props, normalizedName: 'parenttask') ??
        NotionPropertyDescriptor(
          name: templateConfig.parentRelationPropertyName,
          type: 'relation',
        );
    return pageHasParentRelation(page, parentProp.name);
  }

  Future<String?> readParentTaskId(String pageId) async {
    final page = await loadPage(pageId);
    final schema = await _client.getDataSourceSchema();
    final props = parseDataSourceProperties(schema);
    final parentProp = findProperty(props, normalizedName: 'parenttask');
    if (parentProp == null) {
      return null;
    }
    final parentProps = page['properties'] as Map<String, dynamic>? ?? {};
    final ids = readRelationIds(parentProps[parentProp.name] as Map?);
    return ids.isEmpty ? null : ids.first;
  }

  Future<String> createBugFromParent({
    required String parentPageId,
    required QaIssueFieldValues fields,
  }) async {
    final parentId = extractNotionPageId(parentPageId) ?? parentPageId;
    final parentPage = await _client.getPage(parentId);
    final schema = await _client.getDataSourceSchema();
    final schemaProps = parseDataSourceProperties(schema);

    final titleName = findTitlePropertyName(schemaProps);
    if (titleName == null) {
      throw NotionApiException(
        code: 'schema',
        message: 'No title property on data source',
      );
    }

    final typeProp = findProperty(schemaProps, normalizedName: 'type');
    final statusProp = findProperty(schemaProps, normalizedName: 'status');
    final parentProp = findProperty(schemaProps, normalizedName: 'parenttask');
    final estStartProp =
        findProperty(schemaProps, normalizedName: 'estimationstartnonsprint');
    final estEndProp =
        findProperty(schemaProps, normalizedName: 'estimationendnonsprint');

    final properties = copyCompatibleProperties(
      parentPage: parentPage,
      schemaProps: schemaProps,
      skipNormalizedNames: {
        'type',
        'status',
        'parenttask',
        'subtask',
        'name',
        'estimationstartnonsprint',
        'estimationendnonsprint',
      },
    );

    properties[titleName] = titleProperty(mobilePrefixedIssueTitle(fields.title));

    applyGroupOnlyPeopleFromParent(
      out: properties,
      parentPage: parentPage,
      schemaProps: schemaProps,
    );

    if (typeProp != null) {
      final typeOpt = matchSelectOption(
        selectOptions(schema, typeProp.name),
        templateConfig.bugTypeSelectName,
      );
      if (typeOpt != null) {
        properties[typeProp.name] = selectPropertyById(typeOpt['id']!);
      }
    }

    if (statusProp != null) {
      final statusOpt = matchSelectOption(
        selectOptions(schema, statusProp.name),
        templateConfig.bugStatusSelectName,
      );
      if (statusOpt != null) {
        properties[statusProp.name] = selectPropertyById(statusOpt['id']!);
      }
    }

    if (parentProp != null) {
      properties[parentProp.name] = relationProperty([parentId]);
    }

    final today = DateTime.now();
    final end = today.add(const Duration(days: 7));
    if (estStartProp != null) {
      properties[estStartProp.name] = dateProperty(today);
    }
    if (estEndProp != null) {
      properties[estEndProp.name] = dateProperty(end);
    }

    final children = await _buildIssueBodyBlocks(fields);

    final created = await _client.createPage(
      parent: {
        'type': 'data_source_id',
        'data_source_id': _client.config.dataSourceId,
      },
      properties: properties,
      children: children,
    );

    return created['id']?.toString() ?? '';
  }

  Future<void> updateExistingBugReissue({
    required String bugPageId,
    required String commentBody,
  }) async {
    final pageId = extractNotionPageId(bugPageId) ?? bugPageId;
    final schema = await _client.getDataSourceSchema();
    final schemaProps = parseDataSourceProperties(schema);
    final statusProp = findProperty(schemaProps, normalizedName: 'status');
    if (statusProp != null) {
      final statusOpt = matchSelectOption(
        selectOptions(schema, statusProp.name),
        templateConfig.bugStatusSelectName,
      );
      if (statusOpt != null) {
        await _client.updatePageProperties(
          pageId: pageId,
          properties: {
            statusProp.name: selectPropertyById(statusOpt['id']!),
          },
        );
      }
    }

    await _client.createComment(
      pageId: pageId,
      plainText: commentBody,
    );
  }

  /// When every **Issues** child of [childPageId]'s parent is [resolvedChildStatus],
  /// moves an **On Feedback** parent to [resolvedChildStatus] with a comment.
  Future<void> maybePromoteParentWhenAllIssuesResolved({
    required String childPageId,
    required String statusPropertyName,
    String resolvedChildStatus = QaNotionStatusNames.passedParent,
    String onFeedbackStatus = 'On Feedback',
  }) async {
    final parentId = await readParentTaskId(childPageId);
    if (parentId == null || parentId.isEmpty) {
      return;
    }

    final statusService = NotionTaskStatusService(_client);
    final parentStatus = await statusService.readPageStatus(
      parentId,
      statusPropertyOverride: statusPropertyName,
    );
    if (_normalizeNotionStatus(parentStatus) !=
        _normalizeNotionStatus(onFeedbackStatus)) {
      return;
    }

    final schema = await _client.getDataSourceSchema();
    final schemaProps = parseDataSourceProperties(schema);
    final parentProp = findProperty(schemaProps, normalizedName: 'parenttask');
    if (parentProp == null) {
      return;
    }

    final filters = <Map<String, dynamic>>[
      {
        'property': parentProp.name,
        'relation': {'contains': parentId},
      },
    ];
    final typeProp = findProperty(schemaProps, normalizedName: 'type');
    if (typeProp != null) {
      filters.add({
        'property': typeProp.name,
        'select': {'equals': templateConfig.bugTypeSelectName},
      });
    }

    final filter =
        filters.length == 1 ? filters.single : {'and': filters};
    final siblings = await _client.queryDataSource(filter: filter);
    if (siblings.isEmpty) {
      return;
    }

    final rcr = _normalizeNotionStatus(resolvedChildStatus);
    for (final page in siblings) {
      final id = page['id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      final status = await statusService.readPageStatus(
        id,
        statusPropertyOverride: statusPropertyName,
      );
      if (_normalizeNotionStatus(status) != rcr) {
        return;
      }
    }

    await statusService.updateStatus(
      pageId: parentId,
      newStatus: resolvedChildStatus,
      statusPropertyOverride: statusPropertyName,
    );
    await _client.createComment(
      pageId: parentId,
      plainText: 'All issue(s) were resolved ✅',
    );
  }

  static String _normalizeNotionStatus(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<List<Map<String, dynamic>>> _buildIssueBodyBlocks(
    QaIssueFieldValues fields,
  ) async {
    final templateBlocks =
        await _client.listBlockChildren(templateConfig.templatePageId);

    final sections = <String, String>{
      'module': fields.module,
      'precondition': fields.precondition,
      'stepreproduce': fields.stepReproduce,
      'expected': fields.expected,
      'actual': fields.actual,
      'screenshoot': fields.screenshootSection,
    };

    final children = <Map<String, dynamic>>[];
    String? currentSection;
    final filledSections = <String>{};

    for (final block in templateBlocks) {
      final type = block['type']?.toString() ?? '';
      if (type == 'column_list' || type == 'column') {
        continue;
      }
      if (type == 'heading_3') {
        final heading = plainTextFromRichText(
          (block['heading_3'] as Map?)?['rich_text'] as List?,
        );
        currentSection = normalizeNotionKey(heading);
        children.add(_cloneBlockShell(block));
        continue;
      }
      if (type == 'paragraph' && currentSection != null) {
        final replacement = sections[currentSection];
        if (replacement != null &&
            replacement.isNotEmpty &&
            !filledSections.contains(currentSection)) {
          filledSections.add(currentSection);
          if (currentSection == 'stepreproduce') {
            children.addAll(_numberedSteps(replacement));
          } else {
            children.add(_paragraphBlock(replacement));
          }
          continue;
        }
        if (filledSections.contains(currentSection)) {
          continue;
        }
      }
      if (type == 'paragraph') {
        children.add(_cloneBlockShell(block));
      }
    }

    if (children.isEmpty) {
      children.addAll(_defaultIssueBody(fields));
    }

    return children;
  }

  List<Map<String, dynamic>> _defaultIssueBody(QaIssueFieldValues fields) {
    return [
      _headingBlock('Module'),
      _paragraphBlock(fields.module),
      _headingBlock('Precondition'),
      _paragraphBlock(fields.precondition),
      _headingBlock('Step reproduce'),
      ..._numberedSteps(fields.stepReproduce),
      _headingBlock('Expected'),
      _paragraphBlock(fields.expected),
      _headingBlock('Actual'),
      _paragraphBlock(fields.actual),
      _headingBlock('Screenshoot'),
      _paragraphBlock(fields.screenshootSection),
    ];
  }

  List<Map<String, dynamic>> _numberedSteps(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return [
      for (final line in lines)
        {
          'object': 'block',
          'type': 'numbered_list_item',
          'numbered_list_item': {
            'rich_text': _richTextParts(
              line.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
            ),
          },
        },
    ];
  }

  Map<String, dynamic> _paragraphBlock(String text) {
    return {
      'object': 'block',
      'type': 'paragraph',
      'paragraph': {
        'rich_text': _richTextParts(text),
      },
    };
  }

  List<Map<String, dynamic>> _richTextParts(String text) {
    const maxLen = 2000;
    if (text.length <= maxLen) {
      return [
        {
          'type': 'text',
          'text': {'content': text},
        },
      ];
    }
    final parts = <Map<String, dynamic>>[];
    for (var i = 0; i < text.length; i += maxLen) {
      final end = (i + maxLen).clamp(0, text.length);
      parts.add({
        'type': 'text',
        'text': {'content': text.substring(i, end)},
      });
    }
    return parts;
  }

  Map<String, dynamic> _headingBlock(String text) {
    return {
      'object': 'block',
      'type': 'heading_3',
      'heading_3': {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': text},
          },
        ],
      },
    };
  }

  Map<String, dynamic> _cloneBlockShell(Map<String, dynamic> block) {
    final type = block['type']?.toString() ?? 'paragraph';
    final payload = block[type] as Map<String, dynamic>? ?? {};
    return {
      'object': 'block',
      'type': type,
      type: Map<String, dynamic>.from(payload),
    };
  }
}
