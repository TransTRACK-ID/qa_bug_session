import 'package:flutter/material.dart';

/// Checkbox row for glass panels (avoids [CheckboxListTile] + [DecoratedBox] assert).
class BugSessionTodoRow extends StatelessWidget {
  const BugSessionTodoRow({
    super.key,
    required this.checked,
    required this.text,
    required this.onChanged,
  });

  final bool checked;
  final String text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              value: checked,
              onChanged: (value) => onChanged(value ?? false),
              side: const BorderSide(color: Colors.white54),
              checkColor: Colors.black87,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.transparent;
              }),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!checked),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
