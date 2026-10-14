import 'package:flutter/material.dart';

import 'bug_session_config.dart';

/// Context under the app [Navigator] for sheets, dialogs, and flash.
BuildContext? bugSessionModalContext(BugSessionConfig config) {
  final navigator = config.navigatorKey?.currentState;
  if (navigator == null) {
    return null;
  }

  // Must be a descendant of [Navigator], not [NavigatorState.context] itself.
  final overlay = navigator.overlay;
  final overlayContext = overlay?.context;
  if (overlayContext != null && overlayContext.mounted) {
    return overlayContext;
  }

  final keyContext = config.navigatorKey?.currentContext;
  if (keyContext != null && keyContext.mounted) {
    final nested = Navigator.maybeOf(keyContext);
    if (nested != null) {
      final nestedOverlay = nested.overlay;
      if (nestedOverlay != null && nestedOverlay.context.mounted) {
        return nestedOverlay.context;
      }
    }
    try {
      final rootNav = Navigator.of(keyContext, rootNavigator: true);
      final rootOverlay = rootNav.overlay;
      if (rootOverlay != null && rootOverlay.context.mounted) {
        return rootOverlay.context;
      }
    } catch (_) {
      // No navigator above keyContext.
    }
    if (Navigator.maybeOf(keyContext) != null) {
      return keyContext;
    }
  }

  return null;
}

BuildContext requireBugSessionModalContext(
  BugSessionConfig config, {
  BuildContext? fallback,
}) {
  final resolved = bugSessionModalContext(config);
  if (resolved != null) {
    return resolved;
  }
  if (fallback != null &&
      fallback.mounted &&
      Navigator.maybeOf(fallback) != null) {
    return fallback;
  }
  throw StateError(
    'BugSession modals need BugSessionConfig.navigatorKey with an active '
    'route (same key as MaterialApp / auto_route). Open the app past splash '
    'before using Ready to Test.',
  );
}
