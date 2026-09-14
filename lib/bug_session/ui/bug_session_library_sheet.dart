import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../library/bug_session_catalog_entry.dart';
import 'bug_session_session_actions.dart';
import 'bug_session_sheet_stack.dart';
import 'bug_session_timeline_view.dart';
import 'glass/glass_button.dart';

class BugSessionLibrarySheet extends StatelessWidget {
  const BugSessionLibrarySheet({super.key, required this.kit});

  final BugSessionKit kit;

  static const _listRoute = '/';
  static const _detailRoute = '/detail';
  static const timelineRoute = '/timeline';

  static Future<void> show(BuildContext context, {required BugSessionKit kit}) {
    return BugSessionSheetStack.show(
      context: context,
      kit: kit,
      title: 'Saved sessions',
      initialRoute: _listRoute,
      titleForRoute: (route, defaultTitle) {
        return switch (route) {
          _detailRoute => 'Session',
          timelineRoute => 'What happened?',
          _ => defaultTitle,
        };
      },
      routes: {
        _listRoute: (ctx) => _BugSessionLibraryList(kit: kit),
        _detailRoute: (ctx) {
          final entry = ModalRoute.of(ctx)!.settings.arguments
              as BugSessionCatalogEntry;
          return BugSessionSessionActions(
            kit: kit,
            entry: entry,
            embedded: true,
          );
        },
        timelineRoute: (ctx) {
          final entry = ModalRoute.of(ctx)!.settings.arguments
              as BugSessionCatalogEntry;
          return BugSessionTimelineForEntry(kit: kit, entry: entry);
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BugSessionLibraryList(kit: kit);
  }
}

class _BugSessionLibraryList extends StatelessWidget {
  const _BugSessionLibraryList({required this.kit});

  final BugSessionKit kit;

  @override
  Widget build(BuildContext context) {
    final theme = kit.config.resolvedTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: StreamBuilder<List<BugSessionCatalogEntry>>(
            stream: kit.catalog.watchEntries(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? [];
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No sessions yet. Save a clip or import a BugSession zip.',
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
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${entry.source.name} · v${entry.appVersion} · '
                        '${entry.actionCount} actions',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          BugSessionLibrarySheet._detailRoute,
                          arguments: entry,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<BugSessionCatalogEntry>>(
          stream: kit.catalog.watchEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const SizedBox.shrink();
            }
            return GlassButton(
              theme: theme,
              label: 'Clear all sessions',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all sessions?'),
                    content: const Text(
                      'Removes every saved session and any on-device '
                      'exports (may contain credentials).',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) {
                  return;
                }
                await kit.catalog.clearAll();
                kit.recorder.discardLastSession();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Exported zips may contain live credentials. Handle like passwords.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
