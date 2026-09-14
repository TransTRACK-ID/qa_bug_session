import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_modal_context.dart';
import '../models/bug_session.dart';
import '../replay/bug_session_replayer.dart';
import '../replay/replay_result.dart';
import '../runtime/bug_session_environment.dart';

void bugSessionHideChrome(BugSessionKit kit) {
  kit.chromeVisibility.hide();
}

void bugSessionRestoreReplayUi(BugSessionKit kit) {
  kit.chromeVisibility.show();
}

void bugSessionPopModalIfOpen(BugSessionKit kit) {
  final nav = kit.config.navigatorKey?.currentState;
  if (nav != null && nav.canPop()) {
    nav.pop();
  }
}

Future<bool> bugSessionConfirmReplay(
  BugSessionKit kit, {
  required BuildContext fallbackContext,
  String? sessionTitle,
}) async {
  kit.controlPanelLayout.collapse();
  kit.chromeVisibility.hide();
  final modalContext = requireBugSessionModalContext(
    kit.config,
    fallback: fallbackContext,
  );
  final confirmed = await showDialog<bool>(
        context: modalContext,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Replay BugSession?'),
          content: Text(
            sessionTitle == null
                ? 'Replay runs live actions against the real backend using '
                    'credentials from the session file. Shadowplay pauses '
                    'until replay finishes.'
                : 'Replay "$sessionTitle" against the live backend? '
                    'Shadowplay pauses until replay finishes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replay'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) {
    kit.chromeVisibility.show();
    return false;
  }
  // Chrome is hidden for the dialog; start replay UI so the FAB strip stays up
  // (overlay uses [replayController.active] when chrome is hidden).
  kit.replayController.begin();
  return true;
}

Future<ReplayResult?> bugSessionRunReplay({
  required BugSessionKit kit,
  required BugSession session,
  required BugSessionEnvironment current,
  void Function(String message)? onLockFailureFlash,
}) async {
  kit.controlPanelLayout.collapse();
  await kit.recorder.suspendShadowplayCapture();
  kit.replayController.begin();
  ReplayResult? result;
  try {
    result = await kit.replayer.replay(
      session: session,
      current: current,
      onLockFailureFlash: onLockFailureFlash,
      shouldStop: () => kit.replayController.stopRequested,
    );
    return result;
  } finally {
    kit.replayController.end();
    await kit.recorder.resumeShadowplayCapture();
    kit.chromeVisibility.show();
    kit.controlPanelLayout.collapse();
    if (result != null) {
      await kit.config.onReplayFinished?.call(result);
    }
  }
}
