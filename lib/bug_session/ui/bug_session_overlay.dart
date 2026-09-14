import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'bug_session_control_panel.dart';
import 'bug_session_interaction_capture_layer.dart';
import 'recording_overlay.dart';

/// Package-owned overlay stack (indicator + control panel).
class BugSessionOverlayStack extends StatelessWidget {
  const BugSessionOverlayStack({
    super.key,
    required this.kit,
    required this.child,
  });

  final BugSessionKit kit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        kit.chromeVisibility,
        kit.replayController,
      ]),
      builder: (context, _) {
        final showChrome = kit.chromeVisibility.visible;
        final showPanel = showChrome || kit.replayController.active;
        return Stack(
          fit: StackFit.expand,
          children: [
            BugSessionInteractionCaptureLayer(
              kit: kit,
              child: child,
            ),
            RecordingOverlay(
              kit: kit,
              theme: kit.config.resolvedTheme,
            ),
            if (showPanel) BugSessionControlPanel(kit: kit),
          ],
        );
      },
    );
  }
}
