import 'dart:async';

import 'package:flutter/widgets.dart';

class BugSessionTapRipple {
  BugSessionTapRipple({
    required this.globalPosition,
    required this.createdAt,
  });

  final Offset globalPosition;
  final DateTime createdAt;
}

/// Tap markers burned into screen recording (GIF) while QA records.
class BugSessionTapRippleNotifier extends ChangeNotifier {
  final List<BugSessionTapRipple> _ripples = [];
  Timer? _pruneTimer;

  List<BugSessionTapRipple> get ripples => List.unmodifiable(_ripples);

  void recordTap(Offset globalPosition) {
    _ripples.add(
      BugSessionTapRipple(
        globalPosition: globalPosition,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _pruneTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      _prune();
    });
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(milliseconds: 750));
    final before = _ripples.length;
    _ripples.removeWhere((r) => r.createdAt.isBefore(cutoff));
    if (_ripples.length != before) {
      notifyListeners();
    }
    if (_ripples.isEmpty) {
      _pruneTimer?.cancel();
      _pruneTimer = null;
    }
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    super.dispose();
  }
}
