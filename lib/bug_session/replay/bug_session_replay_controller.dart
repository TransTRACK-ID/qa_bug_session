import 'package:flutter/foundation.dart';

/// Live replay lifecycle — exposes [active] and cooperative [requestStop].
class BugSessionReplayController extends ChangeNotifier {
  bool _active = false;
  bool _stopRequested = false;

  bool get active => _active;

  bool get stopRequested => _stopRequested;

  void begin() {
    _active = true;
    _stopRequested = false;
    notifyListeners();
  }

  void requestStop() {
    if (!_active || _stopRequested) {
      return;
    }
    _stopRequested = true;
    notifyListeners();
  }

  void end() {
    _active = false;
    _stopRequested = false;
    notifyListeners();
  }
}
