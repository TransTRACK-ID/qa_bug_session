import 'dart:convert';

import 'timeline_builder.dart';

class TimelinePresenter {
  String formatLine(TimelineEntry entry) {
    final clock = entry.formatClock();
    final detail = entry.detail;
    switch (entry.label) {
      case 'TAP':
        return '$clock  User tapped "${_formatTapDetail(detail)}"';
      case 'TEXTINPUT':
        return '$clock  Text input on "$detail"';
      case 'NAVIGATION':
        return '$clock  Route → ${_formatRouteDetail(detail)}';
      case 'BACK':
        return '$clock  Navigation back';
      case 'NETWORK_REQUEST':
        return '$clock  $detail';
      case 'NETWORK_RESPONSE':
        final parts = detail.split(' ');
        if (parts.length >= 3) {
          final code = parts[0];
          final method = parts[1];
          final url = parts.sublist(2).join(' ');
          return '$clock  $method $url\n           $code';
        }
        return '$clock  $detail';
      case 'NETWORK_ERROR':
        return '$clock  Network error: $detail';
      case 'VISUAL_FRAME':
        return '$clock  Screenshot captured ($detail)';
      case 'BLOC_EVENT':
        return '$clock  ${detail}';
      case 'BLOC_CHANGE':
        return '$clock  $detail';
      case 'BLOC_ERROR':
        return '$clock  $detail';
      case 'FLUTTER_ERROR':
      case 'PLATFORM_ERROR':
      case 'UNCAUGHT_ERROR':
        return '$clock  Exception: $detail';
      default:
        return '$clock  ${entry.label} $detail';
    }
  }

  static String _formatTapDetail(String detail) {
    final slash = detail.indexOf('/');
    if (slash <= 0) {
      return detail;
    }
    final route = detail.substring(0, slash);
    final label = detail.substring(slash + 1);
    if (route == 'unknown_route') {
      return label;
    }
    return '$label ($route)';
  }

  static String _formatRouteDetail(String detail) {
    try {
      final map = jsonDecode(detail) as Map<String, dynamic>;
      final name = map['name'] as String?;
      if (name != null) {
        return name;
      }
    } catch (_) {
      // Not JSON — use raw payload.
    }
    return detail;
  }
}
