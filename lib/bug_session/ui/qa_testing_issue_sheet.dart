import 'package:flutter/material.dart';

import '../../jam/jam_dev_connection.dart';
import '../../notion/notion_issue_service.dart';
import '../kit/bug_session_kit.dart';
import '../qa_testing/human_step_reproduce.dart';
import 'bug_session_flash.dart';
import '../kit/bug_session_modal_context.dart';
import 'design_system/bug_session_input_field.dart';
import 'bug_session_chrome_scope.dart';
import 'glass/glass_panel.dart';
import 'glass/glass_button.dart';

enum _IssueMode { auto, manual }

class QaTestingIssueSheet {
  QaTestingIssueSheet._();

  static Future<void> show(BuildContext context, {required BugSessionKit kit}) {
    final modalContext = requireBugSessionModalContext(
      kit.config,
      fallback: context,
    );
    return kit.sheetCoordinator.runExclusive(kit, () async {
      await showModalBottomSheet<void>(
        context: modalContext,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final height = MediaQuery.sizeOf(ctx).height * 0.85;
          return BugSessionChromeScope(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SizedBox(
                height: height,
                child: GlassPanel(
                  theme: kit.config.resolvedTheme,
                  child: _QaTestingIssuePane(kit: kit),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _QaTestingIssuePane extends StatefulWidget {
  const _QaTestingIssuePane({required this.kit});

  final BugSessionKit kit;

  @override
  State<_QaTestingIssuePane> createState() => _QaTestingIssuePaneState();
}

class _QaTestingIssuePaneState extends State<_QaTestingIssuePane> {
  _IssueMode _mode = _IssueMode.auto;
  var _submitting = false;

  final _title = TextEditingController();
  final _module = TextEditingController();
  final _precondition = TextEditingController();
  final _steps = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _module.dispose();
    _precondition.dispose();
    _steps.dispose();
    _expected.dispose();
    _actual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Auto',
                  selected: _mode == _IssueMode.auto,
                  onTap: () => setState(() => _mode = _IssueMode.auto),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Manual',
                  selected: _mode == _IssueMode.manual,
                  onTap: () => setState(() => _mode = _IssueMode.manual),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  BugSessionInputField(
                    label: 'Title',
                    hint: 'Bug title',
                    controller: _title,
                  ),
                  if (_mode == _IssueMode.manual) ...[
                    const SizedBox(height: 8),
                    BugSessionInputField(
                      label: 'Module',
                      hint: 'Feature under test',
                      controller: _module,
                    ),
                    const SizedBox(height: 8),
                    BugSessionInputField(
                      label: 'Precondition',
                      hint: 'Preconditions',
                      controller: _precondition,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    BugSessionInputField(
                      label: 'Step reproduce',
                      hint: 'Steps',
                      controller: _steps,
                      maxLines: 4,
                    ),
                  ],
                  const SizedBox(height: 8),
                  BugSessionInputField(
                    label: 'Expected',
                    hint: 'Expected result',
                    controller: _expected,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  BugSessionInputField(
                    label: 'Actual',
                    hint: 'Actual result',
                    controller: _actual,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          GlassButton(
            theme: theme,
            label: _submitting ? 'Submitting…' : 'Submit issue',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _actual.text.trim().isEmpty) {
      BugSessionFlash.showTopFlash(
        widget.kit.config,
        message: 'Title and Actual are required',
        isError: true,
      );
      return;
    }

    final jamStore = widget.kit.config.jamDevCredentialsStore;
    final jam = await jamStore?.read();
    if (jam == null || !jam.isComplete) {
      BugSessionFlash.showTopFlash(
        widget.kit.config,
        message: 'Configure Jam PAT and team id',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final autoModule = resolveTestingModuleLabel(
        currentRoute: widget.kit.config.currentRouteName?.call(),
        actions: widget.kit.recorder.recordedActions,
      );
      final fields = QaIssueFieldValues(
        title: _title.text.trim(),
        module: _mode == _IssueMode.auto
            ? autoModule
            : _module.text.trim(),
        precondition: _mode == _IssueMode.auto
            ? 'Kondisi sebelum'
            : _precondition.text.trim(),
        stepReproduce: _mode == _IssueMode.auto
            ? formatHumanStepReproduce(widget.kit.recorder.recordedActions)
            : _steps.text.trim(),
        expected: _expected.text.trim(),
        actual: _actual.text.trim(),
        screenshootSection: '',
      );

      await widget.kit.qaTesting.generateIssue(
        fields: fields,
        jamToken: jam.personalAccessToken,
        jamTeamId: jam.teamId,
        isAutoMode: _mode == _IssueMode.auto,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white24 : Colors.white10,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
