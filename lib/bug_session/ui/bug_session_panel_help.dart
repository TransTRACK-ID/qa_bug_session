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
                      'Use Save clip to export actions + real-time video without '
                      'stopping your work.',
                    ),
                    _helpBlock(
                      'Full Record',
                      'Start → use the app → End session. Saves the whole span '
                      'with video (Shadowplay pauses while recording).',
                    ),
                  ] else
                    _helpBlock(
                      'Recording',
                      'Capture actions and video for bug reports.',
                    ),
                  _helpBlock(
                    'Save clip',
                    'Snapshot the rolling buffer to the library (name + MP4).',
                  ),
                  _helpBlock(
                    'Export / Replay last',
                    'Export shares zip + video. Replay last re-runs the most '
                    'recent saved clip on the live backend.',
                  ),
                  _helpBlock(
                    'Saved sessions',
                    'Browse clips, open What happened?, replay, export, or share.',
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
