import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../library/bug_session_catalog.dart';
import '../library/bug_session_store.dart';
import '../recording/bug_session_recorder.dart';
import '../recording/bug_session_video_visual_capture.dart';
import '../recording/bug_session_visual_capture.dart';
import '../recording/semantic_interaction_recorder.dart';
import '../replay/bug_session_replay_controller.dart';
import '../replay/bug_session_replayer.dart';
import '../ui/bug_session_capture_mode.dart';
import '../ui/bug_session_chrome_visibility.dart';
import '../ui/bug_session_control_panel_layout.dart';
import '../ui/bug_session_overlay.dart';
import '../ui/bug_session_sheet_coordinator.dart';
import '../ui/bug_session_tap_ripple_notifier.dart';
import 'bug_session_config.dart';
import 'bug_session_dio_interceptor.dart';
import 'bug_session_scope.dart';

class BugSessionKit {
  BugSessionKit._({
    required this.config,
    required this.recorder,
    required this.catalog,
    required this.replayer,
  })  : chromeVisibility = BugSessionChromeVisibility(),
        tapRipples = BugSessionTapRippleNotifier(),
        controlPanelLayout = BugSessionControlPanelLayout(),
        captureMode = BugSessionCaptureMode(),
        replayController = BugSessionReplayController(),
        sheetCoordinator = BugSessionSheetCoordinator();

  final BugSessionConfig config;
  final BugSessionRecorder recorder;
  final FileBugSessionCatalog catalog;
  final BugSessionReplayer replayer;
  final BugSessionChromeVisibility chromeVisibility;
  final BugSessionTapRippleNotifier tapRipples;
  final BugSessionControlPanelLayout controlPanelLayout;
  final BugSessionCaptureMode captureMode;
  final BugSessionReplayController replayController;
  final BugSessionSheetCoordinator sheetCoordinator;

  /// Prepares catalog storage. Call from `main()` before `runApp` when using
  /// the default documents directory (no [BugSessionConfig.storageDirectory]).
  static Future<BugSessionKit> initialize({
    required BugSessionConfig config,
  }) async {
    final root = config.storageDirectory ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}/bug-sessions',
        );
    final kit = BugSessionKit._(
      config: config,
      recorder: BugSessionRecorder(
        visualCapture: _pngVisualCaptureFromConfig(config),
        videoCapture: _videoVisualCaptureFromConfig(config),
        shadowplaySettings: config.shadowplay,
      ),
      catalog: FileBugSessionCatalog(store: BugSessionStore(root)),
      replayer: BugSessionReplayer(
        credentialInjector: config.credentialInjector,
        interactionRecorder: SemanticInteractionRecorder(
          replayNavigation: config.replayNavigation,
          replayStepDelay: config.replayStepDelay,
          replaySettle: config.replaySettle,
          tryReplayAction: config.tryReplayAction,
          resolveReplayTapPosition: config.resolveReplayTapPosition,
          resolveRecorderTargetId: config.resolveRecorderTargetId,
        ),
        validateUserIdentityOnReplay: config.validateUserIdentityOnReplay,
        restoreSessionAfterReplay: config.restoreSessionAfterReplay,
        replayBootstrap: config.replayBootstrap,
        prepareForReplay: config.prepareForReplay,
      ),
    );
    if (config.enabled) {
      await kit.catalog.listEntries();
      await kit.catalog.restoreRecorderLastSession(kit.recorder);
      if (config.shadowplay.enabled) {
        await kit.recorder.startShadowplay();
      }
    }
    return kit;
  }

  /// Synchronous init when [BugSessionConfig.storageDirectory] is already set.
  static BugSessionKit initializeSync({required BugSessionConfig config}) {
    final root = config.storageDirectory;
    assert(
      root != null,
      'initializeSync requires BugSessionConfig.storageDirectory',
    );
    final kit = BugSessionKit._(
      config: config,
      recorder: BugSessionRecorder(
        visualCapture: _pngVisualCaptureFromConfig(config),
        videoCapture: _videoVisualCaptureFromConfig(config),
        shadowplaySettings: config.shadowplay,
      ),
      catalog: FileBugSessionCatalog(store: BugSessionStore(root!)),
      replayer: BugSessionReplayer(
        credentialInjector: config.credentialInjector,
        interactionRecorder: SemanticInteractionRecorder(
          replayNavigation: config.replayNavigation,
          replayStepDelay: config.replayStepDelay,
          replaySettle: config.replaySettle,
          tryReplayAction: config.tryReplayAction,
          resolveReplayTapPosition: config.resolveReplayTapPosition,
          resolveRecorderTargetId: config.resolveRecorderTargetId,
        ),
        validateUserIdentityOnReplay: config.validateUserIdentityOnReplay,
        restoreSessionAfterReplay: config.restoreSessionAfterReplay,
        replayBootstrap: config.replayBootstrap,
        prepareForReplay: config.prepareForReplay,
      ),
    );
    if (config.enabled && config.shadowplay.enabled) {
      unawaited(kit.recorder.startShadowplay());
    }
    return kit;
  }

  /// Drops in-memory [BugSessionRecorder.lastSession] when catalog entry is gone.
  void discardLastSessionIfDeleted(String sessionId) {
    final last = recorder.lastSession;
    if (last?.manifest.sessionId == sessionId) {
      recorder.discardLastSession();
    }
  }

  /// When [config.enabled] is false, returns [app] unchanged.
  Widget wrap({required Widget app}) {
    if (!config.enabled) return app;
    return BugSessionScope(
      kit: this,
      child: app,
    );
  }

  /// Chain with an existing [MaterialApp.builder] (recommended for overlays).
  TransitionBuilder wrapMaterialAppBuilder([
    TransitionBuilder? existing,
  ]) {
    if (!config.enabled) {
      return existing ?? (context, child) => child ?? const SizedBox.shrink();
    }
    return (context, child) {
      final built = existing?.call(context, child) ?? child;
      return BugSessionOverlayStack(
        kit: this,
        child: built ?? const SizedBox.shrink(),
      );
    };
  }

  void attachDio(Dio dio) {
    if (!config.enabled) return;
    dio.interceptors.add(BugSessionDioInterceptor(recorder));
  }

  static BugSessionVisualCapture? _pngVisualCaptureFromConfig(
    BugSessionConfig config,
  ) {
    if (config.videoCapture != null) {
      return null;
    }
    final capture = config.screenshotCapture;
    if (capture == null) {
      return null;
    }
    return BugSessionVisualCapture(
      capturePng: capture,
      interval: config.screenshotInterval,
      maxFrames: config.maxScreenshotFrames,
    );
  }

  static BugSessionVideoVisualCapture? _videoVisualCaptureFromConfig(
    BugSessionConfig config,
  ) {
    final capture = config.videoCapture;
    if (capture == null) {
      return null;
    }
    return BugSessionVideoVisualCapture(
      capture: capture,
      maxDuration: config.maxVideoDuration,
    );
  }
}
