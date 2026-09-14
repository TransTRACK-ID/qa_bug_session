import 'package:flutter/foundation.dart';

/// Expanded vs collapsed BugSession FAB panel.
class BugSessionControlPanelLayout extends ChangeNotifier {
  bool _expanded = false;

  bool get expanded => _expanded;

  void expand() {
    if (_expanded) {
      return;
    }
    _expanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_expanded) {
      return;
    }
    _expanded = false;
    notifyListeners();
  }
}
