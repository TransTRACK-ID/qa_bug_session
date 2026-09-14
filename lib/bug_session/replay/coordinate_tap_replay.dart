import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'bug_session_chrome_hit_test.dart';

/// Dispatches synthetic pointer events at [globalPosition] (replay taps).
Future<void> replayCoordinateTap(
  Offset globalPosition, {
  bool Function()? shouldStop,
}) async {
  if (bugSessionChromeHitAt(globalPosition)) {
    return;
  }
  final binding = WidgetsBinding.instance;
  const pointer = 24;
  binding.handlePointerEvent(
    PointerDownEvent(pointer: pointer, position: globalPosition),
  );
  await binding.endOfFrame;
  if (shouldStop?.call() == true) {
    return;
  }
  if (bugSessionChromeHitAt(globalPosition)) {
    return;
  }
  binding.handlePointerEvent(
    PointerUpEvent(pointer: pointer, position: globalPosition),
  );
  await binding.endOfFrame;
}
