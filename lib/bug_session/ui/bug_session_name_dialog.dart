import 'package:flutter/material.dart';

/// Optional QA label after stopping a recording.
Future<String?> showBugSessionNameDialog(BuildContext context) {
  return showDialog<String?>(
    context: context,
    builder: (ctx) => const _BugSessionNameDialog(),
  );
}

Future<String?> showBugSessionRenameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<String?>(
    context: context,
    builder: (ctx) => _BugSessionRenameDialog(initialName: currentName),
  );
}

class _BugSessionNameDialog extends StatefulWidget {
  const _BugSessionNameDialog();

  @override
  State<_BugSessionNameDialog> createState() => _BugSessionNameDialogState();
}

class _BugSessionNameDialogState extends State<_BugSessionNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this session'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Optional — e.g. Login → task filter bug',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BugSessionRenameDialog extends StatefulWidget {
  const _BugSessionRenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_BugSessionRenameDialog> createState() => _BugSessionRenameDialogState();
}

class _BugSessionRenameDialogState extends State<_BugSessionRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename session'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          final text = _controller.text.trim();
          Navigator.pop(context, text.isEmpty ? null : text);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, text.isEmpty ? null : text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
