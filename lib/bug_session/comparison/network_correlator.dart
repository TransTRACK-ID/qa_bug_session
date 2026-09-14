import '../models/network_event.dart';

class CorrelatedNetworkPair {
  CorrelatedNetworkPair({
    required this.original,
    this.replay,
  });

  final NetworkResponseEvent original;
  final NetworkResponseEvent? replay;

  bool get hasResponseDifference =>
      replay != null && replay!.statusCode != original.statusCode;
}

/// Correlates QA vs replay network observations (Section 20).
class NetworkCorrelator {
  List<CorrelatedNetworkPair> correlate({
    required List<NetworkEvent> originalEvents,
    required List<NetworkEvent> replayEvents,
  }) {
    final originalResponses = originalEvents
        .where((e) => e.kind == NetworkEventKind.response)
        .map((e) => e.response!)
        .toList();
    final replayResponses = replayEvents
        .where((e) => e.kind == NetworkEventKind.response)
        .map((e) => e.response!)
        .toList();

    final usedReplay = <int>{};
    final pairs = <CorrelatedNetworkPair>[];

    for (final original in originalResponses) {
      final index = _findBestReplayIndex(
        original,
        replayResponses,
        usedReplay,
      );
      if (index != null) {
        usedReplay.add(index);
        pairs.add(
          CorrelatedNetworkPair(
            original: original,
            replay: replayResponses[index],
          ),
        );
      } else {
        pairs.add(CorrelatedNetworkPair(original: original));
      }
    }

    return pairs;
  }

  int? _findBestReplayIndex(
    NetworkResponseEvent original,
    List<NetworkResponseEvent> replayResponses,
    Set<int> used,
  ) {
    for (var i = 0; i < replayResponses.length; i++) {
      if (used.contains(i)) continue;
      final candidate = replayResponses[i];
      if (original.correlationId != null &&
          original.correlationId == candidate.correlationId) {
        return i;
      }
    }
    for (var i = 0; i < replayResponses.length; i++) {
      if (used.contains(i)) continue;
      final candidate = replayResponses[i];
      if (candidate.method == original.method &&
          _normalizeUrl(candidate.url) == _normalizeUrl(original.url)) {
        return i;
      }
    }
    return null;
  }

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return Uri(
        path: uri.path,
        query: uri.query.isEmpty ? null : uri.query,
      ).toString();
    } catch (_) {
      return url;
    }
  }
}
