import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';

/// One BugSession modal (library, help, etc.) at a time; FAB collapses while open.
class BugSessionSheetCoordinator {
  bool _modalOpen = false;
  BuildContext? _exclusiveModalContext;

  bool get isModalOpen => _modalOpen;

  /// Called from [BugSessionSheetStack.show] builder — do not pop [navigatorKey] blindly.
  void attachExclusiveModal(BuildContext sheetContext) {
    _exclusiveModalContext = sheetContext;
  }

  void detachExclusiveModal() {
    _exclusiveModalContext = null;
  }

  Future<void> dismissAll(BugSessionKit kit) async {
    if (!_modalOpen) {
      return;
    }
    final sheetContext = _exclusiveModalContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext, rootNavigator: true).pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return;
    }
    final nav = kit.config.navigatorKey?.currentState;
    if (nav != null && nav.canPop() && _topRouteIsOverlay(nav)) {
      nav.pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  static bool _topRouteIsOverlay(NavigatorState nav) {
    bool isTop = true;
    var found = false;
    nav.popUntil((route) {
      if (isTop) {
        found = route is ModalRoute<dynamic> && route.settings.name == null;
        isTop = false;
      }
      return true;
    });
    return found;
  }

  Future<void> runExclusive(
    BugSessionKit kit,
    Future<void> Function() showModal,
  ) async {
    await dismissAll(kit);
    final expandWhenClosed = kit.config.expandPanelWhenSheetClosed;
    kit.controlPanelLayout.collapse();
    _modalOpen = true;
    final video = kit.recorder.videoCapture;
    var haltedVideo = false;
    if (video != null && kit.recorder.isCapturing) {
      await video.haltCapture();
      haltedVideo = true;
    }
    try {
      await showModal();
    } finally {
      detachExclusiveModal();
      _modalOpen = false;
      if (haltedVideo && kit.recorder.isCapturing) {
        await video?.start();
      }
      if (expandWhenClosed) {
        kit.controlPanelLayout.expand();
      } else {
        kit.controlPanelLayout.collapse();
      }
    }
  }
}
