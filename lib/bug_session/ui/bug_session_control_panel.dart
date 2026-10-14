import 'dart:async';

import 'package:flutter/material.dart';

import '../../jam/jam_session_video_upload.dart';
import '../kit/bug_session_background_work.dart';
import '../kit/bug_session_kit.dart';
import '../models/bug_session.dart';
import '../kit/bug_session_modal_context.dart';
import '../kit/bug_session_theme.dart';
import '../recording/bug_session_recorder.dart';
import '../library/bug_session_catalog_entry.dart';
import '../library/bug_session_recording_kind.dart';
import '../replay/bug_session_replayer.dart';
import '../runtime/bug_session_environment.dart';
import 'bug_session_capture_mode.dart';
import 'bug_session_library_sheet.dart';
import 'bug_session_ready_to_test_sheet.dart';
import 'bug_session_name_dialog.dart';
import 'bug_session_replay_flow.dart';
import 'bug_session_panel_help.dart';
import 'bug_session_share_helper.dart';
import 'glass/glass_button.dart';
import 'glass/glass_panel.dart';

enum _BugSessionPanelCaptureStyle { shadowplay, manualRecord }

class BugSessionControlPanel extends StatefulWidget {
  const BugSessionControlPanel({super.key, required this.kit});

  final BugSessionKit kit;

  @override
  State<BugSessionControlPanel> createState() => _BugSessionControlPanelState();
}

class _BugSessionControlPanelState extends State<BugSessionControlPanel> {
  Offset _position = const Offset(16, 120);
  String _status = 'Idle';
  int _savedCount = 0;
  bool _finalizingSession = false;
  _BugSessionPanelCaptureStyle _captureStyle =
      _BugSessionPanelCaptureStyle.shadowplay;

  BugSessionKit get kit => widget.kit;
  BugSessionThemeData get theme => kit.config.resolvedTheme;

  @override
  void initState() {
    super.initState();
    _syncCaptureModeToKit();
    kit.controlPanelLayout.addListener(_onLayoutChanged);
    kit.replayController.addListener(_onLayoutChanged);
    kit.recorder.addListener(_onRecorderChanged);
    kit.catalog.watchEntries().listen((entries) {
      if (!mounted) return;
      setState(() => _savedCount = entries.length);
    });
  }

  @override
  void dispose() {
    kit.controlPanelLayout.removeListener(_onLayoutChanged);
    kit.replayController.removeListener(_onLayoutChanged);
    kit.recorder.removeListener(_onRecorderChanged);
    super.dispose();
  }

  void _onLayoutChanged() {
    if (!mounted) {
      return;
    }
    if (kit.controlPanelLayout.expanded) {
      unawaited(kit.sheetCoordinator.dismissAll(kit));
    }
    setState(() {});
  }

  void _onRecorderChanged() {
    if (mounted) setState(() {});
  }

  Future<BugSessionEnvironment?> _environment() async {
    await kit.config.refreshEnvironment?.call();
    return kit.config.environmentBuilder?.call();
  }

  bool get _dualCaptureModes =>
      kit.config.shadowplay.enabled && kit.config.manualRecordWithShadowplay;

  bool get _shadowplayUi {
    if (!kit.config.shadowplay.enabled) {
      return false;
    }
    if (!_dualCaptureModes) {
      return true;
    }
    return _captureStyle == _BugSessionPanelCaptureStyle.shadowplay;
  }

  void _syncCaptureModeToKit() {
    if (!_dualCaptureModes) {
      kit.captureMode.setMode(BugSessionPanelCaptureMode.instantReplay);
      return;
    }
    kit.captureMode.setMode(
      _shadowplayUi
          ? BugSessionPanelCaptureMode.instantReplay
          : BugSessionPanelCaptureMode.fullRecord,
    );
  }

  void _applyCaptureStyle(_BugSessionPanelCaptureStyle style) {
    setState(() {
      _captureStyle = style;
      if (style == _BugSessionPanelCaptureStyle.shadowplay) {
        _status = 'Instant Replay · '
            '${kit.config.shadowplay.defaultVideoRetention.inSeconds}s buffer';
      } else {
        _status = 'Full Record — tap Start session';
      }
    });
    _syncCaptureModeToKit();
  }

