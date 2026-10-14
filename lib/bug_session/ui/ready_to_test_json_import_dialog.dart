import 'package:flutter/material.dart';

import '../../notion/ready_to_test_connection_import.dart';
import '../kit/bug_session_kit.dart';
import 'glass/glass_button.dart';

/// Modal to paste Ready to Test + Jam credentials as JSON.
Future<ReadyToTestConnectionImport?> showReadyToTestJsonImportDialog({
  required BuildContext context,
  required BugSessionKit kit,
}) {
  return showDialog<ReadyToTestConnectionImport>(
    context: context,
    builder: (ctx) => _ReadyToTestJsonImportDialog(kit: kit),
  );
}

class _ReadyToTestJsonImportDialog extends StatefulWidget {
  const _ReadyToTestJsonImportDialog({required this.kit});

  final BugSessionKit kit;

  @override
  State<_ReadyToTestJsonImportDialog> createState() =>
      _ReadyToTestJsonImportDialogState();
}

class _ReadyToTestJsonImportDialogState
    extends State<_ReadyToTestJsonImportDialog> {
  final _json = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E28),
      title: const Text(
        'Import connection JSON',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste one JSON object with Notion + Jam fields. '
                'Recognized keys include notion_token, data_source_id, '
                'qa_user_id, jam_personal_access_token, jam_team_id '
                '(or nested "notion" / "jam" objects).',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _json,
                maxLines: 14,
                autocorrect: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                decoration: InputDecoration(
                  hintText: readyToTestConnectionImportExampleJson.trim(),
                  hintStyle: TextStyle(
                    color: Colors.white24,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GlassButton(
          theme: theme,
          label: 'Fill fields',
          onPressed: _fill,
        ),
      ],
    );
  }

  void _fill() {
    try {
      final parsed = parseReadyToTestConnectionImport(_json.text);
      Navigator.of(context).pop(parsed);
    } on ReadyToTestConnectionImportException catch (e) {
      setState(() => _error = e.message);
    }
  }
}
