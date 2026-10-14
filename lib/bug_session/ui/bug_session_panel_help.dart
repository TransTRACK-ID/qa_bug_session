import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_modal_context.dart';
import 'glass/glass_panel.dart';

Future<void> showBugSessionPanelHelp(
  BuildContext context, {
  required BugSessionKit kit,
  required int bufferSeconds,
  required bool dualCaptureModes,
}) {
  return kit.sheetCoordinator.runExclusive(kit, () async {
    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: context,
    );
    await showModalBottomSheet<void>(
      context: modalContext,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = kit.config.resolvedTheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 16,
          ),
          child: GlassPanel(
            theme: theme,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'QA capture guide',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dualCaptureModes) ...[
                    _helpBlock(
                      'Instant Replay (Shadowplay)',
                      'Always buffers the last $bufferSeconds seconds. '
                      'Save clip stores actions in the library; screen video is '
                      'uploaded to Jam.dev when configured (not kept on device).',
                    ),
                    _helpBlock(
                      'Full Record',
                      'Start → use the app → End session. Captures the full span '
                      '(Shadowplay pauses while recording). Video goes to Jam when '
                      'Ready to Test credentials are set.',
                    ),
                  ] else
                    _helpBlock(
                      'Recording',
                      'Capture actions for bug reports. Pair with Jam.dev in '
                      'Ready to Test for screen recordings.',
                    ),
                  _helpBlock(
                    'Save clip',
                    'Snapshot the rolling buffer to Saved sessions (actions + '
                    'timeline). Jam link is attached when PAT/team id are configured.',
                  ),
                  _helpBlock(
                    'Export / Replay last',
                    'Export shares a .zip (session data) plus a Jam recording link '
                    'in the share text—not a local MP4. Replay last re-runs the most '
                    'recent saved session on the live backend.',
                  ),
                  _helpBlock(
                    'Saved sessions',
                    'Browse sessions, open What happened?, replay, export, or share. '
                    'Card QA runs are saved here when you stop or complete testing.',
                  ),
                  _helpBlock(
                    'Test this card (Notion)',
                    'Issues upload video to Jam.dev and a BugSession replay .zip '
                    '(Notion file block or host URL) under Screenshoot. Re-open a '
                    'bug card to log another occurrence with a confirmation—no new '
                    'child card.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  });
}

Widget _helpBlock(String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
        ),
      ],
    ),
  );
}
