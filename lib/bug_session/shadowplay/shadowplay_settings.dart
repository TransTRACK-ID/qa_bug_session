import 'package:meta/meta.dart';

import 'shadowplay_mode.dart';

@immutable
class BugSessionShadowplaySettings {
  const BugSessionShadowplaySettings({
    this.enabled = false,
    this.mode = BugSessionShadowplayMode.semantic,
    this.rawEventRetention = const Duration(seconds: 30),
    this.semanticEventRetention = const Duration(seconds: 60),
    this.maxVideoRetention = const Duration(seconds: 60),
    this.defaultVideoRetention = const Duration(seconds: 30),
  });

  final bool enabled;
  final BugSessionShadowplayMode mode;
  final Duration rawEventRetention;
  final Duration semanticEventRetention;
  final Duration maxVideoRetention;
  final Duration defaultVideoRetention;

  Duration eventRetentionFor(BugSessionShadowplayMode mode) {
    return mode == BugSessionShadowplayMode.raw
        ? rawEventRetention
        : semanticEventRetention;
  }
}
