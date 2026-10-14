import 'package:flutter/foundation.dart';

import '../../jam/jam_dev_connection.dart';
import '../../jam/jam_session_video_upload.dart';
import '../../notion/notion_api.dart';
import '../../notion/notion_issue_service.dart';
import '../../notion/notion_ready_to_test.dart';
import '../../notion/qa_notion_status_names.dart';
import '../../notion/ready_to_test_connection.dart';
import '../kit/bug_session_background_work.dart';
import '../kit/bug_session_kit.dart';
import '../notion_page_status_update.dart';
import '../library/bug_session_catalog_entry.dart';
import '../library/bug_session_recording_kind.dart';
import '../models/bug_session.dart';
import '../recording/bug_session_video_capture.dart';
import '../runtime/bug_session_environment.dart';
import '../ui/bug_session_capture_mode.dart';
import 'human_step_reproduce.dart';
import 'qa_issue_screenshoot.dart';
import 'qa_issue_zip_export.dart';
import 'qa_testing_notification.dart';

export 'human_step_reproduce.dart';

class QaTestingTodoItem {
  QaTestingTodoItem({
    required this.blockId,
    required this.text,
    required this.checked,
  });

  final String blockId;
  final String text;
  bool checked;
}

class QaTestingSessionController extends ChangeNotifier {
  QaTestingSessionController(this.kit);

  final BugSessionKit kit;

  bool _active = false;
  String? _pageId;
  String? _title;
  bool _isChildCard = false;
  bool _parentOnFeedback = false;
  bool _childReissueSubmitted = false;
  String? _bugExpected;
  String? _bugActual;
  int _issueCount = 0;
  ReadyToTestConnection? _connection;
  final List<QaTestingTodoItem> _todos = [];
  Map<String, bool> _initialTodoState = {};

  bool get active => _active;
  String? get pageId => _pageId;
  String? get title => _title;
  bool get isChildCard => _isChildCard;
  bool get parentOnFeedback => _parentOnFeedback;

  /// Stop without pass: parent on feedback, or child after **Log issue again**.
  bool get finishWithStopOnly =>
      parentOnFeedback || (isChildCard && childReissueSubmitted);

  /// After a successful **Log issue again** on a child bug card this session.
  bool get childReissueSubmitted => _childReissueSubmitted;

  /// Expected / Actual from the bug card body (child cards only).
  String? get bugExpected => _bugExpected;
  String? get bugActual => _bugActual;

  static const childReissueSubmittedTooltip =
      'Already logged issue again. The bug card status is set to Issues '
      'and the new Jam recording was added as a comment.';
  bool get hideRecordingChrome => kit.config.hideRecordingChromeDuringQaTest;

  List<QaTestingTodoItem> get sortedTodos {
    final unchecked = _todos.where((t) => !t.checked).toList();
    final checked = _todos.where((t) => t.checked).toList();
    return [...unchecked, ...checked];
  }

  Future<void> startTesting({
    required ReadyToTestConnection connection,
    required String pageId,
    required String title,
    required List<NotionTodoBlock> todos,
  }) async {
    _connection = connection;
    _pageId = pageId;
    _title = title;
    _todos
      ..clear()
      ..addAll([
        for (final todo in todos)
          QaTestingTodoItem(
            blockId: todo.blockId,
            text: todo.text,
            checked: todo.checked,
          ),
      ]);
    _initialTodoState = {
      for (final todo in todos) todo.blockId: todo.checked,
    };

    final notion = NotionClient(connection.toApiConfig());
    final issueService = NotionIssueService(notion);
    _isChildCard = await issueService.isChildBugCard(pageId);
    _childReissueSubmitted = false;

    final task = await ReadyToTestService(notion).loadTaskDetail(
      pageId,
      configForMeta: connection.toFilterConfig(),
    );
    _parentOnFeedback = _normalize(task.task.status) == 'onfeedback';

    if (_isChildCard) {
      _bugExpected = _nonEmptySection(task.sectionText('expected'));
      _bugActual = _nonEmptySection(task.sectionText('actual'));
    } else {
      _bugExpected = null;
      _bugActual = null;
    }

    kit.captureMode.setMode(BugSessionPanelCaptureMode.fullRecord);
    kit.controlPanelLayout.collapse();
    kit.qaTestingChrome.enter();
    await kit.sheetCoordinator.dismissAll(kit);

    if (_normalize(task.task.status) != 'ontesting') {
      await NotionTaskStatusService(notion).updateStatus(
        pageId: pageId,
        newStatus: 'On Testing',
        statusPropertyOverride: connection.statusPropertyName,
      );
    }

    await kit.recorder.start();
    kit.recorder.holdQaTestingVideoCapture();
    _active = true;
    _issueCount = 0;
    notifyListeners();

    await QaTestingNotification.showActive(
      onStop: () => finishAfterFeedback(),
    );
  }

