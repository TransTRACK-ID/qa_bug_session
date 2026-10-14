import 'package:flutter/material.dart';

import '../kit/bug_session_background_work.dart';
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

class _BugSessionLibraryList extends StatefulWidget {
  const _BugSessionLibraryList({required this.kit});

  final BugSessionKit kit;

  @override
  State<_BugSessionLibraryList> createState() => _BugSessionLibraryListState();
}

class _BugSessionLibraryListState extends State<_BugSessionLibraryList> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode() {
    setState(() => _selectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String sessionId) {
    setState(() {
      if (_selectedIds.contains(sessionId)) {
        _selectedIds.remove(sessionId);
      } else {
        _selectedIds.add(sessionId);
      }
    });
  }

  void _selectAll(List<BugSessionCatalogEntry> entries) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(entries.map((e) => e.sessionId));
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _bulkExport() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty || widget.kit.backgroundWork.active) {
      return;
    }
    var ok = 0;
    var failed = 0;
    try {
      await widget.kit.backgroundWork.run(
        config: widget.kit.config,
        title: 'Exporting sessions',
        startToast: 'Exporting ${ids.length} session(s)…',
        successToast: null,
        errorToastPrefix: 'Export failed',
        phases: [
          BugSessionWorkPhase(
            label: 'Writing zips',
            weight: 1,
            run: (r) async {
              for (var i = 0; i < ids.length; i++) {
                try {
                  await widget.kit.catalog.exportSessionToDisk(ids[i]);
                  ok++;
                } catch (_) {
                  failed++;
                }
                r((i + 1) / ids.length);
              }
            },
          ),
        ],
      );
      if (!mounted) {
        return;
      }
      final summary = failed == 0
          ? 'Exported $ok session${ok == 1 ? '' : 's'} to device storage'
          : 'Exported $ok of ${ids.length}; $failed failed';
      BugSessionTaskToasts.notifySuccess(widget.kit.config, summary);
      _exitSelectionMode();
    } catch (_) {}
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${ids.length} session${ids.length == 1 ? '' : 's'}?'),
        content: const Text(
          'Removes the selected entries and any on-device zips '
          '(may contain credentials).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.kit.catalog.deleteSessions(ids);
    for (final id in ids) {
      widget.kit.discardLastSessionIfDeleted(id);
    }
    if (!mounted) return;
    _exitSelectionMode();
    _snack('Deleted ${ids.length} session${ids.length == 1 ? '' : 's'}');
  }

  String _entrySubtitle(BugSessionCatalogEntry entry) {
    return '${entry.recordingKindLabel} · ${entry.source.name} · '
        'v${entry.appVersion} · ${entry.actionCount} actions';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<BugSessionCatalogEntry>>(
          stream: widget.kit.catalog.watchEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const SizedBox.shrink();
            }
            if (_selectionMode) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _selectAll(entries),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _exitSelectionMode,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _enterSelectionMode,
                  child: const Text('Select'),
                ),
              ),
            );
          },
        ),
        Flexible(
          child: StreamBuilder<List<BugSessionCatalogEntry>>(
            stream: widget.kit.catalog.watchEntries(),
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
                  final selected = _selectedIds.contains(entry.sessionId);
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _selectionMode
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => _toggleSelected(entry.sessionId),
                            )
                          : null,
                      title: Text(
                        entry.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _entrySubtitle(entry),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelected(entry.sessionId);
                          return;
                        }
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
        if (_selectionMode && _selectedIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassButton(
            theme: theme,
            label: 'Export selected (${_selectedIds.length})',
            filled: true,
            onPressed: _bulkExport,
          ),
          const SizedBox(height: 8),
          GlassButton(
            theme: theme,
            label: 'Delete selected (${_selectedIds.length})',
            onPressed: _bulkDelete,
          ),
        ],
        const SizedBox(height: 12),
        StreamBuilder<List<BugSessionCatalogEntry>>(
          stream: widget.kit.catalog.watchEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];
            if (entries.isEmpty || _selectionMode) {
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
                await widget.kit.catalog.clearAll();
                widget.kit.recorder.discardLastSession();
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
