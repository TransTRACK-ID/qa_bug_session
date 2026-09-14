import 'package:flutter/foundation.dart';

/// FAB panel capture mode (Instant Replay vs Full Record).
enum BugSessionPanelCaptureMode {
  instantReplay,
  fullRecord,
}

class BugSessionCaptureMode extends ChangeNotifier {
  BugSessionPanelCaptureMode _mode = BugSessionPanelCaptureMode.instantReplay;

  BugSessionPanelCaptureMode get mode => _mode;

  bool get isInstantReplay => _mode == BugSessionPanelCaptureMode.instantReplay;

  void setMode(BugSessionPanelCaptureMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }
}
