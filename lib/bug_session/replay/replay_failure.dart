import '../models/recorded_action.dart';

class ReplayFailure {
  ReplayFailure({
    required this.actionIndex,
    required this.action,
    required this.reason,
  });

  final int actionIndex;
  final RecordedAction action;
  final String reason;
}
