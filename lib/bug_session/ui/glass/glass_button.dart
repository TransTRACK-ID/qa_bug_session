import 'package:flutter/material.dart';

import '../../kit/bug_session_theme.dart';
import 'glass_panel.dart';

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.expand = false,
  });

  final BugSessionThemeData theme;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final child = Text(
      label,
      style: TextStyle(
        color: filled
            ? Colors.black87
            : (enabled ? Colors.white : Colors.white54),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );

    Widget button;
    if (filled && enabled) {
      button = Material(
        color: theme.accent.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(theme.cornerRadius - 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(theme.cornerRadius - 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Center(child: child),
          ),
        ),
      );
    } else {
      button = Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GlassPanel(
          theme: theme,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: InkWell(
            onTap: onPressed,
            child: Center(child: child),
          ),
        ),
      );
    }

    if (!expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
