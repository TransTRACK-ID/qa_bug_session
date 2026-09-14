import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_modal_context.dart';
import '../library/bug_session_catalog_entry.dart';
import '../replay/bug_session_replayer.dart';
import '../runtime/bug_session_environment.dart';
import 'bug_session_name_dialog.dart';
import 'bug_session_replay_flow.dart';
import 'bug_session_flight_log_sheet.dart';
import 'bug_session_share_helper.dart';
import 'bug_session_library_sheet.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';

class BugSessionSessionActions extends StatelessWidget {
  const BugSessionSessionActions({
    super.key,
    required this.kit,
    required this.entry,
    this.embedded = false,
  });

  final BugSessionKit kit;
  final BugSessionCatalogEntry entry;
  final bool embedded;

  void _popDetail(BuildContext context) {
    if (embedded) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.pop(context);
  }

  void _closeRootSheet(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  static Future<void> show(
    BuildContext context, {
    required BugSessionKit kit,
    required BugSessionCatalogEntry entry,
  }) {
    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: context,
    );
    return showModalBottomSheet<void>(
      context: modalContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BugSessionSessionActions(kit: kit, entry: entry),
    );
  }

  Future<BugSessionEnvironment?> _environment() async {
    await kit.config.refreshEnvironment?.call();
    return kit.config.environmentBuilder?.call();
  }

  Future<void> _replay(BuildContext context) async {
    await kit.config.refreshEnvironment?.call();
    final env = kit.config.environmentBuilder?.call();
    if (env == null) {
      _snack(context, 'Set BugSessionConfig.environmentBuilder');
      return;
    }
    final confirmed = await bugSessionConfirmReplay(
      kit,
      fallbackContext: context,
      sessionTitle: entry.displayName,
    );
    if (confirmed != true) {
      return;
    }
    bugSessionPopModalIfOpen(kit);
    if (context.mounted) {
      _closeRootSheet(context);
    }

    try {
      final session = await kit.catalog.loadSession(entry.sessionId);
      final warnings = kit.replayer.compatibilityWarnings(session, env);
      if (warnings.isNotEmpty && context.mounted) {
        kit.controlPanelLayout.collapse();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Compatibility warnings'),
            content: Text(warnings.map((w) => w.message).join('\n\n')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue')),
            ],
          ),
        );
        kit.controlPanelLayout.collapse();
      }
      final result = await bugSessionRunReplay(
        kit: kit,
        session: session,
        current: env,
      );
      if (result == null) return;
      if (context.mounted) {
        final message = result.cancelled
            ? 'Replay stopped (${result.actionsSucceeded}/${result.actionsAttempted})'
            : result.success
                ? 'Replay OK (${result.actionsSucceeded}/${result.actionsAttempted})'
                : 'Replay failed: ${result.failure?.reason}';
        _snack(context, message);
      }
    } on ReplayBlockedException catch (e) {
      if (context.mounted) _snack(context, e.flashMessage);
    }
  }

  Future<void> _export(BuildContext context) async {
    _snack(context, 'Preparing export (waiting for video if needed)…');
    final updated = await kit.catalog.exportSessionToDisk(entry.sessionId);
    if (!context.mounted) {
      return;
    }
    final path = updated.filePath;
    if (path != null &&
        kit.config.shareExport != null &&
        kit.config.openShareSheetAfterExport) {
      try {
        await shareBugSessionCatalogEntry(config: kit.config, entry: updated);
        _snack(context, 'Share sheet opened — pick WhatsApp or another app');
      } catch (e) {
        _snack(context, 'Export saved; share failed: $e');
      }
    } else {
      _snack(
        context,
        path != null ? 'Exported to app storage' : 'Exported to device storage',
      );
    }
    _popDetail(context);
  }

  Future<void> _share(BuildContext context) async {
    try {
      await shareBugSessionCatalogEntry(config: kit.config, entry: entry);
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Share failed: $e');
      }
    }
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showBugSessionRenameDialog(
      context,
      currentName: entry.displayName,
    );
    if (name == null || !context.mounted) {
      return;
    }
    await kit.catalog.renameSession(entry.sessionId, name);
    if (context.mounted) {
      _snack(context, 'Renamed to "$name"');
      _popDetail(context);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text(
          'Removes this catalog entry and any on-device zip (may contain credentials).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await kit.catalog.delete(entry.sessionId);
    kit.discardLastSessionIfDeleted(entry.sessionId);
    if (context.mounted) {
      _popDetail(context);
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = kit.config.resolvedTheme;
    final onDisk = entry.filePath != null;

    final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            GlassButton(
              theme: theme,
              label: 'Replay',
              filled: true,
              onPressed: () => _replay(context),
            ),
            const SizedBox(height: 8),
            GlassButton(
              theme: theme,
              label: 'What happened?',
              onPressed: () {
                if (embedded) {
                  Navigator.of(context).pushNamed(
                    BugSessionLibrarySheet.timelineRoute,
                    arguments: entry,
                  );
                  return;
                }
                BugSessionFlightLogSheet.showForEntry(
                  context,
                  kit: kit,
                  entry: entry,
                );
              },
            ),
            const SizedBox(height: 8),
            GlassButton(
              theme: theme,
              label: onDisk ? 'Already exported' : 'Export to device',
              filled: !onDisk,
              onPressed: onDisk ? null : () => _export(context),
            ),
            const SizedBox(height: 8),
            GlassButton(
              theme: theme,
              label: 'Share video + zip',
              filled: onDisk,
              onPressed: onDisk ? () => _share(context) : null,
            ),
            const SizedBox(height: 8),
            GlassButton(
              theme: theme,
              label: 'Rename',
              onPressed: () => _rename(context),
            ),
            const SizedBox(height: 8),
            GlassButton(
              theme: theme,
              label: 'Delete',
              onPressed: () => _delete(context),
            ),
          ],
        );

    if (embedded) {
      return SingleChildScrollView(child: body);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(theme: theme, child: body),
    );
  }
}
