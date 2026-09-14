import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../library/bug_session_catalog_entry.dart';
import 'bug_session_sheet_stack.dart';
import 'bug_session_timeline_view.dart';

/// "What happened?" timeline from saved sessions only (same sheet UX as library).
class BugSessionFlightLogSheet extends StatelessWidget {
  const BugSessionFlightLogSheet({super.key, required this.kit});

  final BugSessionKit kit;

  static const _listRoute = '/';
  static const _logRoute = '/log';

  static Future<void> show(
    BuildContext context, {
    required BugSessionKit kit,
  }) {
    return BugSessionSheetStack.show(
      context: context,
      kit: kit,
      title: 'What happened?',
      initialRoute: _listRoute,
      maxHeightFactor: 0.88,
      routes: {
        _listRoute: (ctx) => _BugSessionFlightLogPickerList(kit: kit),
        _logRoute: (ctx) {
          final entry = ModalRoute.of(ctx)!.settings.arguments
              as BugSessionCatalogEntry;
          return BugSessionTimelineForEntry(kit: kit, entry: entry);
        },
      },
    );
  }

  static Future<void> showForEntry(
    BuildContext context, {
    required BugSessionKit kit,
    required BugSessionCatalogEntry entry,
  }) {
    return BugSessionSheetStack.show(
      context: context,
      kit: kit,
      title: entry.displayName,
      initialRoute: _logRoute,
      initialArguments: entry,
      maxHeightFactor: 0.88,
      routes: {
        _listRoute: (ctx) => _BugSessionFlightLogPickerList(kit: kit),
        _logRoute: (ctx) {
          final e = ModalRoute.of(ctx)!.settings.arguments
              as BugSessionCatalogEntry;
          return BugSessionTimelineForEntry(kit: kit, entry: e);
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BugSessionFlightLogPickerList(kit: kit);
  }
}

class _BugSessionFlightLogPickerList extends StatelessWidget {
  const _BugSessionFlightLogPickerList({required this.kit});

  final BugSessionKit kit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BugSessionCatalogEntry>>(
      stream: kit.catalog.watchEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No saved sessions. Save a clip first.',
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
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    BugSessionFlightLogSheet._logRoute,
                    arguments: entry,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