  Future<void> _record() async {
    if (_finalizingSession) {
      return;
    }
    await kit.recorder.start();
    kit.controlPanelLayout.collapse();
    setState(() => _status = 'Recording…');
  }

  Future<void> _saveShadowplayClip() async {
    if (_finalizingSession || kit.backgroundWork.active) {
      return;
    }
    setState(() => _finalizingSession = true);

    var env = kit.config.environmentBuilder?.call();
    if (env == null) {
      await kit.config.refreshEnvironment?.call();
      env = kit.config.environmentBuilder?.call();
    } else {
      unawaited(kit.config.refreshEnvironment?.call());
    }
    if (env == null) {
      setState(() {
        _finalizingSession = false;
        _status = 'BugSession environment is not configured';
      });
      return;
    }

    Future<Map<String, List<int>>>? videoEncode;
    String? displayName;
    BugSession? session;
    var actionCount = 0;

    try {
      await kit.backgroundWork.run(
        config: kit.config,
        title: 'Saving clip',
        startToast: 'Saving clip…',
        successToast: 'Saved clip',
        errorToastPrefix: 'Save failed',
        phases: [
          BugSessionWorkPhase(
            label: 'Preparing clip',
            weight: 1,
            run: (r) async {
              r(0);
              await kit.recorder.haltShadowplayMediaForSave();
              kit.controlPanelLayout.collapse();
              videoEncode = kit.recorder.finalizeDeferredVideoCapture();
              r(1);
            },
          ),
          BugSessionWorkPhase(
            label: 'Name clip',
            weight: 0.2,
            run: (r) async {
              if (mounted) {
                displayName = await showBugSessionNameDialog(
                  requireBugSessionModalContext(kit.config, fallback: context),
                );
              }
              r(1);
            },
          ),
          BugSessionWorkPhase(
            label: 'Encoding video',
            weight: 2.5,
            run: (r) async {
              r(0);
              final visualFiles = await videoEncode!;
              r(0.5);
              session = await kit.recorder.buildShadowplayClipSession(env!);
              actionCount = session!.actions.length;
              final clipTitle = displayName ??
                  defaultBugSessionDisplayName(
                    startedAt: session!.manifest.startedAt,
                    actionCount: actionCount,
                  );
              final planned = await finalizeSessionVideoForCatalog(
                kit,
                visualArchiveFiles: visualFiles,
                title: clipTitle,
                onJamUploadProgress: r,
              );
              r(0.8);
              await kit.catalog.addFromStoppedSession(
                session!,
                visualArchiveFiles: planned.archiveFiles,
                displayName: displayName,
                jamShareUrl: planned.jamShareUrl,
                recordingKind: BugSessionRecordingKind.instantReplay,
              );
              if (planned.jamShareUrl != null) {
                await kit.catalog.purgeVideoForSession(
                  session!.manifest.sessionId,
                );
              }
              kit.recorder.restoreLastSession(session!);
              r(1);
            },
          ),
        ],
      );
      if (mounted) {
        setState(() => _status = 'Saved clip · $actionCount action(s)');
      }
    } catch (_) {
      await kit.recorder.recoverFromHaltedShadowplaySave();
      if (mounted) {
        setState(() => _status = 'Save failed');
      }
    } finally {
      if (mounted) {
        setState(() => _finalizingSession = false);
      } else {
        _finalizingSession = false;
      }
    }
  }

