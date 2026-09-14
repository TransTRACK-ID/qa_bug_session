# Changelog

All notable changes are documented here. **1.0.0** is the first stable release; prior `0.x` tags on GitHub were pre-release iteration and are no longer maintained.

## 1.1.0

- **Default video host** in-package: `BugSessionDefaultVideoCapture`, `wrapBugSessionDefaultVideoHost` (ScreenRecorder + MP4 encoder deps on package).
- **Zero-touch setup**: `tools/setup_bug_session.dart` scans the app, generates `lib/bug_session/`, patches main/app/router/Dio, always runs registry codegen.
- Registry codegen skips dynamic `\$…` button labels.

## 1.0.0

- **Capture:** Instant Replay (Shadowplay buffer) and Full Record modes; unified FAB control panel; recording overlay states (SHADOWPLAY / RECORD / Saving / REPLAY).
- **Persistence:** Session catalog with `index.json` v2, per-session zip under `sessions/`, `lastSessionId`, restore on kit init.
- **Replay:** Coordinate and registry-based taps; chrome hit-test skip; replay-last from memory or catalog; navigation replay with async route push and settle pauses.
- **Export / library:** Saved sessions sheet, optional name on stop, timeline (“What happened?”), share zip with video sidecar.
- **Host integration:** `BugSessionConfig` hooks (`tryReplayAction`, `resolveReplayTapPosition`, `resolveRecorderTargetId`), credential inject/restore options, Dio attachment.
- **Codegen:** `tools/generate_recorder_registry.dart` scans host `lib/` and emits `bug_session_recorder_registry.g.dart`; optional `AppButton` → `BsAppButton` codemod.
- **Stability:** Mutable catalog entry list on load; finalize lock blocks record and mode switches until save/end completes.
