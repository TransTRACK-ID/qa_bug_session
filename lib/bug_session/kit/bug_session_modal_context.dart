import 'package:flutter/material.dart';

import 'bug_session_config.dart';

/// Resolves a [BuildContext] under the app [Navigator] for sheets and dialogs.
BuildContext? bugSessionModalContext(BugSessionConfig config) {
  return config.navigatorKey?.currentContext;
}

BuildContext requireBugSessionModalContext(
  BugSessionConfig config, {
  BuildContext? fallback,
}) {
  final ctx = bugSessionModalContext(config) ?? fallback;
  if (ctx == null) {
    throw StateError(
      'BugSession modals need BugSessionConfig.navigatorKey with an active '
      'route (same key as MaterialApp / auto_route).',
    );
  }
  return ctx;
}
