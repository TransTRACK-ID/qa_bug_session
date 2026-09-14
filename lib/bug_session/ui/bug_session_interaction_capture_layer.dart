import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../kit/bug_session_kit.dart';
import '../replay/bug_session_chrome_hit_test.dart';
import '../models/recorded_action.dart';

/// Records session-start route and taps outside BugSession chrome while recording.
class BugSessionInteractionCaptureLayer extends StatefulWidget {
  const BugSessionInteractionCaptureLayer({
    super.key,
    required this.kit,
    required this.child,
  });

  final BugSessionKit kit;
  final Widget child;

  @override
  State<BugSessionInteractionCaptureLayer> createState() =>
      _BugSessionInteractionCaptureLayerState();
}

class _BugSessionInteractionCaptureLayerState
    extends State<BugSessionInteractionCaptureLayer> {
  bool _loggedSessionStart = false;
  String? _pendingTextTarget;

  @override
  void initState() {
    super.initState();
    widget.kit.recorder.addListener(_onRecorderChanged);
  }

  @override
  void dispose() {
    widget.kit.recorder.removeListener(_onRecorderChanged);
    super.dispose();
  }

  void _onRecorderChanged() {
    if (!widget.kit.recorder.isCapturing) {
      _loggedSessionStart = false;
      return;
    }
    if (_loggedSessionStart) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.kit.recorder.isCapturing || _loggedSessionStart) {
        return;
      }
      _loggedSessionStart = true;
      _recordCurrentRoute('session_start');
    });
  }

  void _appendAction(RecordedAction action) {
    final recorder = widget.kit.recorder;
    if (recorder.isRecording) {
      recorder.semantic.recordAction(action);
    } else if (recorder.isShadowplayActive) {
      recorder.recordShadowplayAction(action);
    }
  }

  void _recordCurrentRoute(String label) {
    final route = _currentRouteName();
    if (route == null) {
      return;
    }
    _appendAction(
      RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: widget.kit.recorder.isShadowplayActive
            ? widget.kit.recorder.shadowplay.elapsedMs()
            : widget.kit.recorder.semantic.elapsedMs(),
        route: '{"name":"$route","label":"$label"}',
      ),
    );
  }

  String? _currentRouteName() {
    final fromHost = widget.kit.config.currentRouteName?.call();
    if (fromHost != null && fromHost.isNotEmpty) {
      return fromHost;
    }
    final navContext = widget.kit.config.navigatorKey?.currentContext;
    if (navContext != null) {
      final name = ModalRoute.of(navContext)?.settings.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    final name = ModalRoute.of(context)?.settings.name;
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return null;
  }

  void _onPointerUp(PointerUpEvent event) {
    final recorder = widget.kit.recorder;
    if (!recorder.isCapturing) {
      return;
    }
    if (bugSessionChromeHitAt(event.position)) {
      return;
    }
    final route = _currentRouteName() ?? 'unknown_route';
    final label = _semanticsLabelAt(event.position) ?? 'tap';
    final target = '$route/$label';
    final recorderId = _recorderIdAt(event.position);
    widget.kit.tapRipples.recordTap(event.position);
    final view = View.of(context);
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    final ts = recorder.isShadowplayActive
        ? recorder.shadowplay.elapsedMs()
        : recorder.semantic.elapsedMs();
    _appendAction(
      RecordedAction(
        type: RecordedActionType.tap,
        timestampMs: ts,
        target: target,
        metadata: {
          'globalX': event.position.dx,
          'globalY': event.position.dy,
          'normalizedX': logicalSize.width > 0
              ? event.position.dx / logicalSize.width
              : 0.0,
          'normalizedY': logicalSize.height > 0
              ? event.position.dy / logicalSize.height
              : 0.0,
          if (recorderId != null) 'recorderId': recorderId,
        },
      ),
    );
    _scheduleTextCaptureFromHit(event.position, fallbackTarget: target);
  }

  void _scheduleTextCaptureFromHit(
    Offset global, {
    required String fallbackTarget,
  }) {
    final editable = _editableAt(global);
    if (editable == null) {
      _flushPendingTextInput();
      return;
    }
    _pendingTextTarget = fallbackTarget;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !widget.kit.recorder.isCapturing) {
        return;
      }
      if (_pendingTextTarget != fallbackTarget) {
        return;
      }
      final plainText = editable.text?.toPlainText(includeSemanticsLabels: false) ?? '';
      if (plainText.isEmpty) {
        return;
      }
      final view = View.of(context);
      final logicalSize = view.physicalSize / view.devicePixelRatio;
      _appendAction(
        RecordedAction(
          type: RecordedActionType.textInput,
          timestampMs: widget.kit.recorder.isShadowplayActive
              ? widget.kit.recorder.shadowplay.elapsedMs()
              : widget.kit.recorder.semantic.elapsedMs(),
          target: fallbackTarget,
          text: plainText,
          metadata: {
            'globalX': global.dx,
            'globalY': global.dy,
            'normalizedX': logicalSize.width > 0
                ? global.dx / logicalSize.width
                : 0.0,
            'normalizedY': logicalSize.height > 0
                ? global.dy / logicalSize.height
                : 0.0,
          },
        ),
      );
      _pendingTextTarget = null;
    });
  }

  void _flushPendingTextInput() {
    _pendingTextTarget = null;
  }

  RenderEditable? _editableAt(Offset global) {
    final result = HitTestResult();
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      if (entry.target is RenderEditable) {
        return entry.target as RenderEditable;
      }
    }
    return null;
  }

  String? _recorderIdAt(Offset global) {
    final result = HitTestResult();
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsAnnotations) {
        final id = target.properties.identifier;
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }
    return null;
  }

  String? _semanticsLabelAt(Offset global) {
    final result = HitTestResult();
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsAnnotations) {
        final label = target.properties.label;
        if (label != null && label.isNotEmpty && label != 'BugSession') {
          return label;
        }
        final hint = target.properties.hint;
        if (hint != null && hint.isNotEmpty) {
          return hint;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }
}