  Future<void> _stop() async {
    if (_finalizingSession || kit.backgroundWork.active) {
      return;
    }
    setState(() => _finalizingSession = true);
    try {
      await kit.config.refreshEnvironment?.call();
      final env = kit.config.environmentBuilder?.call();
      if (env == null) {
        setState(() => _status = 'BugSession environment is not configured');
        return;
      }

      BugSession? session;
      String? displayName;
      var actionCount = 0;

      await kit.backgroundWork.run(
        config: kit.config,
        title: 'Saving recording',
        startToast: 'Saving session…',
        successToast: 'Recording saved',
        errorToastPrefix: 'Save failed',
        phases: [
          BugSessionWorkPhase(
            label: 'Stopping recording',
            weight: 1,
            run: (r) async {
              r(0);
              session = await kit.recorder.stop(env);
              kit.controlPanelLayout.collapse();
              r(1);
            },
          ),
          BugSessionWorkPhase(
            label: 'Name session',
            weight: 0.2,
            run: (r) async {
              if (mounted) {
                displayName = await showBugSessionNameDialog(
                  requireBugSessionModalContext(kit.config, fallback: context),
                );
              }
              r(1);
            },
          ),
          BugSessionWorkPhase(
            label: 'Uploading & saving',
            weight: 3,
            run: (r) async {
              r(0);
              final visualFiles = kit.recorder.takeVisualArchiveFiles();
              actionCount = session!.actions.length;
              final stopTitle = displayName ??
                  defaultBugSessionDisplayName(
                    startedAt: session!.manifest.startedAt,
                    actionCount: actionCount,
                  );
              final planned = await finalizeSessionVideoForCatalog(
                kit,
                visualArchiveFiles: visualFiles,
                title: stopTitle,
                onJamUploadProgress: r,
              );
              r(0.6);
              await kit.catalog.addFromStoppedSession(
                session!,
                visualArchiveFiles: planned.archiveFiles,
                displayName: displayName,
                jamShareUrl: planned.jamShareUrl,
                recordingKind: BugSessionRecordingKind.fullRecord,
              );
              if (planned.jamShareUrl != null) {
                await kit.catalog.purgeVideoForSession(
                  session!.manifest.sessionId,
                );
              }
              kit.recorder.restoreLastSession(session!);
              if (kit.config.manualRecordWithShadowplay &&
                  kit.config.shadowplay.enabled) {
                await kit.recorder.resumeShadowplayCapture();
              }
              r(1);
            },
          ),
        ],
      );
      if (mounted) {
        setState(() => _status = 'Stopped · $actionCount action(s)');
      }
    } catch (_) {
      if (kit.config.manualRecordWithShadowplay &&
          kit.config.shadowplay.enabled) {
        await kit.recorder.resumeShadowplayCapture();
      }
      if (mounted) {
        setState(() => _status = 'Save failed');
      }
    } finally {
      if (mounted) {
        setState(() => _finalizingSession = false);
      } else {
        _finalizingSession = false;
      }
    }
  }

  Future<String?> _resolveLastSessionId() async {
    final last = kit.recorder.lastSession;
    if (last != null) {
      return last.manifest.sessionId;
    }
    final persisted = await kit.catalog.getLastSessionId();
    if (persisted != null && await kit.catalog.containsSession(persisted)) {
      return persisted;
    }
    final entries = await kit.catalog.listEntries();
    if (entries.isEmpty) {
      return null;
    }
    return entries.first.sessionId;
  }

  Future<BugSession> _loadSessionForReplay(String sessionId) async {
    final last = kit.recorder.lastSession;
    if (last != null && last.manifest.sessionId == sessionId) {
      return last;
    }
    return kit.catalog.loadSession(sessionId);
  }

  Future<void> _exportLast() async {
    final sessionId = await _resolveLastSessionId();
    if (sessionId == null) {
      if (_savedCount == 0) {
        setState(() => _status = 'No saved sessions to export');
      }
      return;
    }
    if (kit.backgroundWork.active) {
      return;
    }
    try {
      late BugSessionCatalogEntry entry;
      await kit.backgroundWork.run(
        config: kit.config,
        title: 'Exporting session',
        startToast: 'Exporting session…',
        successToast: 'Session exported',
        errorToastPrefix: 'Export failed',
        phases: [
          BugSessionWorkPhase(
            label: 'Writing zip',
            weight: 1,
            run: (r) async {
              r(0);
              entry = await kit.catalog.exportSessionToDisk(sessionId);
              r(1);
            },
          ),
        ],
      );
      final path = entry.filePath;
      if (path != null &&
          kit.config.shareExport != null &&
          kit.config.openShareSheetAfterExport) {
        try {
          await shareBugSessionCatalogEntry(kit: kit, entry: entry);
          setState(
            () => _status =
                'Share sheet opened — pick WhatsApp or another app',
          );
          return;
        } catch (e) {
          setState(() => _status = 'Export saved; share failed: $e');
          return;
        }
      }
      setState(
        () => _status = path != null
            ? 'Exported (app storage — use Share from saved session)'
            : 'Exported to device storage',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Export failed');
      }
    }
  }

