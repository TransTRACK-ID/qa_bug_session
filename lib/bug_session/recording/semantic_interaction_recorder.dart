import 'package:flutter/widgets.dart';

import '../kit/bug_session_config.dart';
import '../models/recorded_action.dart';
import '../replay/coordinate_tap_replay.dart';
import '../runtime/recorder_target_registry.dart';
import 'interaction_recorder.dart';

/// MVP interaction engine using semantic target ids (Section 7).
class SemanticInteractionRecorder implements InteractionRecorder {
  SemanticInteractionRecorder({
    this.replayNavigation,
    this.replayStepDelay = Duration.zero,
    this.replaySettle,
    this.tryReplayAction,
    this.resolveReplayTapPosition,
    this.resolveRecorderTargetId,
  });

  final BugSessionNavigationReplay? replayNavigation;
  final Duration replayStepDelay;
  final BugSessionReplaySettle? replaySettle;
  final BugSessionTryReplayAction? tryReplayAction;
  final BugSessionResolveReplayTapPosition? resolveReplayTapPosition;
  final BugSessionResolveRecorderTargetId? resolveRecorderTargetId;

  String? _sessionId;
  int? _startedAtMs;
  final List<RecordedAction> _actions = [];

  bool get isRecording => _sessionId != null;

  List<RecordedAction> get actions => List.unmodifiable(_actions);

  int elapsedMs() => _elapsedMs();

  int _elapsedMs() {
    final start = _startedAtMs;
    if (start == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - start;
  }

  void recordAction(RecordedAction action) {
    if (!isRecording) return;
    _actions.add(action);
  }

  void recordTap(String target) {
    recordAction(
      RecordedAction(
        type: RecordedActionType.tap,
        timestampMs: _elapsedMs(),
        target: target,
      ),
    );
  }

  void recordTextInput(
    String target,
    String text, {
    Map<String, Object?> metadata = const {},
  }) {
    recordAction(
      RecordedAction(
        type: RecordedActionType.textInput,
        timestampMs: _elapsedMs(),
        target: target,
        text: text,
        metadata: metadata,
      ),
    );
  }

  void recordNavigation(String route) {
    recordAction(
      RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: _elapsedMs(),
        route: route,
      ),
    );
  }

  void recordBack() {
    recordAction(
      RecordedAction(
        type: RecordedActionType.back,
        timestampMs: _elapsedMs(),
      ),
    );
  }

  @override
  Future<void> start(String sessionId) async {
    _sessionId = sessionId;
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _actions.clear();
  }

  @override
  Future<RecordedActions> stop() async {
    final result = RecordedActions(actions: List.unmodifiable(_actions));
    _sessionId = null;
    _startedAtMs = null;
    return result;
  }

  @override
  Future<int> replay(
    RecordedActions actions, {
    Duration targetTimeout = const Duration(seconds: 10),
    void Function(RecordedAction action, Object error)? onActionFailed,
    bool Function()? shouldStop,
  }) async {
    final list = actions.actions;
    final minMs = replayStepDelay.inMilliseconds;
    final maxGapMs = minMs > 0 ? 12000 : 300000;
    for (var i = 0; i < list.length; i++) {
      if (shouldStop?.call() == true) {
        return i;
      }
      final action = list[i];
      if (i > 0) {
        final previous = list[i - 1];
        if (!_isSessionStartNavigation(previous)) {
          final rawGap = action.timestampMs - previous.timestampMs;
          final gapMs = rawGap < 0 ? 0 : rawGap;
          final waitMs = minMs > 0
              ? gapMs.clamp(minMs, maxGapMs)
              : gapMs.clamp(0, maxGapMs);
          if (waitMs > 0) {
            final completed = await _delayWithStop(
              waitMs,
              shouldStop: shouldStop,
            );
            if (!completed) {
              return i;
            }
          }
        }
      }
      try {
        if (!_isSessionStartNavigation(action)) {
          await _replayOne(
            action,
            targetTimeout: targetTimeout,
            shouldStop: shouldStop,
          );
        }
        if (shouldStop?.call() == true) {
          return i + 1;
        }
        final nextAction = i + 1 < list.length ? list[i + 1] : null;
        await replaySettle?.call(
          completedAction: action,
          nextAction: nextAction,
          shouldStop: shouldStop,
        );
      } catch (e, _) {
        onActionFailed?.call(action, e);
        rethrow;
      }
    }
    return list.length;
  }

