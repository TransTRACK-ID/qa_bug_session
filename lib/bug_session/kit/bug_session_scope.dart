import 'package:flutter/widgets.dart';

import '../library/bug_session_catalog.dart';
import '../recording/bug_session_recorder.dart';
import '../replay/bug_session_replayer.dart';
import 'bug_session_config.dart';
import 'bug_session_kit.dart';

class BugSessionScope extends InheritedWidget {
  const BugSessionScope({
    super.key,
    required this.kit,
    required super.child,
  });

  final BugSessionKit kit;

  static BugSessionKit? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BugSessionScope>()
        ?.kit;
  }

  static BugSessionKit of(BuildContext context) {
    final kit = maybeOf(context);
    assert(kit != null, 'BugSessionScope not found');
    return kit!;
  }

  @override
  bool updateShouldNotify(BugSessionScope oldWidget) => kit != oldWidget.kit;
}

extension BugSessionScopeAccess on BuildContext {
  BugSessionRecorder? get bugSessionRecorder =>
      BugSessionScope.maybeOf(this)?.recorder;

  BugSessionCatalog? get bugSessionCatalog =>
      BugSessionScope.maybeOf(this)?.catalog;

  BugSessionReplayer? get bugSessionReplayer =>
      BugSessionScope.maybeOf(this)?.replayer;

  BugSessionConfig? get bugSessionConfig =>
      BugSessionScope.maybeOf(this)?.config;
}
