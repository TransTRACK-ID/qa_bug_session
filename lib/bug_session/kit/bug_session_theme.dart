import 'package:flutter/material.dart';

/// Frosted overlay styling — hosts may override; no design-system dependency.
@immutable
class BugSessionThemeData {
  const BugSessionThemeData({
    this.blurSigma = 18,
    this.panelTint = const Color(0xCC1A1A1F),
    this.accent = const Color(0xFFE8E8ED),
    this.cornerRadius = 16,
    this.borderColor = const Color(0x33FFFFFF),
  });

  final double blurSigma;
  final Color panelTint;
  final Color accent;
  final double cornerRadius;
  final Color borderColor;

  static const BugSessionThemeData defaults = BugSessionThemeData();
}