  void toggleTodo(String blockId, bool checked) {
    for (final todo in _todos) {
      if (todo.blockId == blockId) {
        todo.checked = checked;
        break;
      }
    }
    notifyListeners();
  }

  Future<void> finishPassed({required String jamToken, required String jamTeamId}) async {
    final pageId = _pageId;
    final connection = _connection;
    if (pageId == null || connection == null) {
      return;
    }

    BugSessionVideoArtifact? video;
    BugSession? session;
    var jamUrl = '';

    await kit.backgroundWork.run(
      config: kit.config,
      title: 'Submitting QA pass',
      startToast: 'Submitting QA pass…',
      successToast: 'PASSED ✅ · ${QaNotionStatusNames.passedParent}',
      errorToastPrefix: 'Pass failed',
      phases: [
        BugSessionWorkPhase(
          label: 'Finalizing video',
          weight: 1,
          run: (r) async {
            r(0);
            video = await kit.recorder.finalizeFullSessionVideo();
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Stopping recording',
          weight: 1,
          run: (r) async {
            session = await kit.recorder.stop(await _environment());
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Uploading to Jam',
          weight: 3,
          run: (r) async {
            jamUrl = await _resolveJamUrl(
              token: jamToken,
              teamId: jamTeamId,
              title: _title ?? 'QA pass',
              video: video,
              onProgress: r,
            );
          },
        ),
        BugSessionWorkPhase(
          label: 'Updating Notion status',
          weight: 1,
          run: (r) async {
            r(0);
            final notion = NotionClient(connection.toApiConfig());
            await updateNotionPageStatusResolving(
              kit: kit,
              client: notion,
              pageId: pageId,
              status: QaNotionStatusNames.passedParent,
              statusPropertyOverride: connection.statusPropertyName,
            );
            if (_isChildCard) {
              await NotionIssueService(notion)
                  .maybePromoteParentWhenAllIssuesResolved(
                childPageId: pageId,
                statusPropertyName: connection.statusPropertyName,
              );
            }
            r(0.5);
            await notion.createComment(
              pageId: pageId,
              plainText: 'PASSED ✅\n\n$jamUrl',
            );
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Syncing checklist',
          weight: 1,
          run: (r) async {
            r(0);
            await _syncTodos(NotionClient(connection.toApiConfig()));
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Saving session',
          weight: 1,
          run: (r) async {
            r(0);
            await _saveQaSessionToCatalog(
              session!,
              jamShareUrl: jamUrl,
              onJamProgress: r,
            );
            await _clearVideoAfterJamUpload();
            r(1);
          },
        ),
      ],
    );
    await _exitMode();
  }

  Future<String> generateIssue({
    required QaIssueFieldValues fields,
    required String jamToken,
    required String jamTeamId,
    required bool isAutoMode,
  }) async {
    final pageId = _pageId;
    final connection = _connection;
    if (pageId == null || connection == null) {
      throw StateError('No active QA testing session');
    }

    BugSessionVideoArtifact? video;
    var jamUrl = '';
    late QaIssueAttachmentBundle attachments;
    late QaIssueFieldValues resolvedFields;
    late String issuePageId;

    await kit.backgroundWork.run(
      config: kit.config,
      title: 'Submitting issue',
      startToast: 'Submitting issue…',
      successToast: 'Issue submitted · recording resumed',
      errorToastPrefix: 'Issue failed',
      phases: [
        BugSessionWorkPhase(
          label: 'Capturing video',
          weight: 1,
          run: (r) async {
            r(0);
            video = await kit.recorder.snapshotVideoForIssue();
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Uploading to Jam',
          weight: 3,
          run: (r) async {
            jamUrl = await _resolveJamUrl(
              token: jamToken,
              teamId: jamTeamId,
              title: fields.title,
              video: video,
              onProgress: r,
            );
          },
        ),
        BugSessionWorkPhase(
          label: 'Preparing BugSession zip',
          weight: 1,
          run: (r) async {
            r(0);
            final notion = NotionClient(connection.toApiConfig());
            final zipExport = await exportQaIssueReplayZip(kit);
            r(0.4);
            attachments = await buildQaIssueAttachmentBundle(
              kit: kit,
              notion: notion,
              jamUrl: jamUrl,
              zipBytes: zipExport.bytes,
              zipFilename: zipExport.filename,
              onNotionUploadProgress: r,
            );
            resolvedFields = isAutoMode
                ? QaIssueFieldValues(
                    title: fields.title,
                    module: fields.module.isNotEmpty
                        ? fields.module
                        : _resolveModule(),
                    precondition: fields.precondition,
                    stepReproduce: fields.stepReproduce.isNotEmpty
                        ? fields.stepReproduce
                        : formatHumanStepReproduce(
                            kit.recorder.recordedActions,
                          ),
                    expected: fields.expected,
                    actual: fields.actual,
                    screenshootSection: attachments.screenshootSection,
                  )
                : fields.copyWith(
                    screenshootSection: attachments.screenshootSection,
                  );
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Updating Notion',
          weight: 2,
          run: (r) async {
            r(0);
            final notion = NotionClient(connection.toApiConfig());
            final issueService = NotionIssueService(notion);
            if (_isChildCard) {
              issuePageId = pageId;
              await issueService.updateExistingBugReissue(
                bugPageId: pageId,
                commentBody: qaIssueReissueComment(
                  jamUrl: jamUrl,
                  screenshootSection: attachments.screenshootSection,
                ),
              );
              _childReissueSubmitted = true;
            } else {
              issuePageId = await issueService.createBugFromParent(
                parentPageId: pageId,
                fields: resolvedFields,
              );
              if (_issueCount == 0) {
                await NotionTaskStatusService(notion).updateStatus(
                  pageId: pageId,
                  newStatus: 'On Feedback',
                  statusPropertyOverride: connection.statusPropertyName,
                );
                _parentOnFeedback = true;
              }
            }
            r(0.6);
            final uploadId = attachments.notionFileUploadId;
            if (uploadId != null && uploadId.isNotEmpty) {
              await attachQaIssueZipToNotionPage(
                notion: notion,
                issuePageId: issuePageId,
                fileUploadId: uploadId,
              );
            }
            await _clearVideoAfterJamUpload();
            r(1);
          },
        ),
      ],
    );

    _issueCount++;
    notifyListeners();
    return issuePageId;
  }

  Future<void> finishAfterFeedback() async {
    BugSession? session;
    final pageId = _pageId;
    final connection = _connection;

    await kit.backgroundWork.run(
      config: kit.config,
      title: 'Stopping QA test',
      startToast: 'Stopping test…',
      successToast: 'Testing stopped',
      errorToastPrefix: 'Stop failed',
      phases: [
        BugSessionWorkPhase(
          label: 'Stopping recording',
          weight: 2,
          run: (r) async {
            r(0);
            if (kit.recorder.isRecording) {
              session = await kit.recorder.stop(await _environment());
            }
            r(0.5);
            if (session != null) {
              await _saveQaSessionToCatalog(session!, onJamProgress: r);
            }
            r(1);
          },
        ),
        BugSessionWorkPhase(
          label: 'Syncing checklist',
          weight: 1,
          run: (r) async {
            r(0);
            if (pageId != null && connection != null) {
              await _syncTodos(NotionClient(connection.toApiConfig()));
            }
            r(1);
          },
        ),
      ],
    );
    await _exitMode();
  }

  Future<void> _exitMode() async {
    _active = false;
    kit.recorder.releaseQaTestingVideoCapture();
    kit.qaTestingChrome.exit();
    await QaTestingNotification.dismiss();
    notifyListeners();
  }

  Future<void> _syncTodos(NotionClient notion) async {
    final changes = <String, bool>{};
    for (final todo in _todos) {
      final initial = _initialTodoState[todo.blockId];
      if (initial != null && initial != todo.checked) {
        changes[todo.blockId] = todo.checked;
      }
    }
    if (changes.isEmpty) {
      return;
    }
    await ReadyToTestService(notion).submitTodoChanges(changes);
  }

  Future<String> _resolveJamUrl({
    required String token,
    required String teamId,
    required String title,
    BugSessionVideoArtifact? video,
    void Function(double progress)? onProgress,
  }) async {
    if (video == null || video.bytes.isEmpty) {
      return '(No screen recording captured — Jam upload skipped)';
    }
    final url = await uploadVideoToJam(
      connection: JamDevConnection(
        personalAccessToken: token,
        teamId: teamId,
      ),
      video: video,
      title: title,
      pageUrl: kit.config.currentRouteName?.call() ?? '',
      onProgress: onProgress,
    );
    if (url == null || url.isEmpty) {
      return '(Jam upload failed)';
    }
    return url;
  }

  Future<void> _clearVideoAfterJamUpload() async {
    kit.recorder.discardLocalVideoAfterJamUpload();
    final sessionId = kit.recorder.activeSessionId;
    if (sessionId != null) {
      await kit.catalog.purgeVideoForSession(sessionId);
    }
  }

  Future<void> _saveQaSessionToCatalog(
    BugSession session, {
    String? jamShareUrl,
    void Function(double progress)? onJamProgress,
  }) async {
    final cardTitle = _title?.trim();
    final displayName = cardTitle != null && cardTitle.isNotEmpty
        ? 'QA · $cardTitle'
        : defaultBugSessionDisplayName(
            startedAt: session.manifest.startedAt,
            actionCount: session.actions.length,
          );
    final visualFiles = kit.recorder.takeVisualArchiveFiles();
    final planned = await finalizeSessionVideoForCatalog(
      kit,
      visualArchiveFiles: visualFiles,
      title: displayName,
      onJamUploadProgress: onJamProgress,
    );
    await kit.catalog.addFromStoppedSession(
      session,
      visualArchiveFiles: planned.archiveFiles,
      displayName: displayName,
      jamShareUrl: jamShareUrl ?? planned.jamShareUrl,
      recordingKind: BugSessionRecordingKind.qaNotionCard,
    );
    kit.recorder.restoreLastSession(session);
    if (planned.jamShareUrl != null && jamShareUrl == null) {
      await kit.catalog.purgeVideoForSession(session.manifest.sessionId);
    }
  }

  String _resolveModule() {
    final resolver = kit.config.resolveTestingModuleLabel;
    if (resolver != null) {
      return resolver(
        kit.recorder.recordedActions,
        kit.config.currentRouteName?.call(),
      );
    }
    return resolveTestingModuleLabel(
      currentRoute: kit.config.currentRouteName?.call(),
      actions: kit.recorder.recordedActions,
    );
  }

  Future<BugSessionEnvironment> _environment() async {
    await kit.config.refreshEnvironment?.call();
    final env = kit.config.environmentBuilder?.call();
    if (env == null) {
      throw StateError('BugSession environment is not configured');
    }
    return env;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String? _nonEmptySection(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

extension on QaIssueFieldValues {
  QaIssueFieldValues copyWith({String? screenshootSection}) {
    return QaIssueFieldValues(
      title: title,
      module: module,
      precondition: precondition,
      stepReproduce: stepReproduce,
      expected: expected,
      actual: actual,
      screenshootSection: screenshootSection ?? this.screenshootSection,
    );
  }
}
