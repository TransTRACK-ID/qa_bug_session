import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const _boringWidgetTypes = {
  'AbsorbPointer',
  'Align',
  'AnimatedBuilder',
  'AnimatedDefaultTextStyle',
  'AspectRatio',
  'BackdropFilter',
  'Baseline',
  'BlockSemantics',
  'ClipOval',
  'ClipPath',
  'ClipRRect',
  'ClipRect',
  'ColoredBox',
  'CompositedTransformTarget',
  'ConstrainedBox',
  'Container',
  'CustomPaint',
  'DecoratedBox',
  'DefaultTextStyle',
  'Dismissible',
  'ExcludeSemantics',
  'Expanded',
  'Flexible',
  'Focus',
  'GestureDetector',
  'IgnorePointer',
  'InkWell',
  'Listener',
  'Material',
  'MergeSemantics',
  'MouseRegion',
  'Offstage',
  'Opacity',
  'Padding',
  'PhysicalModel',
  'Positioned',
  'RawGestureDetector',
  'RepaintBoundary',
  'RichText',
  'RotatedBox',
  'SafeArea',
  'Semantics',
  'SingleChildScrollView',
  'SizedBox',
  'SliverToBoxAdapter',
  'Stack',
  'Text',
  'Transform',
  'Visibility',
  'Wrap',
};

/// Deepest meaningful widget [Type] name at [global] (e.g. CustomTaskCardViewWidget).
String? widgetTypeAtGlobal(Offset global, BuildContext context) {
  final result = HitTestResult();
  final view = View.of(context);
  WidgetsBinding.instance.hitTestInView(result, global, view.viewId);

  for (final entry in result.path) {
    final typeName = _widgetTypeNameFromTarget(entry.target);
    if (typeName == null) {
      continue;
    }
    if (typeName.isEmpty || typeName.startsWith('_')) {
      continue;
    }
    if (_boringWidgetTypes.contains(typeName)) {
      continue;
    }
    if (typeName.endsWith('Page') ||
        typeName.endsWith('Widget') ||
        typeName.endsWith('View') ||
        typeName.endsWith('Card') ||
        typeName.endsWith('Tile') ||
        typeName.endsWith('Button') ||
        typeName.endsWith('Bar') ||
        typeName.endsWith('Field') ||
        typeName.endsWith('Item')) {
      return typeName;
    }
  }

  for (final entry in result.path) {
    final typeName = _widgetTypeNameFromTarget(entry.target);
    if (typeName == null) {
      continue;
    }
    if (typeName.isEmpty ||
        typeName.startsWith('_') ||
        _boringWidgetTypes.contains(typeName)) {
      continue;
    }
    return typeName;
  }

  return null;
}

String? _widgetTypeNameFromTarget(HitTestTarget target) {
  if (target is! RenderObject) {
    return null;
  }
  final creator = target.debugCreator;
  if (creator is! DebugCreator) {
    return null;
  }
  return creator.element.widget.runtimeType.toString();
}
