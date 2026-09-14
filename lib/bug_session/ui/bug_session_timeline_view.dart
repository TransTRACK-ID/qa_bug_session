import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../library/bug_session_catalog_entry.dart';
import '../models/bug_session.dart';
import '../runtime/timeline_builder.dart';
import '../runtime/timeline_presenter.dart';

/// Timeline for one saved catalog entry (shared by library + flight log sheets).
class BugSessionTimelineForEntry extends StatelessWidget {
  const BugSessionTimelineForEntry({
    super.key,
    required this.kit,
    required this.entry,
  });

  final BugSessionKit kit;
  final BugSessionCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BugSession>(
      future: kit.catalog.loadSession(entry.sessionId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load session: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        return BugSessionFlightLogView(session: snapshot.data!);
      },
    );
  }
}

class BugSessionFlightLogView extends StatelessWidget {
  const BugSessionFlightLogView({super.key, required this.session});

  final BugSession session;

  @override
  Widget build(BuildContext context) {
    final presenter = TimelinePresenter();
    final entries = TimelineBuilder().build(
      actions: session.actions,
      networkEvents: session.networkEvents,
      diagnostics: session.diagnostics,
      visualFrames: session.visualEvidence,
    );

    return entries.isEmpty
        ? const Center(
            child: Text(
              'No timeline entries.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 16, color: Colors.white12),
            itemBuilder: (context, index) {
              final line = presenter.formatLine(entries[index]);
              return Text(
                line,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.35,
                ),
              );
            },
          );
  }
}
