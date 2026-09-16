import 'package:flutter/material.dart';

import '../../notion/notion_api.dart';
import '../../notion/notion_ready_to_test.dart';
import '../../notion/ready_to_test_connection.dart';
import '../kit/bug_session_kit.dart';
import 'bug_session_sheet_stack.dart';
import 'glass/glass_button.dart';

/// Ready to Test queue inside the BugSession glass bottom sheet (same stack as library).
class BugSessionReadyToTestSheet {
  BugSessionReadyToTestSheet._();

  static const _listRoute = '/';
  static const settingsRoute = '/settings';
  static const _detailRoute = '/detail';

  static bool get isConfigured {
    // Checked per-kit in [show].
    return true;
  }

  static Future<void> show(
    BuildContext context, {
    required BugSessionKit kit,
  }) async {
    final store = kit.config.readyToTestStore;
    final defaults = kit.config.readyToTestDefaults;
    if (store == null || defaults == null) {
      return;
    }

    final saved = await store.read();
    final initialRoute =
        saved != null && saved.isComplete ? _listRoute : settingsRoute;

    if (!context.mounted) {
      return;
    }

    await BugSessionSheetStack.show(
      context: context,
      kit: kit,
      title: 'Ready to Test',
      initialRoute: initialRoute,
      titleForRoute: (route, defaultTitle) {
        return switch (route) {
          settingsRoute => 'Notion connection',
          _detailRoute => 'Task detail',
          _ => defaultTitle,
        };
      },
      routes: {
        settingsRoute: (ctx) => _ReadyToTestSettingsPane(
              kit: kit,
              onSaved: () {
                Navigator.of(ctx).pushReplacementNamed(_listRoute);
              },
            ),
        _listRoute: (ctx) => _ReadyToTestQueuePane(kit: kit),
        _detailRoute: (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments
              as _ReadyToTestDetailArgs;
          return _ReadyToTestDetailPane(
            kit: kit,
            connection: args.connection,
            pageId: args.pageId,
            title: args.title,
          );
        },
      },
    );
  }
}

class _ReadyToTestDetailArgs {
  const _ReadyToTestDetailArgs({
    required this.connection,
    required this.pageId,
    required this.title,
  });

  final ReadyToTestConnection connection;
  final String pageId;
  final String title;
}

class _ReadyToTestSettingsPane extends StatefulWidget {
  const _ReadyToTestSettingsPane({
    required this.kit,
    required this.onSaved,
  });

  final BugSessionKit kit;
  final VoidCallback onSaved;

  @override
  State<_ReadyToTestSettingsPane> createState() =>
      _ReadyToTestSettingsPaneState();
}

class _ReadyToTestSettingsPaneState extends State<_ReadyToTestSettingsPane> {
  final _token = TextEditingController();
  final _dataSourceId = TextEditingController();
  final _qaUserId = TextEditingController();
  final _product = TextEditingController();
  var _loading = true;
  var _saving = false;
  String? _error;

