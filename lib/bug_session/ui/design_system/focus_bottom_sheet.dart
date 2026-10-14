import 'package:flutter/material.dart';

/// Opens a focused bottom sheet for a single field (always used in this package).
class FocusBottomSheetField extends StatefulWidget {
  const FocusBottomSheetField({
    super.key,
    required this.fieldBuilder,
    this.label,
  });

  final Widget Function(BuildContext context, FocusNode focusNode) fieldBuilder;
  final String? label;

  @override
  State<FocusBottomSheetField> createState() => _FocusBottomSheetFieldState();
}

class _FocusBottomSheetFieldState extends State<FocusBottomSheetField> {
  final _focusNode = FocusNode();

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.label != null && widget.label!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              widget.fieldBuilder(context, _focusNode),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSheet,
      behavior: HitTestBehavior.opaque,
      child: AbsorbPointer(
        child: widget.fieldBuilder(context, _focusNode),
      ),
    );
  }
}
