import 'dart:ui';

import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';

class QaTestingPassDialog {
  QaTestingPassDialog._();

  static Future<bool?> show(BuildContext context, {required BugSessionKit kit}) {
    final theme = kit.config.resolvedTheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            content: GlassPanel(
              theme: theme,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Finish with no issues?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This uploads the session video to Jam, sets the card to '
                    'Archived, and posts PASSED ✅.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    theme: theme,
                    label: 'Confirm pass',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 6),
                  GlassButton(
                    theme: theme,
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
