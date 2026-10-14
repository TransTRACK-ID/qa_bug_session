import 'package:flutter/material.dart';

import '../../jam/jam_dev_connection.dart';
import '../../notion/qa_notion_status_names.dart';
import '../kit/bug_session_kit.dart';
import '../kit/bug_session_theme.dart';
import '../qa_testing/qa_testing_session.dart';
import '../kit/bug_session_modal_context.dart';
import 'bug_session_flash.dart';
import 'bug_session_chrome_scope.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';
import 'qa_testing_issue_sheet.dart';
import 'qa_testing_reissue_dialog.dart';
import 'bug_session_todo_row.dart';
import 'qa_testing_pass_dialog.dart';

class QaTestingObjectivePanel extends StatefulWidget {
  const QaTestingObjectivePanel({super.key, required this.kit});

  final BugSessionKit kit;

  @override
  State<QaTestingObjectivePanel> createState() => _QaTestingObjectivePanelState();
}

class _QaTestingObjectivePanelState extends State<QaTestingObjectivePanel> {
  Offset _position = const Offset(12, 72);
  var _expanded = true;

  BugSessionKit get kit => widget.kit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kit.qaTesting,
      builder: (context, _) {
        if (!kit.qaTesting.active) {
          return const SizedBox.shrink();
        }
        final theme = kit.config.resolvedTheme;
        final todos = kit.qaTesting.sortedTodos;
        final finishLabel = kit.qaTesting.finishWithStopOnly
            ? 'Stop testing'
            : 'Complete testing';

        final panelMaxWidth = 300.0;
        final screen = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: BugSessionChromeScope(
            child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelMaxWidth),
            child: GlassPanel(
              theme: theme,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    onPanUpdate: (details) {
                      final maxX = (screen.width - panelMaxWidth - padding.right)
                          .clamp(0.0, double.infinity);
                      final maxY = (screen.height - padding.bottom - 120)
                          .clamp(0.0, double.infinity);
                      setState(() {
                        _position = Offset(
                          (_position.dx + details.delta.dx).clamp(0.0, maxX),
                          (_position.dy + details.delta.dy)
                              .clamp(padding.top, maxY),
                        );
                      });
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_handle,
                          color: Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Objective',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.white54,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: kit.qaTesting.isChildCard ? 240 : 180,
                      ),
                      child: SingleChildScrollView(
                        child: _objectiveScrollContent(todos),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GlassButton(
                      theme: theme,
                      label: finishLabel,
                      onPressed: () => _onFinish(context),
                    ),
                    const SizedBox(height: 6),
                    _issueActionButton(context, theme),
                  ],
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _objectiveScrollContent(List<QaTestingTodoItem> todos) {
    if (kit.qaTesting.isChildCard) {
      final expected = kit.qaTesting.bugExpected;
      final actual = kit.qaTesting.bugActual;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bugFieldSection('Expected', expected),
          const SizedBox(height: 8),
          _bugFieldSection('Actual', actual),
          if (todos.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final todo in todos)
              BugSessionTodoRow(
                checked: todo.checked,
                text: todo.text,
                onChanged: (value) {
                  kit.qaTesting.toggleTodo(todo.blockId, value);
                },
              ),
          ],
        ],
      );
    }

    if (todos.isEmpty) {
      return const Text(
        'No objectives were given.',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 12,
        ),
      );
    }

    return Column(
      children: [
        for (final todo in todos)
          BugSessionTodoRow(
            checked: todo.checked,
            text: todo.text,
            onChanged: (value) {
              kit.qaTesting.toggleTodo(todo.blockId, value);
            },
          ),
      ],
    );
  }

  Widget _bugFieldSection(String label, String? body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body ?? '(Not set on this card)',
          style: TextStyle(
            color: body != null ? Colors.white70 : Colors.white38,
            fontSize: 12,
            height: 1.35,
            fontStyle: body == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  Widget _issueActionButton(BuildContext context, BugSessionThemeData theme) {
    final isReissue = kit.qaTesting.isChildCard;
    final disabled =
        isReissue && kit.qaTesting.childReissueSubmitted;
    if (!disabled) {
      return GlassButton(
        theme: theme,
        label: isReissue ? 'Log issue again' : 'Generate issue',
        onPressed: () => _openIssueFlow(context),
      );
    }

    // Objective panel floats outside [MaterialApp]'s overlay — no [Tooltip].
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassButton(
          theme: theme,
          label: 'Log issue again',
          onPressed: null,
        ),
        const SizedBox(height: 4),
        const Text(
          QaTestingSessionController.childReissueSubmittedTooltip,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Future<void> _openIssueFlow(BuildContext context) async {
    if (kit.qaTesting.isChildCard && kit.qaTesting.childReissueSubmitted) {
      return;
    }
    setState(() => _expanded = false);
    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: context,
    );
    try {
      if (kit.qaTesting.isChildCard) {
        await QaTestingReissueDialog.show(modalContext, kit: kit);
      } else {
        await QaTestingIssueSheet.show(modalContext, kit: kit);
      }
    } finally {
      if (mounted) {
        setState(() => _expanded = true);
      }
    }
  }

  Future<void> _onFinish(BuildContext context) async {
    if (kit.qaTesting.finishWithStopOnly) {
      try {
        await kit.qaTesting.finishAfterFeedback();
      } catch (_) {}
      return;
    }

    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: context,
    );
    final confirmed = await QaTestingPassDialog.show(modalContext, kit: kit);
    if (confirmed != true || !context.mounted) {
      return;
    }

    final jam = await _readJamCredentials();
    if (jam == null) {
      BugSessionFlash.showTopFlash(
        kit.config,
        message: 'Configure Jam PAT and team id in Ready to Test settings',
        isError: true,
      );
      return;
    }

    try {
      await kit.qaTesting.finishPassed(
        jamToken: jam.personalAccessToken,
        jamTeamId: jam.teamId,
      );
    } catch (_) {}
  }

  Future<JamDevConnection?> _readJamCredentials() async {
    final store = kit.config.jamDevCredentialsStore;
    if (store == null) {
      return null;
    }
    final connection = await store.read();
    if (connection == null || !connection.isComplete) {
      return null;
    }
    return connection;
  }
}
