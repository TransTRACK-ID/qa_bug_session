import 'package:flutter/foundation.dart';

/// Minimal overlay chrome while a Notion card QA session is active.
class QaTestingChromeController extends ChangeNotifier {
  bool _active = false;

  bool get active => _active;

  void enter() {
    if (_active) {
      return;
    }
    _active = true;
    notifyListeners();
  }

  void exit() {
    if (!_active) {
      return;
    }
    _active = false;
    notifyListeners();
  }
}
