import '../comparison/session_comparator.dart';
import '../models/network_event.dart';
import 'replay_failure.dart';

class ReplayResult {
  ReplayResult({
    required this.actionsAttempted,
    required this.actionsSucceeded,
    required this.replayNetworkEvents,
    this.failure,
    this.comparison,
    this.cancelled = false,
  });

  final int actionsAttempted;
  final int actionsSucceeded;
  final List<NetworkEvent> replayNetworkEvents;
  final ReplayFailure? failure;
  final SessionComparison? comparison;
  final bool cancelled;

  bool get success =>
      !cancelled &&
      failure == null &&
      actionsSucceeded == actionsAttempted;
}
