import '../models/network_event.dart';

abstract interface class NetworkRecorder {
  void startSession(String sessionId);

  void recordRequest(NetworkRequestEvent event);

  void recordResponse(NetworkResponseEvent event);

  void recordError(NetworkErrorEvent event);

  List<NetworkEvent> getEvents();

  void stopSession();
}

class InMemoryNetworkRecorder implements NetworkRecorder {
  String? _sessionId;
  final List<NetworkEvent> _events = [];

  @override
  void startSession(String sessionId) {
    _sessionId = sessionId;
    _events.clear();
  }

  int _elapsedMs(int? sessionStartMs) {
    if (sessionStartMs == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - sessionStartMs;
  }

  int? _startMs;

  void markSessionClockStart() {
    _startMs = DateTime.now().millisecondsSinceEpoch;
  }

  int elapsedMs() => _elapsedMs(_startMs);

  @override
  void recordRequest(NetworkRequestEvent event) {
    _events.add(NetworkEvent.request(event));
  }

  @override
  void recordResponse(NetworkResponseEvent event) {
    _events.add(NetworkEvent.response(event));
  }

  @override
  void recordError(NetworkErrorEvent event) {
    _events.add(NetworkEvent.error(event));
  }

  @override
  List<NetworkEvent> getEvents() => List.unmodifiable(_events);

  @override
  void stopSession() {
    _sessionId = null;
    _startMs = null;
  }

  String? get sessionId => _sessionId;
}
