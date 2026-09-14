import '../models/diagnostic_event.dart';
import '../models/network_event.dart';
import '../models/recorded_action.dart';
import 'rolling_event_buffer.dart';
import 'shadowplay_settings.dart';

/// Always-on rolling capture; [saveSnapshot] materializes a permanent session slice.
class BugSessionShadowplayEngine {
  BugSessionShadowplayEngine(this.settings)
      : _buffer = RollingEventBuffer(
          retention: settings.eventRetentionFor(settings.mode),
          mode: settings.mode,
        );

  BugSessionShadowplaySettings settings;
  final RollingEventBuffer _buffer;
  bool _active = false;

  bool get isActive => _active;

  void start() {
    _active = true;
    _buffer.resetClock();
    _buffer.retention = settings.eventRetentionFor(settings.mode);
    _buffer.mode = settings.mode;
  }

  void setMode(BugSessionShadowplaySettings newSettings) {
    settings = newSettings;
    if (_active) {
      _buffer.retention = settings.eventRetentionFor(settings.mode);
      _buffer.mode = settings.mode;
    }
  }

  int elapsedMs() => _buffer.elapsedMs();

  void recordAction(RecordedAction action) {
    if (!_active) {
      return;
    }
    _buffer.addAction(action);
  }

  void recordNetwork(NetworkEvent event) {
    if (!_active) {
      return;
    }
    _buffer.addNetwork(event);
  }

  void recordDiagnostic(DiagnosticEvent event) {
    if (!_active) {
      return;
    }
    _buffer.addDiagnostic(event);
  }

  RollingEventSnapshot snapshot() => _buffer.snapshot();
}
