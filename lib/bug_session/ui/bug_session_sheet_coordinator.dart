import '../kit/bug_session_kit.dart';

/// One BugSession modal (library, help, etc.) at a time; FAB collapses while open.
class BugSessionSheetCoordinator {
  bool _modalOpen = false;

  bool get isModalOpen => _modalOpen;

  Future<void> dismissAll(BugSessionKit kit) async {
    final nav = kit.config.navigatorKey?.currentState;
    if (_modalOpen && nav != null && nav.canPop()) {
      nav.pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    _modalOpen = false;
  }

  Future<void> runExclusive(
    BugSessionKit kit,
    Future<void> Function() showModal,
  ) async {
    await dismissAll(kit);
    final expandWhenClosed = kit.config.expandPanelWhenSheetClosed;
    kit.controlPanelLayout.collapse();
    _modalOpen = true;
    try {
      await showModal();
    } finally {
      _modalOpen = false;
      if (expandWhenClosed) {
        kit.controlPanelLayout.expand();
      } else {
        kit.controlPanelLayout.collapse();
      }
    }
  }
}
