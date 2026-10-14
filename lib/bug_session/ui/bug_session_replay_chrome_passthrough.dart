import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// While [passthrough] is true, this subtree is painted but does not receive
/// pointer hits — replay coordinate taps reach the app underneath.
class BugSessionReplayChromePassthrough extends SingleChildRenderObjectWidget {
  const BugSessionReplayChromePassthrough({
    super.key,
    required this.passthrough,
    required this.child,
  });

  final bool passthrough;
  final Widget child;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBugSessionReplayChromePassthrough(passthrough: passthrough);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBugSessionReplayChromePassthrough renderObject,
  ) {
    renderObject.passthrough = passthrough;
  }
}

class RenderBugSessionReplayChromePassthrough extends RenderProxyBox {
  RenderBugSessionReplayChromePassthrough({required bool passthrough})
      : _passthrough = passthrough;

  bool _passthrough;

  bool get passthrough => _passthrough;

  set passthrough(bool value) {
    if (_passthrough == value) {
      return;
    }
    _passthrough = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_passthrough) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
