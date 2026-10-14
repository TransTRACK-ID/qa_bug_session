import 'dart:ui';

import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';

/// QA enters the exact status label from Notion when a preset is missing.
class NotionStatusInputDialog {
  NotionStatusInputDialog._();

  static Future<String?> show(
    BuildContext context, {
    required BugSessionKit kit,
    required String attemptedStatus,
    String? hint,
  }) {
    final theme = kit.config.resolvedTheme;
    final controller = TextEditingController(text: attemptedStatus);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
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
                    'Status not found in Notion',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hint ??
                        '“$attemptedStatus” is not an option on this database’s '
                        'Status property. Enter the exact name as shown in Notion.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Status name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    theme: theme,
                    label: 'Set status',
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        return;
                      }
                      Navigator.of(dialogContext).pop(value);
                    },
                  ),
                  const SizedBox(height: 6),
                  GlassButton(
                    theme: theme,
                    label: 'Cancel',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }
}
