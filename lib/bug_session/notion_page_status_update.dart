import 'package:flutter/widgets.dart';

import 'kit/bug_session_kit.dart';
import 'kit/bug_session_modal_context.dart';
import '../notion/notion_api.dart';
import '../notion/notion_ready_to_test.dart';
import 'ui/notion_status_input_dialog.dart';

/// Updates page status; prompts for a custom label when [NotionTaskStatusService]
/// reports `unknown_status`.
Future<void> updateNotionPageStatusResolving({
  required BugSessionKit kit,
  required NotionClient client,
  required String pageId,
  required String status,
  String? statusPropertyOverride,
  BuildContext? fallbackContext,
}) async {
  final service = NotionTaskStatusService(client);
  try {
    await service.updateStatus(
      pageId: pageId,
      newStatus: status,
      statusPropertyOverride: statusPropertyOverride,
    );
  } on NotionApiException catch (e) {
    if (e.code != 'unknown_status') {
      throw e;
    }
    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: fallbackContext,
    );
    final custom = await NotionStatusInputDialog.show(
      modalContext,
      kit: kit,
      attemptedStatus: status,
    );
    if (custom == null || custom.trim().isEmpty) {
      throw NotionApiException(
        code: 'status_cancelled',
        message: 'Status update cancelled',
      );
    }
    await service.updateStatus(
      pageId: pageId,
      newStatus: custom.trim(),
      statusPropertyOverride: statusPropertyOverride,
    );
  }
}
