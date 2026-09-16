import 'package:flutter/material.dart';

import 'notion_api.dart';
import 'notion_ready_to_test.dart';
import 'ready_to_test_connection.dart';

/// Dev/staging overlay entry for the Ready to Test Notion queue.
class ReadyToTestToolsHost extends StatefulWidget {
  const ReadyToTestToolsHost({
    super.key,
    required this.store,
    required this.defaults,
    required this.child,
    this.enabled = true,
  });

  final ReadyToTestCredentialsStore store;
  final ReadyToTestSetupDefaults defaults;
  final Widget child;
  final bool enabled;

  @override
  State<ReadyToTestToolsHost> createState() => _ReadyToTestToolsHostState();
}

class _ReadyToTestToolsHostState extends State<ReadyToTestToolsHost> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 16,
          bottom: 24,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.extended(
              heroTag: 'ready_to_test_queue',
              onPressed: _onOpen,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Ready to Test'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onOpen() async {
    var connection = await widget.store.read();
    if (connection == null || !connection.isComplete) {
      connection = await _showSettingsSheet(connection);
    }
    if (!mounted || connection == null || !connection.isComplete) {
      return;
    }

    await _showQueueSheet(connection);
  }

  Future<ReadyToTestConnection?> _showSettingsSheet(
    ReadyToTestConnection? existing,
  ) {
    return showModalBottomSheet<ReadyToTestConnection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ReadyToTestSettingsSheet(
          defaults: widget.defaults,
          initial: existing,
          onSave: (connection) async {
            await widget.store.write(connection);
            if (context.mounted) {
              Navigator.of(context).pop(connection);
            }
          },
        );
      },
    );
  }

  Future<void> _showQueueSheet(ReadyToTestConnection connection) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ReadyToTestQueueSheet(
          connection: connection,
          onConfigure: () => _showSettingsSheet(connection),
        );
      },
    );
  }
}

class _ReadyToTestSettingsSheet extends StatefulWidget {
  const _ReadyToTestSettingsSheet({
    required this.defaults,
    required this.initial,
    required this.onSave,
  });

  final ReadyToTestSetupDefaults defaults;
  final ReadyToTestConnection? initial;
  final Future<void> Function(ReadyToTestConnection connection) onSave;

  @override
  State<_ReadyToTestSettingsSheet> createState() =>
      _ReadyToTestSettingsSheetState();
}

class _ReadyToTestSettingsSheetState extends State<_ReadyToTestSettingsSheet> {
  late final TextEditingController _token;
  late final TextEditingController _dataSourceId;
  late final TextEditingController _qaUserId;
  late final TextEditingController _product;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _token = TextEditingController(text: initial?.token ?? '');
    _dataSourceId = TextEditingController(
      text: initial?.dataSourceId ?? widget.defaults.dataSourceId,
    );
    _qaUserId = TextEditingController(
      text: initial?.qaUserId ?? widget.defaults.qaUserId,
    );
    _product = TextEditingController(
      text: initial?.productDomain ?? widget.defaults.productDomain ?? '',
    );
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to Test — Notion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Integration token is stored on-device. Other ids can be '
              'pre-filled by project setup.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Notion integration token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dataSourceId,
              decoration: const InputDecoration(
                labelText: 'Data source ID',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qaUserId,
              decoration: const InputDecoration(
                labelText: 'QA Notion user ID',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _product,
              decoration: const InputDecoration(
                labelText: 'Product domain filter (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
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
      statusEquals: widget.defaults.statusEquals,
      statusPropertyName: widget.defaults.statusPropertyName,
      productPropertyName: widget.defaults.productPropertyName,
      qaPropertyName: widget.defaults.qaPropertyName,
    );
    if (!connection.isComplete) {
      _showError('Token, data source id, and QA user id are required.');
      return;
    }

    setState(() => _saving = true);
    try {
      final client = NotionClient(connection.toApiConfig());
      await client.getUsersMe();
      await widget.onSave(connection);
    } on NotionApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ReadyToTestQueueSheet extends StatefulWidget {
  const _ReadyToTestQueueSheet({
    required this.connection,
    required this.onConfigure,
  });

  final ReadyToTestConnection connection;
  final VoidCallback onConfigure;

  @override
  State<_ReadyToTestQueueSheet> createState() => _ReadyToTestQueueSheetState();
}

class _ReadyToTestQueueSheetState extends State<_ReadyToTestQueueSheet> {
  late Future<List<ReadyToTestTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final client = NotionClient(widget.connection.toApiConfig());
    final service = ReadyToTestService(client);
    _tasksFuture = service.listTasks(widget.connection.toFilterConfig());
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ready to Test',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Notion settings',
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onConfigure();
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ReadyToTestTask>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('${snapshot.error}'),
                    ),
                  );
                }
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks in this queue.'));
                }
                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        [
                          if (task.productDomain != null) task.productDomain,
                          task.status,
                        ].whereType<String>().join(' · '),
                      ),
                      onTap: () => _openDetail(task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(ReadyToTestTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ReadyToTestDetailSheet(
          connection: widget.connection,
          pageId: task.pageId,
          title: task.title,
        );
      },
    );
    if (mounted) {
      setState(_reload);
    }
  }
}

class _ReadyToTestDetailSheet extends StatefulWidget {
  const _ReadyToTestDetailSheet({
    required this.connection,
    required this.pageId,
    required this.title,
  });

  final ReadyToTestConnection connection;
  final String pageId;
  final String title;

  @override
  State<_ReadyToTestDetailSheet> createState() =>
      _ReadyToTestDetailSheetState();
}

class _ReadyToTestDetailSheetState extends State<_ReadyToTestDetailSheet> {
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
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _pending.clear();
        for (final todo in detail.todos) {
          _pending[todo.blockId] = todo.checked;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Map<String, bool> _changedTodos() {
    final detail = _detail;
    if (detail == null) return {};
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
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = NotionClient(widget.connection.toApiConfig());
      await ReadyToTestService(client).submitTodoChanges(changes);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('$_error'))
                    : _buildBody(),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit checklist to Notion'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final detail = _detail!;
    return ListView(
      padding: const EdgeInsets.all(16),
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
                  style: switch (level) {
                    1 => Theme.of(context).textTheme.headlineSmall,
                    2 => Theme.of(context).textTheme.titleMedium,
                    _ => Theme.of(context).textTheme.titleSmall,
                  },
                ),
              ),
            NotionParagraphBlock(:final text) when text.isNotEmpty => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(text),
              ),
            NotionBulletedBlock(:final text) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
            NotionTodoBlock(:final blockId, :final text) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text),
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
