import 'package:flutter/material.dart';

import '../kit/bug_session_scope.dart';
import '../recording/bug_session_recorder.dart';
import '../runtime/recorder_target_registry.dart';

/// Semantic tap target — prefer ids like `checkout.submit` (Section 7).
class RecorderTap extends StatefulWidget {
  const RecorderTap({
    super.key,
    required this.id,
    required this.onPressed,
    required this.child,
    this.recorder,
  });

  final String id;
  final VoidCallback onPressed;
  final Widget child;
  final BugSessionRecorder? recorder;

  @override
  State<RecorderTap> createState() => _RecorderTapState();
}

class _RecorderTapState extends State<RecorderTap> {
  @override
  void initState() {
    super.initState();
    RecorderTargetRegistry.instance.register(widget.id, _activate);
  }

  @override
  void didUpdateWidget(covariant RecorderTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      RecorderTargetRegistry.instance.unregister(oldWidget.id);
      RecorderTargetRegistry.instance.register(widget.id, _activate);
    }
  }

  @override
  void dispose() {
    RecorderTargetRegistry.instance.unregister(widget.id);
    super.dispose();
  }

  Future<void> _activate() async {
    widget.onPressed();
  }

  void _handleTap() {
    final recorder = widget.recorder ?? context.bugSessionRecorder;
    recorder?.semantic.recordTap(widget.id);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
