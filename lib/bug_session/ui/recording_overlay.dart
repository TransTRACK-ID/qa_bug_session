import 'dart:async';

import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_theme.dart';
import '../recording/bug_session_recorder.dart';
import '../replay/bug_session_replay_controller.dart';
import 'bug_session_capture_mode.dart';

/// Top-right status: Shadowplay buffer, manual record, or replay.
class RecordingOverlay extends StatelessWidget {
  const RecordingOverlay({
    super.key,
    required this.kit,
    this.child,
    this.theme,
  });

  final BugSessionKit kit;
  final Widget? child;
  final BugSessionThemeData? theme;

  static String? statusLabel({
    required BugSessionRecorder recorder,
    required BugSessionReplayController replay,
    required BugSessionCaptureMode captureMode,
  }) {
    if (replay.active) {
      return 'REPLAY';
    }
    if (recorder.state == BugSessionRecorderState.stopping) {
      return 'Saving';
    }
    if (recorder.isRecording) {
      return 'RECORD';
    }
    if (captureMode.isInstantReplay && recorder.isShadowplayBuffering) {
      return 'SHADOWPLAY';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        kit.recorder,
        kit.replayController,
        kit.captureMode,
      ]),
      builder: (context, _) {
        final label = statusLabel(
          recorder: kit.recorder,
          replay: kit.replayController,
          captureMode: kit.captureMode,
        );
        if (label == null) {
          return child ?? const SizedBox.shrink();
        }

        return Stack(
          children: [
            if (child != null) child!,
            Positioned(
              top: MediaQuery.paddingOf(context).top + 10,
              right: 12,
              child: _RecordingStatusBadge(
                recorder: kit.recorder,
                replayController: kit.replayController,
                label: label,
                replayActive: kit.replayController.active,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordingStatusBadge extends StatefulWidget {
  const _RecordingStatusBadge({
    required this.recorder,
    required this.replayController,
    required this.label,
    required this.replayActive,
  });

  final BugSessionRecorder recorder;
  final BugSessionReplayController replayController;
  final String label;
  final bool replayActive;

  @override
  State<_RecordingStatusBadge> createState() => _RecordingStatusBadgeState();
}

class _RecordingStatusBadgeState extends State<_RecordingStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (widget.recorder.isRecording &&
          widget.recorder.state == BugSessionRecorderState.recording) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _formatClock(Duration? elapsed) {
    if (elapsed == null) {
      return '';
    }
    final s = elapsed.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.replayActive
        ? ''
        : _formatClock(widget.recorder.recordingElapsed);
    final dotColor = widget.replayActive
        ? const Color(0xFF64D2FF)
        : const Color(0xFFFF453A);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF0121214),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.45, end: 1).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFFF2F2F7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            if (clock.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                clock,
                style: const TextStyle(
                  color: Color(0xB3F2F2F7),
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
