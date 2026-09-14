import '../models/network_event.dart';
import 'network_correlator.dart';

class SessionComparison {
  SessionComparison({
    required this.networkPairs,
    required this.summaryMessage,
  });

  final List<CorrelatedNetworkPair> networkPairs;
  final String summaryMessage;

  int get responseDifferences =>
      networkPairs.where((p) => p.hasResponseDifference).length;
}

class SessionComparator {
  SessionComparator({NetworkCorrelator? correlator})
      : _correlator = correlator ?? NetworkCorrelator();

  final NetworkCorrelator _correlator;

  SessionComparison compare({
    required List<NetworkEvent> originalNetwork,
    required List<NetworkEvent> replayNetwork,
  }) {
    final pairs = _correlator.correlate(
      originalEvents: originalNetwork,
      replayEvents: replayNetwork,
    );
    final diffs = pairs.where((p) => p.hasResponseDifference).length;
    final message = diffs == 0
        ? 'The same recorded action sequence was replayed. '
            'Observed network responses match the original session.'
        : 'The same recorded action sequence was replayed. '
            'The observed response differs from the original session '
            'for $diffs request(s). Further investigation required.';
    return SessionComparison(networkPairs: pairs, summaryMessage: message);
  }
}
