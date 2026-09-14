import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_modal_context.dart';
import '../library/bug_session_catalog_entry.dart';
import 'glass/glass_panel.dart';

/// Pick a catalog session (flight log, etc.).
class BugSessionSessionPickerSheet extends StatelessWidget {
  const BugSessionSessionPickerSheet({
    super.key,
    required this.kit,
    required this.title,
    required this.onSelected,
  });

  final BugSessionKit kit;
  final String title;
  final Future<void> Function(BugSessionCatalogEntry entry) onSelected;

  static Future<void> show(
    BuildContext context, {
    required BugSessionKit kit,
    required String title,
    required Future<void> Function(BugSessionCatalogEntry entry) onSelected,
  }) {
    return kit.sheetCoordinator.runExclusive(kit, () async {
      final modalContext = requireBugSessionModalContext(
        kit.config,
        fallback: context,
      );
      await showModalBottomSheet<void>(
        context: modalContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => BugSessionSessionPickerSheet(
          kit: kit,
          title: title,
          onSelected: onSelected,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = kit.config.resolvedTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GlassPanel(
            theme: theme,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: StreamBuilder<List<BugSessionCatalogEntry>>(
                    stream: kit.catalog.watchEntries(),
                    builder: (context, snapshot) {
                      final entries = snapshot.data ?? [];
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No saved sessions.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${entry.actionCount} actions · v${entry.appVersion}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await onSelected(entry);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
