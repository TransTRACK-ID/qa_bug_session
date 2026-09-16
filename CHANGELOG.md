# Changelog

All notable changes are documented here. **1.0.0** is the first stable release; prior `0.x` tags on GitHub were pre-release iteration and are no longer maintained.

## 1.3.2

- **Ready to Test:** Opens from the BugSession FAB panel (glass bottom sheet + inner navigator, same as Saved sessions). No separate FAB on the app root — fixes Navigator context errors.
- **Notion credentials:** QA enters integration token, data source id, QA user id (and optional product) in-app; setup no longer bakes ids into the host.
- **`BugSessionConfig`:** `readyToTestStore` + `readyToTestDefaults`.

## 1.3.1

- **Setup:** `BugSessionStorage` no longer calls `userRepository` before GetIt registration (maritime-style apps); detects `kUserId` / `kKeyProfileName` for secure-storage hosts; auto_route scan from `@AutoRouterConfig`; pubspec bump from `v1.2.0`.

## 1.3.0

- **Ready to Test zero-touch setup:** `setup_bug_session.dart` generates Notion defaults, secure storage, and in-app FAB overlay; flags `--notion-data-source-id`, `--notion-qa-user-id`, `--notion-product`.
- **Package UI:** `ReadyToTestToolsHost` (queue, detail, checklist submit to Notion).

## 1.2.0

- **Ready to Test (Notion):** Dart client (`NotionClient`, `ReadyToTestService`, `NotionTaskStatusService`) for filtered list, read-only task detail, and to-do checkbox sync.
- **`tools/nts`:** subcommands `list`, `show`, `sync-todos` alongside legacy status updates; documented in `docs/NOTION_READY_TO_TEST.md`.

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