  ReadyToTestCredentialsStore get _store => widget.kit.config.readyToTestStore!;
  ReadyToTestSetupDefaults get _defaults =>
      widget.kit.config.readyToTestDefaults!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await _store.read();
    if (!mounted) {
      return;
    }
    _token.text = existing?.token ?? '';
    _dataSourceId.text = existing?.dataSourceId ?? '';
    _qaUserId.text = existing?.qaUserId ?? '';
    _product.text = existing?.productDomain ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _token.dispose();
    _dataSourceId.dispose();
    _qaUserId.dispose();
    _product.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    final theme = widget.kit.config.resolvedTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter your Notion integration token and filter ids. '
            'Nothing is baked into the app — values stay on this device.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _field(_token, 'Integration token (secret)', obscure: true),
          const SizedBox(height: 10),
          _field(_dataSourceId, 'Data source ID'),
          const SizedBox(height: 10),
          _field(_qaUserId, 'QA user ID (people property)'),
          const SizedBox(height: 10),
          _field(_product, 'Product domain filter (optional)'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          GlassButton(
            theme: theme,
            label: _saving ? 'Saving…' : 'Save & validate',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final product = _product.text.trim();
    final connection = ReadyToTestConnection(
      token: _token.text.trim(),
      dataSourceId: _dataSourceId.text.trim(),
      qaUserId: _qaUserId.text.trim(),
      productDomain: product.isEmpty ? null : product,
      statusEquals: _defaults.statusEquals,
      statusPropertyName: _defaults.statusPropertyName,
      productPropertyName: _defaults.productPropertyName,
      qaPropertyName: _defaults.qaPropertyName,
    );
    if (!connection.isComplete) {
      setState(() {
        _error = 'Token, data source id, and QA user id are required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = NotionClient(connection.toApiConfig());
      await client.getUsersMe();
      await _store.write(connection);
      if (!mounted) {
        return;
      }
      widget.onSaved();
    } on NotionApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ReadyToTestQueuePane extends StatefulWidget {
  const _ReadyToTestQueuePane({required this.kit});

  final BugSessionKit kit;

  @override
  State<_ReadyToTestQueuePane> createState() => _ReadyToTestQueuePaneState();
}

class _ReadyToTestQueuePaneState extends State<_ReadyToTestQueuePane> {
  ReadyToTestConnection? _connection;
  Future<List<ReadyToTestTask>>? _tasksFuture;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final connection = await widget.kit.config.readyToTestStore!.read();
    if (!mounted) {
      return;
    }
    if (connection == null || !connection.isComplete) {
      setState(() {
        _connection = connection;
        _error = 'Notion connection incomplete.';
        _tasksFuture = null;
      });
      return;
    }
    final client = NotionClient(connection.toApiConfig());
    final service = ReadyToTestService(client);
    setState(() {
      _connection = connection;
      _error = null;
      _tasksFuture = service.listTasks(connection.toFilterConfig());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassButton(
          theme: theme,
          label: 'Notion connection settings',
          onPressed: () {
            Navigator.of(context).pushNamed(
              BugSessionReadyToTestSheet.settingsRoute,
            );
          },
        ),
        const SizedBox(height: 12),
        Flexible(
          child: FutureBuilder<List<ReadyToTestTask>>(
            future: _tasksFuture,
            builder: (context, snapshot) {
              if (_error != null) {
                return Center(
                  child: Text(
                    '$_error',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              final tasks = snapshot.data ?? [];
              if (tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'No tasks in this queue.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        task.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [
                          if (task.productDomain != null) task.productDomain,
                          task.status,
                        ].whereType<String>().join(' · '),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        final connection = _connection;
                        if (connection == null) {
                          return;
                        }
                        Navigator.of(context).pushNamed(
                          BugSessionReadyToTestSheet._detailRoute,
                          arguments: _ReadyToTestDetailArgs(
                            connection: connection,
                            pageId: task.pageId,
                            title: task.title,
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReadyToTestDetailPane extends StatefulWidget {
  const _ReadyToTestDetailPane({
    required this.kit,
    required this.connection,
    required this.pageId,
    required this.title,
  });

  final BugSessionKit kit;
  final ReadyToTestConnection connection;
  final String pageId;
  final String title;

  @override
  State<_ReadyToTestDetailPane> createState() => _ReadyToTestDetailPaneState();
}

class _ReadyToTestDetailPaneState extends State<_ReadyToTestDetailPane> {
  ReadyToTestTaskDetail? _detail;
  final Map<String, bool> _pending = {};
  var _loading = true;
  var _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = NotionClient(widget.connection.toApiConfig());
      final service = ReadyToTestService(client);
      final detail = await service.loadTaskDetail(
        widget.pageId,
        configForMeta: widget.connection.toFilterConfig(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _pending.clear();
        for (final todo in detail.todos) {
          _pending[todo.blockId] = todo.checked;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Map<String, bool> _changedTodos() {
    final detail = _detail;
    if (detail == null) {
      return {};
    }
    final changes = <String, bool>{};
    for (final todo in detail.todos) {
      final next = _pending[todo.blockId];
      if (next != null && next != todo.checked) {
        changes[todo.blockId] = next;
      }
    }
    return changes;
  }

  Future<void> _submit() async {
    final changes = _changedTodos();
    if (changes.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = NotionClient(widget.connection.toApiConfig());
      await ReadyToTestService(client).submitTodoChanges(changes);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          '$_error',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildBody()),
        const SizedBox(height: 8),
        GlassButton(
          theme: theme,
          label: _submitting ? 'Submitting…' : 'Submit checklist to Notion',
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildBody() {
    final detail = _detail!;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final block in detail.bodyBlocks) ...[
          switch (block) {
            NotionHeadingBlock(:final level, :final text) => Padding(
                padding: EdgeInsets.only(
                  top: level == 1 ? 8 : 16,
                  bottom: 8,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: switch (level) {
                      1 => 20,
                      2 => 17,
                      _ => 15,
                    },
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            NotionParagraphBlock(:final text) when text.isNotEmpty => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            NotionBulletedBlock(:final text) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            NotionTodoBlock(:final blockId, :final text) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text, style: const TextStyle(color: Colors.white)),
                checkColor: Colors.black,
                activeColor: Colors.white70,
                value: _pending[blockId] ?? false,
                onChanged: (value) {
                  setState(() => _pending[blockId] = value ?? false);
                },
              ),
            _ => const SizedBox.shrink(),
          },
        ],
      ],
    );
  }
}
