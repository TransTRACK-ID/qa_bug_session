import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../kit/bug_session_kit.dart';
import '../models/recorded_action.dart';
import '../replay/bug_session_chrome_hit_test.dart';
import '../runtime/bug_session_active_route.dart';
import '../runtime/bug_session_tap_probe.dart';

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
  Offset? _pendingTextGlobal;
  Map<String, Object?> _pendingTextMetadata = const {};
  String _lastRecordedTextForTarget = '';

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
    final payload = <String, dynamic>{
      'name': route,
      'label': label,
    };
    if (label == 'session_start') {
      final activeTab = widget.kit.config.activeNavbarTabRouteName?.call();
      if (activeTab != null && activeTab.isNotEmpty) {
        payload['activeTab'] = activeTab;
      }
    }
    _appendAction(
      RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: widget.kit.recorder.isShadowplayActive
            ? widget.kit.recorder.shadowplay.elapsedMs()
            : widget.kit.recorder.semantic.elapsedMs(),
        route: jsonEncode(payload),
      ),
    );
  }

  String _routeKeyForRecordedTap(BuildContext context) {
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
    final fromActions = lastNamedRouteFromActions(
      widget.kit.recorder.recordedActions,
    );
    if (fromActions != null && fromActions.isNotEmpty) {
      return fromActions;
    }
    return 'unknown_route';
  }

  String? _currentRouteName() {
    final label = _routeKeyForRecordedTap(context);
    if (label == 'unknown_route') {
      return null;
    }
    return label;
  }

  String? _screenLabelForTap(BuildContext context, String routeKey) {
    final fromHost = widget.kit.config.resolveTapScreenLabel?.call(
      context,
      routeKey,
    );
    if (fromHost != null && fromHost.isNotEmpty) {
      return fromHost;
    }
    if (routeKey != 'unknown_route' && routeKey.isNotEmpty) {
      final pretty = displayRouteName(routeKey);
      if (pretty.isNotEmpty) {
        return pretty;
      }
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
    final route = _routeKeyForRecordedTap(context);
    final semanticsLabel = _semanticsLabelAt(event.position);
    final label = semanticsLabel ?? 'tap';
    final target = '$route/$label';
    final recorderId = _recorderIdAt(event.position);
    final widgetType = widgetTypeAtGlobal(event.position, context);
    final screenLabel = _screenLabelForTap(context, route);
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
          if (semanticsLabel != null && semanticsLabel.isNotEmpty)
            'semanticsLabel': semanticsLabel,
          if (widgetType != null && widgetType.isNotEmpty)
            'widgetType': widgetType,
          if (screenLabel != null && screenLabel.isNotEmpty)
            'screenLabel': screenLabel,
          'screenRoute': route,
        },
      ),
    );
    _scheduleTextCaptureFromHit(
      event.position,
      fallbackTarget: target,
      tapMetadata: {
        'globalX': event.position.dx,
        'globalY': event.position.dy,
        'normalizedX': logicalSize.width > 0
            ? event.position.dx / logicalSize.width
            : 0.0,
        'normalizedY': logicalSize.height > 0
            ? event.position.dy / logicalSize.height
            : 0.0,
        if (recorderId != null) 'recorderId': recorderId,
        if (semanticsLabel != null && semanticsLabel.isNotEmpty)
          'semanticsLabel': semanticsLabel,
        if (widgetType != null && widgetType.isNotEmpty) 'widgetType': widgetType,
        if (screenLabel != null && screenLabel.isNotEmpty)
          'screenLabel': screenLabel,
        'screenRoute': route,
      },
    );
  }

  void _scheduleTextCaptureFromHit(
    Offset global, {
    required String fallbackTarget,
    required Map<String, Object?> tapMetadata,
  }) {
    final editable = _editableAt(global);
    if (editable == null) {
      _flushPendingTextInput(
        editableAt: _pendingTextGlobal != null
            ? _editableAt(_pendingTextGlobal!)
            : null,
      );
      return;
    }
    final wiredRecorderId = tapMetadata['recorderId'];
    if (wiredRecorderId is String && wiredRecorderId.isNotEmpty) {
      if (_pendingTextTarget != null) {
        _flushPendingTextInput(
          editableAt: _pendingTextGlobal != null
              ? _editableAt(_pendingTextGlobal!)
              : null,
        );
      }
      return;
    }
    if (_pendingTextTarget != null && _pendingTextTarget != fallbackTarget) {
      _flushPendingTextInput(
        editableAt: _pendingTextGlobal != null
            ? _editableAt(_pendingTextGlobal!)
            : null,
      );
    }
    _pendingTextTarget = fallbackTarget;
    _pendingTextGlobal = global;
    _pendingTextMetadata = tapMetadata;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !widget.kit.recorder.isCapturing) {
        return;
      }
      if (_pendingTextTarget != fallbackTarget) {
        return;
      }
      _recordTextInputFromEditable(
        editable,
        fallbackTarget: fallbackTarget,
        global: global,
        tapMetadata: tapMetadata,
      );
      _clearPendingTextInput();
    });
  }

  void _recordTextInputFromEditable(
    RenderEditable editable, {
    required String fallbackTarget,
    required Offset global,
    required Map<String, Object?> tapMetadata,
  }) {
    final plainText =
        editable.text?.toPlainText(includeSemanticsLabels: false) ?? '';
    final recorderId = tapMetadata['recorderId'];
    final target = recorderId is String && recorderId.isNotEmpty
        ? recorderId
        : fallbackTarget;
    // Skip empty on a virgin field (random taps); allow empty when clearing.
    if (plainText.isEmpty) {
      final prefix = '$target|';
      final prior = _lastRecordedTextForTarget;
      final hadNonEmptyForTarget =
          prior.startsWith(prefix) && prior.length > prefix.length;
      if (!hadNonEmptyForTarget) {
        return;
      }
    }
    final dedupeKey = '$target|$plainText';
    if (dedupeKey == _lastRecordedTextForTarget) {
      return;
    }
    _lastRecordedTextForTarget = dedupeKey;
    _appendAction(
      RecordedAction(
        type: RecordedActionType.textInput,
        timestampMs: widget.kit.recorder.isShadowplayActive
            ? widget.kit.recorder.shadowplay.elapsedMs()
            : widget.kit.recorder.semantic.elapsedMs(),
        target: target,
        text: plainText,
        metadata: Map<String, Object?>.from(tapMetadata),
      ),
    );
  }

  void _flushPendingTextInput({RenderEditable? editableAt}) {
    final target = _pendingTextTarget;
    final global = _pendingTextGlobal;
    final meta = _pendingTextMetadata;
    if (target != null && global != null && editableAt != null) {
      _recordTextInputFromEditable(
        editableAt,
        fallbackTarget: target,
        global: global,
        tapMetadata: meta,
      );
    }
    _clearPendingTextInput();
  }

  void _clearPendingTextInput() {
    _pendingTextTarget = null;
    _pendingTextGlobal = null;
    _pendingTextMetadata = const {};
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
