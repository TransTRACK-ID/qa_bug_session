import '../models/recorded_action.dart';
import '../runtime/bug_session_active_route.dart';

String formatHumanStepReproduce(List<RecordedAction> actions) {
  final lines = <String>[];
  var index = 1;
  String? currentScreen;
  String? lastPlainLine;
  String? lastNamedRoute;

  for (final action in actions) {
    if (action.type == RecordedActionType.navigation) {
      lastNamedRoute =
          extractRouteNameFromPayload(action.route) ?? lastNamedRoute;
    }
    currentScreen = _screenAfterAction(
      action,
      currentScreen,
      lastNamedRoute: lastNamedRoute,
    );
    final line = _describeAction(action, currentScreen: currentScreen);
    if (line == null || line.isEmpty) {
      continue;
    }
    if (line == lastPlainLine) {
      continue;
    }
    lastPlainLine = line;
    lines.add('${index++}. $line');
    if (lines.length >= 40) {
      break;
    }
  }

  return lines.join('\n');
}

String? _screenAfterAction(
  RecordedAction action,
  String? currentScreen, {
  String? lastNamedRoute,
}) {
  switch (action.type) {
    case RecordedActionType.navigation:
      return _humanRouteFromPayload(action.route) ?? currentScreen;
    case RecordedActionType.tap:
    case RecordedActionType.textInput:
    case RecordedActionType.scroll:
    case RecordedActionType.swipe:
      return _screenFromTarget(action.target, fallbackRoute: lastNamedRoute) ??
          currentScreen;
    case RecordedActionType.back:
      return currentScreen;
  }
}

String? _describeAction(
  RecordedAction action, {
  required String? currentScreen,
}) {
  switch (action.type) {
    case RecordedActionType.tap:
      return _describeTap(action, currentScreen);
    case RecordedActionType.textInput:
      final text = action.text?.trim();
      final (_, control) = _parseTarget(action.target);
      final screen = _screenFromTarget(action.target) ?? currentScreen ?? 'screen';
      if (text == null || text.isEmpty) {
        return 'On "$screen", enter text in "$control"';
      }
      final clipped = text.length > 48 ? '${text.substring(0, 48)}…' : text;
      return 'On "$screen", type "$clipped" in "$control"';
    case RecordedActionType.navigation:
      final dest = _humanRouteFromPayload(action.route);
      if (dest == null) {
        return 'Open screen';
      }
      return 'Navigate to "$dest"';
    case RecordedActionType.back:
      final from = currentScreen ?? 'current screen';
      return 'Go back from "$from"';
    case RecordedActionType.scroll:
      final screen = _screenFromTarget(action.target) ?? currentScreen ?? 'screen';
      return 'Scroll on "$screen"';
    case RecordedActionType.swipe:
      final screen = _screenFromTarget(action.target) ?? currentScreen ?? 'screen';
      return 'Swipe on "$screen"';
  }
}

String _describeTap(RecordedAction action, String? currentScreen) {
  final (screenFromTarget, control) = _parseTarget(action.target);
  final metaScreen = action.metadata['screenLabel']?.toString();
  final screen = metaScreen?.isNotEmpty == true
      ? metaScreen!
      : (screenFromTarget ?? currentScreen ?? 'Current screen');
  final recorderId = action.metadata['recorderId']?.toString();
  final semanticsLabel = action.metadata['semanticsLabel']?.toString();
  final widgetType = action.metadata['widgetType']?.toString();
  final label = _humanControlLabel(
    control,
    recorderId: recorderId,
    semanticsLabel: semanticsLabel,
    widgetType: widgetType,
  );
  if (_isDialogLike(label)) {
    return 'On "$screen", open/interact with "$label" dialog or sheet';
  }
  return 'On "$screen", tap "$label"';
}

bool _isDialogLike(String label) {
  final lower = label.toLowerCase();
  return lower.contains('dialog') ||
      lower.contains('modal') ||
      lower.contains('bottom sheet') ||
      lower == 'scrim';
}

(String? screen, String control) _parseTarget(String? target) {
  if (target == null || target.isEmpty) {
    return (null, 'control');
  }
  final slash = target.lastIndexOf('/');
  if (slash <= 0) {
    return (null, target);
  }
  final rawScreen = target.substring(0, slash);
  final screen = _humanRoute(rawScreen);
  return (
    screen.isEmpty ? null : screen,
    target.substring(slash + 1),
  );
}

String? _screenFromTarget(String? target, {String? fallbackRoute}) {
  final (screen, _) = _parseTarget(target);
  if (screen != null && screen.isNotEmpty) {
    return screen;
  }
  if (fallbackRoute != null && fallbackRoute.isNotEmpty) {
    return displayRouteName(fallbackRoute);
  }
  return null;
}

String _humanControlLabel(
  String control, {
  String? recorderId,
  String? semanticsLabel,
  String? widgetType,
}) {
  if (widgetType != null && widgetType.isNotEmpty) {
    return widgetType;
  }
  if (control.toLowerCase() != 'tap' && control.isNotEmpty) {
    return _titleCase(control.replaceAll('_', ' '));
  }
  if (semanticsLabel != null && semanticsLabel.isNotEmpty) {
    return semanticsLabel;
  }
  if (recorderId != null && recorderId.isNotEmpty) {
    return recorderId;
  }
  return 'unlabeled control';
}

String? _humanRouteFromPayload(String? route) {
  if (route == null || route.isEmpty) {
    return null;
  }
  if (route.startsWith('{')) {
    final nameMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(route);
    if (nameMatch != null) {
      return _humanRoute(nameMatch.group(1));
    }
  }
  return _humanRoute(route);
}

String _humanRoute(String? route) {
  if (route == null || route.isEmpty) {
    return 'screen';
  }
  if (route == 'unknown_route') {
    return '';
  }
  final pretty = displayRouteName(route);
  if (pretty.isNotEmpty && !route.contains('/')) {
    return pretty;
  }
  final segments = route.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) {
    return _titleCase(route.replaceAll('_', ' '));
  }
  if (segments.length >= 2) {
    final tail = segments.sublist(segments.length - 2);
    return _titleCase(tail.join(' ').replaceAll('_', ' '));
  }
  final last = segments.last.replaceAll('_', ' ');
  return _titleCase(last);
}

String _titleCase(String input) {
  return input
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String resolveTestingModuleLabel({
  String? currentRoute,
  required List<RecordedAction> actions,
}) {
  for (final action in actions.reversed) {
    if (action.type == RecordedActionType.navigation &&
        action.route != null &&
        action.route!.contains('modules/')) {
      final module = _moduleFromPath(action.route!);
      if (module != null) {
        return module;
      }
    }
  }
  if (currentRoute != null && currentRoute.contains('modules/')) {
    final module = _moduleFromPath(currentRoute);
    if (module != null) {
      return module;
    }
  }
  if (currentRoute != null && currentRoute.isNotEmpty) {
    return _titleCase(currentRoute.split('/').last.replaceAll('_', ' '));
  }
  return 'General';
}

String? _moduleFromPath(String path) {
  final parts = path.split('/');
  final modulesIndex = parts.indexOf('modules');
  if (modulesIndex == -1 || modulesIndex + 2 >= parts.length) {
    if (parts.isNotEmpty) {
      return _titleCase(parts.last.replaceAll('_', ' '));
    }
    return null;
  }
  final feature = parts[modulesIndex + 2];
  return _titleCase(feature.replaceAll('_', ' '));
}
