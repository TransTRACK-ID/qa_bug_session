import 'dart:ui';

import 'package:flutter/material.dart';

import '../../kit/bug_session_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final BugSessionThemeData theme;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cornerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.blurSigma,
          sigmaY: theme.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.panelTint,
            borderRadius: BorderRadius.circular(theme.cornerRadius),
            border: Border.all(color: theme.borderColor),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
