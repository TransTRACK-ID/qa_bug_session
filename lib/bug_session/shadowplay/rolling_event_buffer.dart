import '../models/diagnostic_event.dart';
import '../models/network_event.dart';
import '../models/recorded_action.dart';
import 'shadowplay_mode.dart';

/// Time-based sliding window for session events (Shadowplay §2.1).
class RollingEventBuffer {
  RollingEventBuffer({
    required this.retention,
    required this.mode,
  });

  Duration retention;
  BugSessionShadowplayMode mode;

  final List<RecordedAction> _actions = [];
  final List<NetworkEvent> _network = [];
  final List<DiagnosticEvent> _diagnostics = [];
  int _clockStartMs = DateTime.now().millisecondsSinceEpoch;

  int elapsedMs() => DateTime.now().millisecondsSinceEpoch - _clockStartMs;

  void resetClock() {
    _clockStartMs = DateTime.now().millisecondsSinceEpoch;
    _actions.clear();
    _network.clear();
    _diagnostics.clear();
  }

  void addAction(RecordedAction action) {
    if (!_acceptsAction(action)) {
      return;
    }
    _actions.add(action);
    _evictActions();
  }

  void addNetwork(NetworkEvent event) {
    _network.add(event);
    _evictNetwork();
  }

  void addDiagnostic(DiagnosticEvent event) {
    _diagnostics.add(event);
    _evictDiagnostics();
  }

  bool _acceptsAction(RecordedAction action) {
    if (mode == BugSessionShadowplayMode.raw) {
      return true;
    }
    return switch (action.type) {
      RecordedActionType.tap ||
      RecordedActionType.textInput ||
      RecordedActionType.navigation ||
      RecordedActionType.back =>
        true,
      RecordedActionType.scroll ||
      RecordedActionType.swipe =>
        false,
    };
  }

  RollingEventSnapshot snapshot() {
    _evictActions();
    _evictNetwork();
    _evictDiagnostics();
    return RollingEventSnapshot(
      actions: List.unmodifiable(_actions),
      networkEvents: List.unmodifiable(_network),
      diagnostics: List.unmodifiable(_diagnostics),
      startedAtMs: _clockStartMs,
    );
  }

  void _evictActions() {
    final cutoff = elapsedMs() - retention.inMilliseconds;
    _actions.removeWhere((a) => a.timestampMs < cutoff);
  }

  void _evictNetwork() {
    final cutoff = elapsedMs() - retention.inMilliseconds;
    _network.removeWhere((e) => e.timestampMs < cutoff);
  }

  void _evictDiagnostics() {
    final cutoff = elapsedMs() - retention.inMilliseconds;
    _diagnostics.removeWhere((e) => e.timestampMs < cutoff);
  }
}

class RollingEventSnapshot {
  const RollingEventSnapshot({
    required this.actions,
    required this.networkEvents,
    required this.diagnostics,
    required this.startedAtMs,
  });

  final List<RecordedAction> actions;
  final List<NetworkEvent> networkEvents;
  final List<DiagnosticEvent> diagnostics;
  final int startedAtMs;
}
