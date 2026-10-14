# Changelog

All notable changes are documented here. **1.0.0** is the first stable release; prior `0.x` tags on GitHub were pre-release iteration and are no longer maintained.

## 1.5.4

- **Docs:** [docs/HOST_IMPLEMENTATION.md](docs/HOST_IMPLEMENTATION.md) — agent checklist for new hosts (navigator key, `RecorderInput`, DS search trap, rich route args, Jam store, `REPLAY` stop). README and replay doc link to it.

## 1.5.3

- **Text capture:** Record empty/cleared field values (deletes), flush on focus loss, and append text inputs during Instant Replay/Shadowplay via `recordCapturedTextInput`.

## 1.5.2

- **Replay stop:** Removed the left "Replay | Stop" chip. Tap the top-right `REPLAY` badge to stop replay.

## 1.5.1

- **Text replay:** `TextInputTargetRegistry` + `RecorderInput` for debounced capture and controller fill on replay; `BugSessionConfig.tryReplayTextInput` host hook.
- **Capture:** Interaction layer flushes final editable text on field leave and copies tap metadata into `textInput` actions; skips fallback when `recorderId` is wired.
- **Docs:** Text input section in [docs/REPLAY_AND_SHADOWPLAY.md](docs/REPLAY_AND_SHADOWPLAY.md).

## 1.5.0

- **Background work:** Global top progress banner (0–100%) for save clip, full record, export/import, Jam/Notion uploads, QA pass/issue/stop, Ready to Test sync, and bulk export.
- **Toasts:** Start/success/error flashes via `BugSessionTaskToasts` / extended `BugSessionFlash` duration.
- **Uploads:** Byte-level progress for Jam media PUT and Notion file upload multipart POST.

## 1.4.2

- **Saved sessions:** Recording kind labels (Instant Replay, Full Record, QA testing, Imported) on catalog rows; legacy index entries infer QA/imported where possible.
- **Saved sessions:** Multi-select bulk export (device zips only) and bulk delete in the library sheet.
- **Export:** Zip filenames use `{displayName}_BugSesh.zip` with optional session-id suffix on collision.

## 1.4.1

- **Replay:** `bugSessionPrepareActionsForReplay` trims one-time funnel routes, dedupes navigation+tap and back+tap pairs; applied on Shadowplay **Save clip** and before live replay.
- **Config:** `prepareRecordedActionsForReplay` host hook; registry codegen skips ambiguous `*|label` wildcards (`Back`, `Skip`, …).
- **Docs:** [docs/REPLAY_AND_SHADOWPLAY.md](docs/REPLAY_AND_SHADOWPLAY.md).

## 1.4.0

- **QA card testing mode:** Start from Ready to Test, full-record capture, draggable glass objective checklist, pass (Ready Code Review + PASSED ✅ + Jam) and generate issue (Notion child bug + Jam slice + BugSession zip comment).
- **Notion:** Issue service (create/update bug cards, comments, template body sections), manual status chips, extended API client.
- **Jam.dev:** PAT + GraphQL video upload client; credentials in Ready to Test settings alongside Notion.
- **UX:** Thin-line FAB handle, hide recording badge/ripples during card testing (objective panel stays), top flash toasts, Android ongoing notification with Stop testing.

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
