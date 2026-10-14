import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'glass/glass_panel.dart';

/// Global top progress banner while [BugSessionKit.backgroundWork] is active.
class BugSessionProgressBanner extends StatelessWidget {
  const BugSessionProgressBanner({super.key, required this.kit});

  final BugSessionKit kit;

  @override
  Widget build(BuildContext context) {
    final theme = kit.config.resolvedTheme;
    return ListenableBuilder(
      listenable: kit.backgroundWork,
      builder: (context, _) {
        final work = kit.backgroundWork;
        if (!work.active) {
          return const SizedBox.shrink();
        }
        final percent = (work.progress * 100).round().clamp(0, 100);
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 559),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GlassPanel(
                    theme: theme,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                work.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: work.progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            color: theme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
