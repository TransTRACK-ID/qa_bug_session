import 'dart:convert';

import '../models/recorded_action.dart';

/// Last named route from [actions] (newest navigation wins).
String? lastNamedRouteFromActions(List<RecordedAction> actions) {
  for (var i = actions.length - 1; i >= 0; i--) {
    final action = actions[i];
    if (action.type != RecordedActionType.navigation) {
      continue;
    }
    final name = extractRouteNameFromPayload(action.route);
    if (name != null && name.isNotEmpty && name != 'unknown_route') {
      return name;
    }
  }
  return null;
}

String? extractRouteNameFromPayload(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }
  if (payload.startsWith('{')) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final name = map['name']?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } on Object {
      // fall through
    }
  }
  if (payload.contains('/')) {
    return payload.split('/').where((s) => s.isNotEmpty).last;
  }
  return payload;
}

/// Human-readable screen title from an auto_route / path name.
String displayRouteName(String? routeName) {
  if (routeName == null || routeName.isEmpty) {
    return '';
  }
  if (routeName == 'unknown_route') {
    return '';
  }
  var label = routeName;
  if (label.endsWith('Route')) {
    label = label.substring(0, label.length - 5);
  }
  return label
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .trim();
}
