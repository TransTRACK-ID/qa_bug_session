import '../models/recorded_action.dart';

/// Adapter boundary — do not depend on third-party recorders outside impls.
abstract interface class InteractionRecorder {
  Future<void> start(String sessionId);

  Future<RecordedActions> stop();

  Future<int> replay(
    RecordedActions actions, {
    Duration targetTimeout = const Duration(seconds: 10),
    void Function(RecordedAction action, Object error)? onActionFailed,
    bool Function()? shouldStop,
  });
}
