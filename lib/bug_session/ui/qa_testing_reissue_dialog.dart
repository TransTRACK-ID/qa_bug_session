import 'dart:ui';

import 'package:flutter/material.dart';

import '../../notion/notion_issue_service.dart';
import '../kit/bug_session_kit.dart';
import 'bug_session_chrome_scope.dart';
import 'bug_session_flash.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';

class QaTestingReissueDialog {
  QaTestingReissueDialog._();

  static Future<void> show(
    BuildContext context, {
    required BugSessionKit kit,
  }) async {
    final theme = kit.config.resolvedTheme;
    final cardTitle = kit.qaTesting.title?.trim();
    final titleLine = cardTitle != null && cardTitle.isNotEmpty
        ? cardTitle
        : 'this bug card';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            content: BugSessionChromeScope(
              child: GlassPanel(
                theme: theme,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Log this issue again?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are on an existing bug card ($titleLine). '
                      'We will upload a new Jam recording, attach a BugSession zip, '
                      'and add a comment. '
                      'The original Screenshoot link on the card will not change.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      theme: theme,
                      label: 'Log issue again',
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await _submit(kit);
                      },
                    ),
                    const SizedBox(height: 6),
                    GlassButton(
                      theme: theme,
                      label: 'Cancel',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _submit(BugSessionKit kit) async {
    final jamStore = kit.config.jamDevCredentialsStore;
    final jam = await jamStore?.read();
    if (jam == null || !jam.isComplete) {
      BugSessionFlash.showTopFlash(
        kit.config,
        message: 'Configure Jam PAT and team id',
        isError: true,
      );
      return;
    }

    final cardTitle = kit.qaTesting.title?.trim();
    try {
      await kit.qaTesting.generateIssue(
        fields: QaIssueFieldValues(
          title: cardTitle ?? 'Bug',
          module: '',
          precondition: '',
          stepReproduce: '',
          expected: '',
          actual: 'Issue persists — see new Jam recording in comments.',
          screenshootSection: '',
        ),
        jamToken: jam.personalAccessToken,
        jamTeamId: jam.teamId,
        isAutoMode: true,
      );
      BugSessionFlash.showTopFlash(
        kit.config,
        message: 'Issue logged again · recording resumed',
      );
    } catch (e) {
      BugSessionFlash.showTopFlash(
        kit.config,
        message: '$e',
        isError: true,
      );
    }
  }
}
