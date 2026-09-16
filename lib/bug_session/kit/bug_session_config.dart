import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../models/bug_session.dart';
import '../models/recorded_action.dart';
import '../recording/bug_session_video_capture.dart';
import '../replay/replay_result.dart';
import '../shadowplay/shadowplay_settings.dart';
import '../runtime/bug_session_environment.dart';
import '../security/credential_injector.dart';
import '../../notion/ready_to_test_connection.dart';
import 'bug_session_file_picker.dart';
import 'bug_session_theme.dart';

typedef BugSessionNavigationReplay = Future<void> Function(
  RecordedAction action, {
  bool Function()? shouldStop,
});

typedef BugSessionReplayBootstrap = Future<void> Function(BugSession session);

typedef BugSessionPrepareReplay = Future<void> Function(BugSession session);

typedef BugSessionReplaySettle = Future<void> Function({
  required RecordedAction completedAction,
  RecordedAction? nextAction,
  bool Function()? shouldStop,
});

typedef BugSessionCurrentRouteName = String? Function();

/// Host-specific replay (e.g. Continue on detail task). Return true if handled.
typedef BugSessionTryReplayAction = Future<bool> Function(
  RecordedAction action, {
  bool Function()? shouldStop,
});

/// Prefer normalized tap metadata over recorded global pixels when set.
typedef BugSessionResolveReplayTapPosition = Offset? Function(
  RecordedAction action,
);

/// Maps a recorded tap to a [RecorderTargetRegistry] id (host codegen).
typedef BugSessionResolveRecorderTargetId = String? Function(
  RecordedAction action,
);

typedef BugSessionScreenshotCapture = Future<Uint8List?> Function();

/// Opens the platform share sheet (e.g. WhatsApp) for an exported zip path.
class BugSessionShareExportRequest {
  const BugSessionShareExportRequest({
    required this.zipPath,
    this.videoPath,
  });

  final String zipPath;
  final String? videoPath;
}

typedef BugSessionShareExport = Future<void> Function(
  BugSessionShareExportRequest request,
);

typedef BugSessionReplayFinished = Future<void> Function(ReplayResult result);

@immutable
class BugSessionConfig {
  const BugSessionConfig({
    required this.enabled,
    required this.environmentLabel,
    required this.credentialInjector,
    this.environmentBuilder,
    this.storageDirectory,
    this.theme,
    this.filePicker,
    this.openLibraryAfterImport = false,
    this.navigatorKey,
    this.refreshEnvironment,
    this.replayNavigation,
    this.screenshotCapture,
    this.screenshotInterval = const Duration(seconds: 3),
    this.maxScreenshotFrames = 80,
    this.videoCapture,
    this.maxVideoDuration = const Duration(minutes: 1),
    this.shareExport,
    this.openShareSheetAfterExport = true,
    this.validateUserIdentityOnReplay = false,
    this.restoreSessionAfterReplay = false,
    this.replayBootstrap,
    this.prepareForReplay,
    this.replaySettle,
    this.replayStepDelay = const Duration(milliseconds: 900),
    this.tryReplayAction,
    this.resolveReplayTapPosition,
    this.resolveRecorderTargetId,
    this.currentRouteName,
    this.shadowplay = const BugSessionShadowplaySettings(),
    this.manualRecordWithShadowplay = false,
    this.onReplayFinished,
    this.expandPanelWhenSheetClosed = true,
    this.readyToTestStore,
    this.readyToTestDefaults,
  });

  final bool enabled;
  final String environmentLabel;
  final CredentialInjector credentialInjector;
  final BugSessionEnvironment Function()? environmentBuilder;
  final Directory? storageDirectory;
  final BugSessionThemeData? theme;
  final BugSessionFilePicker? filePicker;

  /// When true, library sheet opens after a successful import.
  final bool openLibraryAfterImport;

  /// Must match [MaterialApp.router] / auto_route root navigator for modals.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Called before reading [environmentBuilder] (e.g. refresh auth snapshot).
  final Future<void> Function()? refreshEnvironment;

  /// Replays [RecordedActionType.navigation] (and related) during live replay.
  final BugSessionNavigationReplay? replayNavigation;

  /// Periodic PNG frames while recording (visual evidence in export zip).
  final BugSessionScreenshotCapture? screenshotCapture;
  final Duration screenshotInterval;
  final int maxScreenshotFrames;

  /// Short screen recording (GIF/MP4) while recording — preferred over PNG frames.
  final BugSessionVideoCapture? videoCapture;
  final Duration maxVideoDuration;

  final BugSessionShareExport? shareExport;

  /// When true and [shareExport] is set, export opens the share sheet automatically.
  final bool openShareSheetAfterExport;

  /// When false (default), replay swaps to the session user without matching current login.
  final bool validateUserIdentityOnReplay;

  /// When false (default), injected credentials stay after replay (QA impersonation).
  final bool restoreSessionAfterReplay;

  /// Resets navigation to the recorded starting point before replaying actions.
  final BugSessionReplayBootstrap? replayBootstrap;

  /// Host hook before credential injection (e.g. logout for login-flow replay).
  final BugSessionPrepareReplay? prepareForReplay;

  /// Wait for async UI (API + navigation) before the next replay step.
  final BugSessionReplaySettle? replaySettle;

  /// Pause between replay steps so QA can follow the flow on screen.
  final Duration replayStepDelay;

  final BugSessionTryReplayAction? tryReplayAction;

  final BugSessionResolveReplayTapPosition? resolveReplayTapPosition;

  final BugSessionResolveRecorderTargetId? resolveRecorderTargetId;

  /// Host route name (e.g. auto_route [StackRouter.current.name]).
  final BugSessionCurrentRouteName? currentRouteName;

  /// Shadowplay rolling-buffer recording (save snapshot vs classic record/stop).
  final BugSessionShadowplaySettings shadowplay;

  /// GeForce-style: Shadowplay buffer always on + optional manual Record/Stop.
  final bool manualRecordWithShadowplay;

  /// Host hook after replay completes and Shadowplay resumes (e.g. flash).
  final BugSessionReplayFinished? onReplayFinished;

  /// When true, closing a BugSession bottom sheet re-expands the FAB panel.
  final bool expandPanelWhenSheetClosed;

  /// When set with [readyToTestDefaults], shows Ready to Test on the FAB panel.
  final ReadyToTestCredentialsStore? readyToTestStore;

  /// Status / property names for Notion filters (ids entered by QA in-app).
  final ReadyToTestSetupDefaults? readyToTestDefaults;

  bool get readyToTestEnabled =>
      readyToTestStore != null && readyToTestDefaults != null;

  BugSessionThemeData get resolvedTheme =>
      theme ?? BugSessionThemeData.defaults;
}
