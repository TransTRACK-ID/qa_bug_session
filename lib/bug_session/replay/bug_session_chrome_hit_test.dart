import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// True when [global] hits BugSession overlay chrome (FAB panel, etc.).
bool bugSessionChromeHitAt(Offset global) {
  final binding = WidgetsBinding.instance;
  final views = binding.platformDispatcher.views;
  if (views.isEmpty) {
    return false;
  }
  for (final view in views) {
    final result = HitTestResult();
    binding.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsAnnotations) {
        final label = target.properties.label;
        if (label == 'BugSession') {
          return true;
        }
      }
    }
  }
  return false;
}
