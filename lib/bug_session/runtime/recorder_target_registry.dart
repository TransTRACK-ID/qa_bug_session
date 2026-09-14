import 'dart:async';

import 'package:flutter/foundation.dart';

typedef TargetActivator = Future<void> Function();

/// Maps semantic recorder ids (e.g. `checkout.submit`) to replay handlers.
class RecorderTargetRegistry {
  RecorderTargetRegistry._();

  static final RecorderTargetRegistry instance = RecorderTargetRegistry._();

  final Map<String, TargetActivator> _activators = {};

  void register(String id, TargetActivator activator) {
    _activators[id] = activator;
  }

  void unregister(String id) {
    _activators.remove(id);
  }

  bool hasTarget(String id) => _activators.containsKey(id);

  Future<void> activate(
    String id, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final activator = _activators[id];
      if (activator != null) {
        await activator();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw TargetNotFoundException(id, timeout);
  }
}

class TargetNotFoundException implements Exception {
  TargetNotFoundException(this.targetId, this.timeout);

  final String targetId;
  final Duration timeout;

  @override
  String toString() =>
      'Target "$targetId" was not found within ${timeout.inSeconds} seconds.';
}
