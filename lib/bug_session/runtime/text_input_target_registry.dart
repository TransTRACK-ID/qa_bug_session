import 'dart:async';

typedef TextInputApply = Future<void> Function(String text);

/// Maps semantic input ids to controller fill handlers during replay.
class TextInputTargetRegistry {
  TextInputTargetRegistry._();

  static final TextInputTargetRegistry instance = TextInputTargetRegistry._();

  final Map<String, TextInputApply> _handlers = {};

  void register(String id, TextInputApply apply) {
    _handlers[id] = apply;
  }

  void unregister(String id) {
    _handlers.remove(id);
  }

  bool hasTarget(String id) => _handlers.containsKey(id);

  Future<void> apply(
    String id,
    String text, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final handler = _handlers[id];
      if (handler != null) {
        await handler(text);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw TextInputTargetNotFoundException(id, timeout);
  }
}

class TextInputTargetNotFoundException implements Exception {
  TextInputTargetNotFoundException(this.targetId, this.timeout);

  final String targetId;
  final Duration timeout;

  @override
  String toString() =>
      'Text input "$targetId" was not registered within ${timeout.inSeconds} seconds.';
}
