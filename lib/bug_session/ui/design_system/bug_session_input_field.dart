import 'package:flutter/material.dart';

import '../../kit/bug_session_theme.dart';
import 'focus_bottom_sheet.dart';

class BugSessionInputField extends StatelessWidget {
  const BugSessionInputField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? initialValue;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BugSessionThemeData.defaults;
    return FocusBottomSheetField(
      label: label,
      fieldBuilder: (context, focusNode) {
        return TextFormField(
          focusNode: focusNode,
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: theme.panelTint.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.cornerRadius),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(theme.cornerRadius),
              borderSide: BorderSide(color: theme.borderColor),
            ),
          ),
        );
      },
    );
  }
}
