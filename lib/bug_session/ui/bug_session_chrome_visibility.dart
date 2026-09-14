import 'package:flutter/foundation.dart';

/// Hides BugSession FAB / recording chip during replay dialogs and playback.
class BugSessionChromeVisibility extends ChangeNotifier {
  bool _visible = true;

  bool get visible => _visible;

  void hide() {
    if (!_visible) {
      return;
    }
    _visible = false;
    notifyListeners();
  }

  void show() {
    if (_visible) {
      return;
    }
    _visible = true;
    notifyListeners();
  }
}
