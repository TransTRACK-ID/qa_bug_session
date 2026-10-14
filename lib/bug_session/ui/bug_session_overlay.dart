import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'bug_session_control_panel.dart';
import 'bug_session_progress_banner.dart';
import 'bug_session_interaction_capture_layer.dart';
import 'bug_session_replay_chrome_passthrough.dart';
import 'qa_testing_objective_panel.dart';
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
        kit.qaTesting,
        kit.qaTestingChrome,
        kit.backgroundWork,
      ]),
      builder: (context, _) {
        final qaActive = kit.qaTesting.active;
        final hideRecordingChrome =
            qaActive && kit.config.hideRecordingChromeDuringQaTest;
        final replayActive = kit.replayController.active;
        final showChrome = kit.chromeVisibility.visible && !qaActive;
        final showControlPanel = showChrome && !qaActive;
        return Stack(
          fit: StackFit.expand,
          children: [
            BugSessionInteractionCaptureLayer(
              kit: kit,
              child: child,
            ),
            if (!hideRecordingChrome)
              RecordingOverlay(
                kit: kit,
                theme: kit.config.resolvedTheme,
              ),
            if (showControlPanel) BugSessionControlPanel(kit: kit),
            BugSessionReplayChromePassthrough(
              passthrough: replayActive,
              child: QaTestingObjectivePanel(kit: kit),
            ),
            BugSessionProgressBanner(kit: kit),
          ],
        );
      },
    );
  }
}