  bool _isSessionStartNavigation(RecordedAction action) {
    if (action.type != RecordedActionType.navigation) {
      return false;
    }
    final route = action.route ?? '';
    return route.contains('"label":"session_start"') ||
        route.contains('session_start');
  }

  Iterable<String> _registryIdsForTap(RecordedAction action, String target) {
    final ids = <String>[];
    final seen = <String>{};
    void consider(String? id) {
      if (id == null || id.isEmpty || !seen.add(id)) {
        return;
      }
      ids.add(id);
    }

    final metaId = action.metadata['recorderId'];
    if (metaId is String) {
      consider(metaId);
    }
    if (!target.contains('/')) {
      consider(target);
    }
    consider(resolveRecorderTargetId?.call(action));
    final slash = target.lastIndexOf('/');
    if (slash >= 0 && slash < target.length - 1) {
      consider(target.substring(slash + 1));
    }
    return ids;
  }

  Future<bool> _activateRegistryTap(
    RecordedAction action, {
    required Duration targetTimeout,
  }) async {
    final target = action.target;
    if (target == null) {
      return false;
    }
    for (final id in _registryIdsForTap(action, target)) {
      if (!RecorderTargetRegistry.instance.hasTarget(id)) {
        continue;
      }
      await RecorderTargetRegistry.instance.activate(
        id,
        timeout: targetTimeout,
      );
      return true;
    }
    return false;
  }

  Future<bool> _delayWithStop(
    int waitMs, {
    bool Function()? shouldStop,
  }) async {
    var remaining = waitMs;
    while (remaining > 0) {
      if (shouldStop?.call() == true) {
        return false;
      }
      final chunk = remaining > 200 ? 200 : remaining;
      await Future<void>.delayed(Duration(milliseconds: chunk));
      remaining -= chunk;
    }
    return true;
  }

  Future<void> _replayOne(
    RecordedAction action, {
    required Duration targetTimeout,
    bool Function()? shouldStop,
  }) async {
    switch (action.type) {
      case RecordedActionType.tap:
        if (tryReplayAction != null) {
          final handled = await tryReplayAction!(
            action,
            shouldStop: shouldStop,
          );
          if (handled) {
            break;
          }
        }
        final target = action.target;
        if (target == null) {
          throw FormatException('Tap action missing target');
        }
        if (await _activateRegistryTap(
          action,
          targetTimeout: targetTimeout,
        )) {
          break;
        }
        final meta = action.metadata;
        final gx = meta['globalX'];
        final gy = meta['globalY'];
        if (gx is num && gy is num) {
          await replayCoordinateTap(
            Offset(gx.toDouble(), gy.toDouble()),
            shouldStop: shouldStop,
          );
          break;
        }
        final resolved = resolveReplayTapPosition?.call(action);
        if (resolved != null) {
          await replayCoordinateTap(resolved, shouldStop: shouldStop);
          break;
        }
        if (RecorderTargetRegistry.instance.hasTarget(target)) {
          await RecorderTargetRegistry.instance.activate(
            target,
            timeout: targetTimeout,
          );
          break;
        }
        throw TargetNotFoundException(target, targetTimeout);
      case RecordedActionType.textInput:
        final target = action.target;
        final text = action.text;
        if (target == null || text == null) {
          throw FormatException('Text input action missing target or text');
        }
        final meta = action.metadata;
        final gx = meta['globalX'];
        final gy = meta['globalY'];
        if (gx is num && gy is num) {
          await replayCoordinateTap(
            Offset(gx.toDouble(), gy.toDouble()),
            shouldStop: shouldStop,
          );
        } else if (RecorderTargetRegistry.instance.hasTarget(target)) {
          await RecorderTargetRegistry.instance.activate(
            target,
            timeout: targetTimeout,
          );
        }
        // Recorded [text] is in the session for QA evidence; filling fields
        // automatically is not supported for all Flutter inputs yet.
        break;
      case RecordedActionType.navigation:
        final replayNavigation = this.replayNavigation;
        if (replayNavigation == null) {
          throw StateError(
            'Configure BugSessionConfig.replayNavigation for navigation replay',
          );
        }
        await replayNavigation(action, shouldStop: shouldStop);
      case RecordedActionType.back:
        final replayNavigation = this.replayNavigation;
        if (replayNavigation == null) {
          throw StateError(
            'Configure BugSessionConfig.replayNavigation for back replay',
          );
        }
        await replayNavigation(action, shouldStop: shouldStop);
      case RecordedActionType.scroll:
      case RecordedActionType.swipe:
        break;
    }
  }
}