  Future<void> _import() async {
    final picker = kit.config.filePicker;
    if (picker == null) {
      setState(() => _status = 'Configure BugSessionConfig.filePicker');
      return;
    }
    if (kit.backgroundWork.active) {
      return;
    }
    final bytes = await picker.pickBugSessionZip();
    if (bytes == null) {
      return;
    }
    try {
      await kit.backgroundWork.run(
        config: kit.config,
        title: 'Importing session',
        startToast: 'Importing session…',
        successToast: 'Session imported',
        errorToastPrefix: 'Import failed',
        phases: [
          BugSessionWorkPhase(
            label: 'Reading zip',
            weight: 1,
            run: (r) async {
              r(0);
              await kit.catalog.importFromZipBytes(bytes);
              r(1);
            },
          ),
        ],
      );
      setState(() => _status = 'Imported session');
      if (kit.config.openLibraryAfterImport && mounted) {
        await BugSessionLibrarySheet.show(
          requireBugSessionModalContext(kit.config, fallback: context),
          kit: kit,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Import failed');
      }
    }
  }

  Future<void> _replayLast() async {
    final sessionId = await _resolveLastSessionId();
    if (sessionId == null) {
      if (_savedCount == 0) {
        setState(() => _status = 'No saved sessions to replay');
      }
      return;
    }
    await _replaySession(sessionId);
  }

  Future<void> _replaySession(String sessionId) async {
    await kit.config.refreshEnvironment?.call();
    final env = kit.config.environmentBuilder?.call();
    if (env == null) {
      setState(() => _status = 'BugSession environment is not configured');
      return;
    }
    final confirmed = await bugSessionConfirmReplay(
      kit,
      fallbackContext: context,
    );
    if (confirmed != true) {
      return;
    }

    bugSessionPopModalIfOpen(kit);
    try {
      final session = await _loadSessionForReplay(sessionId);
      final result = await bugSessionRunReplay(
        kit: kit,
        session: session,
        current: env,
        onLockFailureFlash: (msg) {
          if (mounted) {
            setState(() => _status = msg);
          }
        },
      );
      if (result == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      if (result.actionsAttempted == 0) {
        setState(
          () => _status =
              'Replay: no recorded actions (navigate or use RecorderTap while recording)',
        );
      } else {
        setState(() {
          if (result.cancelled) {
            _status =
                'Replay stopped (${result.actionsSucceeded}/${result.actionsAttempted})';
          } else {
            _status = result.success
                ? 'Replay OK (${result.actionsSucceeded}/${result.actionsAttempted})'
                : 'Replay failed: ${result.failure?.reason}';
          }
        });
      }
    } on ReplayBlockedException catch (e) {
      if (mounted) {
        setState(() => _status = e.flashMessage);
      }
    } catch (e) {
      kit.replayController.end();
      kit.chromeVisibility.show();
      if (mounted) {
        setState(() => _status = 'Replay failed: $e');
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    setState(() {
      _position += details.delta;
      _position = Offset(
        _position.dx.clamp(padding.left, size.width - padding.right - 72),
        _position.dy.clamp(padding.top, size.height - padding.bottom - 72),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadowplayEnabled = kit.config.shadowplay.enabled;
    final recording = kit.recorder.isRecording;
    final stopping =
        kit.recorder.state == BugSessionRecorderState.stopping;
    final busy =
        stopping || recording || _finalizingSession || kit.backgroundWork.active;
    final bufferSeconds =
        kit.config.shadowplay.defaultVideoRetention.inSeconds;
    final hasSaved = _savedCount > 0;
    final expanded = kit.controlPanelLayout.expanded;
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Semantics(
        label: 'BugSession',
        container: true,
        child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: expanded
              ? Material(
                  color: Colors.transparent,
                  child: GlassPanel(
                  theme: theme,
                  child: SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if ((shadowplayEnabled && _shadowplayUi) || recording)
                              const Icon(
                                Icons.fiber_manual_record,
                                color: Colors.redAccent,
                                size: 12,
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Semantics(
                                label: 'BugSession',
                                container: true,
                                child: const Text(
                                  'BugSession',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => showBugSessionPanelHelp(
                                context,
                                kit: kit,
                                bufferSeconds: bufferSeconds,
                                dualCaptureModes: _dualCaptureModes,
                              ),
                              icon: const Icon(
                                Icons.info_outline,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: kit.controlPanelLayout.collapse,
                              icon: const Icon(Icons.expand_more, color: Colors.white70),
                            ),
                          ],
                        ),
                        Text(
                          _shadowplayUi
                              ? 'Instant Replay · ${bufferSeconds}s buffer'
                              : 'Full session record',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_dualCaptureModes) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _CaptureModeSegment(
                                  theme: theme,
                                  label: 'Instant Replay',
                                  selected: _shadowplayUi,
                                  enabled: !busy,
                                  onTap: () => _applyCaptureStyle(
                                    _BugSessionPanelCaptureStyle.shadowplay,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CaptureModeSegment(
                                  theme: theme,
                                  label: 'Full Record',
                                  selected: !_shadowplayUi,
                                  enabled: !busy,
                                  onTap: () => _applyCaptureStyle(
                                    _BugSessionPanelCaptureStyle.manualRecord,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        _PrimaryCaptureButton(
                          theme: theme,
                          shadowplayUi: _shadowplayUi,
                          shadowplayEnabled: shadowplayEnabled,
                          recording: recording,
                          stopping: stopping,
                          busy: busy,
                          onSaveClip: _saveShadowplayClip,
                          onStartSession: _record,
                          onEndSession: _stop,
                        ),
                        const SizedBox(height: 10),
                        if (hasSaved) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              GlassButton(
                                theme: theme,
                                label: 'Export last',
                                onPressed: busy ? null : _exportLast,
                              ),
                              GlassButton(
                                theme: theme,
                                label: 'Replay last',
                                onPressed: busy ? null : _replayLast,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        GlassButton(
                          theme: theme,
                          label: 'Saved sessions ($_savedCount)',
                          onPressed: () async {
                            try {
                              await BugSessionLibrarySheet.show(
                                context,
                                kit: kit,
                              );
                            } on StateError catch (e) {
                              setState(() => _status = e.message);
                            }
                          },
                        ),
                        if (kit.config.readyToTestEnabled) ...[
                          const SizedBox(height: 6),
                          GlassButton(
                            theme: theme,
                            label: 'Ready to Test',
                            onPressed: () async {
                              try {
                                await BugSessionReadyToTestSheet.show(
                                  context,
                                  kit: kit,
                                );
                              } on StateError catch (e) {
                                setState(() => _status = e.message);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        GlassButton(
                          theme: theme,
                          label: 'Import .zip',
                          onPressed: busy ? null : _import,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: kit.controlPanelLayout.expand,
                    borderRadius: BorderRadius.circular(24),
                    child: GlassPanel(
                      theme: theme,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (recording)
                            Container(
                              width: 3,
                              height: 8,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          Container(
                            width: 3,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
      ),
    );
  }
}

class _CaptureModeSegment extends StatelessWidget {
  const _CaptureModeSegment({
    required this.theme,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final BugSessionThemeData theme;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.cornerRadius - 4);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected
            ? theme.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? theme.accent : theme.borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCaptureButton extends StatelessWidget {
  const _PrimaryCaptureButton({
    required this.theme,
    required this.shadowplayUi,
    required this.shadowplayEnabled,
    required this.recording,
    required this.stopping,
    required this.busy,
    required this.onSaveClip,
    required this.onStartSession,
    required this.onEndSession,
  });

  final BugSessionThemeData theme;
  final bool shadowplayUi;
  final bool shadowplayEnabled;
  final bool recording;
  final bool stopping;
  final bool busy;
  final VoidCallback onSaveClip;
  final VoidCallback onStartSession;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context) {
    if (shadowplayUi && shadowplayEnabled) {
      return GlassButton(
        theme: theme,
        label: 'Save clip',
        filled: true,
        expand: true,
        onPressed: busy ? null : onSaveClip,
      );
    }

    if (recording && !stopping) {
      return GlassButton(
        theme: theme,
        label: 'End session',
        expand: true,
        onPressed: onEndSession,
      );
    }

    return GlassButton(
      theme: theme,
      label: 'Start session',
      filled: true,
      expand: true,
      onPressed: busy ? null : onStartSession,
    );
  }
}
