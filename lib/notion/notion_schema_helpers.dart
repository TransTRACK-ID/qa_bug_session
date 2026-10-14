// Resolve Notion data-source properties and build API payloads.

import 'notion_api.dart';

String normalizeNotionKey(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class NotionPropertyDescriptor {
  const NotionPropertyDescriptor({
    required this.name,
    required this.type,
  });

  final String name;
  final String type;
}

Map<String, NotionPropertyDescriptor> parseDataSourceProperties(
  Map<String, dynamic> schema,
) {
  final properties = schema['properties'] as Map<String, dynamic>? ?? {};
  return {
    for (final entry in properties.entries)
      entry.key: NotionPropertyDescriptor(
        name: entry.key,
        type: (entry.value as Map?)?['type']?.toString() ?? '',
      ),
  };
}

NotionPropertyDescriptor? findProperty(
  Map<String, NotionPropertyDescriptor> props, {
  required String normalizedName,
}) {
  for (final entry in props.entries) {
    if (normalizeNotionKey(entry.key) == normalizedName) {
      return entry.value;
    }
  }
  return null;
}

String? findTitlePropertyName(Map<String, NotionPropertyDescriptor> props) {
  for (final entry in props.entries) {
    if (entry.value.type == 'title') {
      return entry.key;
    }
  }
  return null;
}

List<Map<String, String>> selectOptions(
  Map<String, dynamic> schema,
  String propertyName,
) {
  final prop = schema['properties']?[propertyName] as Map?;
  if (prop == null) {
    return const [];
  }
  final type = prop['type']?.toString();
  final bucket = prop[type] as Map?;
  final options = bucket?['options'] as List? ?? [];
  return [
    for (final opt in options)
      if (opt is Map)
        {
          'id': opt['id']?.toString() ?? '',
          'name': opt['name']?.toString() ?? '',
        },
  ];
}

Map<String, String>? matchSelectOption(
  List<Map<String, String>> options,
  String desiredName,
) {
  final target = normalizeNotionKey(desiredName);
  for (final option in options) {
    if (normalizeNotionKey(option['name'] ?? '') == target) {
      return option;
    }
  }
  return null;
}

Map<String, dynamic> richTextProperty(String text) {
  return {
    'rich_text': [
      {
        'type': 'text',
        'text': {'content': text},
      },
    ],
  };
}

Map<String, dynamic> titleProperty(String text) {
  return {
    'title': [
      {
        'type': 'text',
        'text': {'content': text},
      },
    ],
  };
}

Map<String, dynamic> selectPropertyById(String optionId) {
  return {
    'select': {'id': optionId},
  };
}

Map<String, dynamic> statusPropertyById(String optionId) {
  return {
    'status': {'id': optionId},
  };
}

Map<String, dynamic> dateProperty(DateTime date) {
  return {
    'date': {
      'start': date.toIso8601String().split('T').first,
    },
  };
}

Map<String, dynamic> relationProperty(List<String> pageIds) {
  return {
    'relation': [
      for (final id in pageIds) {'id': id},
    ],
  };
}

String readPlainRichText(Map<String, dynamic>? prop, String type) {
  final bucket = prop?[type] as Map?;
  final rich = bucket?['rich_text'] as List?;
  return plainTextFromRichText(rich);
}

List<String> readRelationIds(Map<dynamic, dynamic>? prop) {
  final relation = prop?['relation'] as List? ?? [];
  return [
    for (final item in relation)
      if (item is Map) item['id']?.toString() ?? '',
  ].where((id) => id.isNotEmpty).toList();
}

bool pageHasParentRelation(
  Map<String, dynamic> page,
  String parentRelationPropertyName,
) {
  final props = page['properties'] as Map<String, dynamic>? ?? {};
  final rel = readRelationIds(props[parentRelationPropertyName] as Map?);
  return rel.isNotEmpty;
}

/// Notion people columns that only accept workspace groups (not users).
const groupOnlyPeoplePropertyKeys = {'developer', 'qa', 'observer'};

/// Copies parent people assignees for create-page (users + groups, 1..N).
///
/// Groups keep `object: group`. Users omit `object` (Notion rejects `user` on
/// some bug-card columns).
Map<String, dynamic>? peoplePropertyForCreateFromParent(
  Map<String, dynamic> prop,
) {
  final people = prop['people'] as List? ?? [];
  final out = <Map<String, String>>[];
  final seenIds = <String>{};
  for (final item in people) {
    if (item is! Map) {
      continue;
    }
    final id = item['id']?.toString();
    if (id == null || id.isEmpty || seenIds.contains(id)) {
      continue;
    }
    seenIds.add(id);
    if (item['object']?.toString() == 'group') {
      out.add({'object': 'group', 'id': id});
    } else {
      out.add({'id': id});
    }
  }
  if (out.isEmpty) {
    return null;
  }
  return {'people': out};
}

/// Sets [out] people fields from the parent page (Developer, QA, Observer, …).
void applyGroupOnlyPeopleFromParent({
  required Map<String, dynamic> out,
  required Map<String, dynamic> parentPage,
  required Map<String, NotionPropertyDescriptor> schemaProps,
  Set<String> normalizedNames = groupOnlyPeoplePropertyKeys,
}) {
  final parentProps = parentPage['properties'] as Map<String, dynamic>? ?? {};
  for (final normalized in normalizedNames) {
    final prop = findProperty(schemaProps, normalizedName: normalized);
    if (prop == null) {
      continue;
    }
    final parentValue = parentProps[prop.name];
    if (parentValue is! Map<String, dynamic>) {
      continue;
    }
    final copied = peoplePropertyForCreateFromParent(parentValue);
    if (copied != null) {
      out[prop.name] = copied;
    } else {
      out.remove(prop.name);
    }
  }
}

Map<String, dynamic> copyCompatibleProperties({
  required Map<String, dynamic> parentPage,
  required Map<String, NotionPropertyDescriptor> schemaProps,
  required Set<String> skipNormalizedNames,
}) {
  final parentProps = parentPage['properties'] as Map<String, dynamic>? ?? {};
  final out = <String, dynamic>{};

  for (final entry in parentProps.entries) {
    final name = entry.key;
    final normalized = normalizeNotionKey(name);
    if (skipNormalizedNames.contains(normalized)) {
      continue;
    }
    final descriptor = schemaProps[name];
    if (descriptor == null) {
      continue;
    }
    final type = descriptor.type;
    if (type == 'title' ||
        type == 'formula' ||
        type == 'rollup' ||
        type == 'unique_id' ||
        type == 'created_time' ||
        type == 'last_edited_time' ||
        type == 'created_by') {
      continue;
    }
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    if (value[type] == null) {
      continue;
    }
    if (type == 'people' &&
        groupOnlyPeoplePropertyKeys.contains(normalized)) {
      final copied = peoplePropertyForCreateFromParent(
        Map<String, dynamic>.from(value),
      );
      if (copied != null) {
        out[name] = copied;
      }
      continue;
    }
    out[name] = value;
  }

  return out;
}
