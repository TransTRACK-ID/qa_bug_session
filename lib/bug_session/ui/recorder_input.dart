import 'dart:async';

import 'package:flutter/material.dart';

import '../kit/bug_session_scope.dart';
import '../recording/bug_session_recorder.dart';
import '../runtime/text_input_target_registry.dart';

/// Wraps a text field subtree for BugSession text capture and replay fill.
///
/// Records every settled controller value after [recordDebounce], including
/// empty strings (deletes/clears). Flushes immediately on focus loss.
class RecorderInput extends StatefulWidget {
  const RecorderInput({
    super.key,
    required this.id,
    required this.controller,
    required this.child,
    this.onChanged,
    this.recorder,
    this.screenRoute,
    this.semanticsLabel,
    this.recordDebounce = const Duration(milliseconds: 300),
  });

  final String id;
  final TextEditingController controller;
  final Widget child;
  final ValueChanged<String>? onChanged;
  final BugSessionRecorder? recorder;
  final String? screenRoute;
  final String? semanticsLabel;
  final Duration recordDebounce;

  @override
  State<RecorderInput> createState() => _RecorderInputState();
}

class _RecorderInputState extends State<RecorderInput> {
  Timer? _debounce;
  String _lastRecordedText = '';
  final FocusNode _focusNode = FocusNode(debugLabel: 'RecorderInput');

  @override
  void initState() {
    super.initState();
    TextInputTargetRegistry.instance.register(widget.id, _applyText);
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RecorderInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      TextInputTargetRegistry.instance.unregister(oldWidget.id);
      TextInputTargetRegistry.instance.register(widget.id, _applyText);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    TextInputTargetRegistry.instance.unregister(widget.id);
    super.dispose();
  }

  Future<void> _applyText(String text) async {
    widget.controller.text = text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
    widget.onChanged?.call(text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      return;
    }
    _debounce?.cancel();
    _flushRecordedText();
  }

  void _onControllerChanged() {
    final recorder = widget.recorder ?? context.bugSessionRecorder;
    if (recorder == null || !recorder.isCapturing) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(widget.recordDebounce, () {
      if (!mounted) {
        return;
      }
      _flushRecordedText();
    });
  }

  void _flushRecordedText() {
    final recorder = widget.recorder ?? context.bugSessionRecorder;
    if (recorder == null || !recorder.isCapturing) {
      return;
    }
    final text = widget.controller.text;
    if (text == _lastRecordedText) {
      return;
    }
    _lastRecordedText = text;
    recorder.recordCapturedTextInput(
      widget.id,
      text,
      metadata: {
        'recorderId': widget.id,
        if (widget.screenRoute != null && widget.screenRoute!.isNotEmpty)
          'screenRoute': widget.screenRoute!,
        if (widget.semanticsLabel != null &&
            widget.semanticsLabel!.isNotEmpty)
          'semanticsLabel': widget.semanticsLabel!,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Semantics(
        identifier: widget.id,
        label: widget.semanticsLabel,
        child: widget.child,
      ),
    );
  }
}
