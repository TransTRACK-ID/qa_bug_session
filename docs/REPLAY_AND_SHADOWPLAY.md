# Replay and Instant Replay (Shadowplay)

This document explains how **qa_bug_session** records clips and replays them against the **live backend**, and how host apps should wire navigation so replay stays consistent.

## Capture pipeline

```text
User input
  → BugSessionInteractionCaptureLayer (coordinate taps, session_start route)
  → Host NavigatorObserver (push/pop → navigation / back actions)
  → RecorderTap widgets (semantic recorder ids on BsAppButton, etc.)
  → RecorderInput widgets (text fields — debounced `textInput` actions + replay fill)
  → RollingEventBuffer (Shadowplay) or SemanticInteractionRecorder (full record)
```

**Instant Replay** keeps the last ~90s of actions in memory. **Save clip** snapshots that buffer into a `BugSession` (zip in the on-device library). Clips are **not** a screen recording substitute for navigation state—they are a **time-ordered action list** replayed step by step.

### `session_start` semantics

When Shadowplay capture starts, the interaction layer appends one navigation action with `"label":"session_start"`. That records **where the buffer began**, not a user-driven route change. Replay skips executing this marker.

Hosts may set `BugSessionConfig.activeNavbarTabRouteName` so the marker JSON includes optional `"activeTab":"HistoryRoute"` (etc.) while `"name"` remains the shell route. Bootstrap code should prefer `activeTab` when inferring the initial bottom-nav tab.

## What replay does

1. `prepareForReplay` (host): e.g. credential injector flags, replay context.
2. `replayBootstrap` (host): reset stack to a known route (login or home).
3. `bugSessionPrepareActionsForReplay` (package): trim/dedupe actions (also runs when saving a clip).
4. Credential injection (skipped for auth clips when host opts out).
5. Each action: wait (timestamps), `replayNavigation` / registry tap / coordinate tap, then `replaySettle`.

Replay **never** substitutes recorded HTTP responses. Network events in the zip are evidence only.

### QA overlay during replay

Coordinate replay injects synthetic pointer events at recorded `(globalX, globalY)`. If those coordinates overlap large BugSession chrome (e.g. the FAB control panel or QA objective panel), replay could cancel itself instead of tapping the app.

While `BugSessionReplayController.active`, QA objective chrome uses **hit-test passthrough** (`BugSessionReplayChromePassthrough`) so replay taps reach the host UI underneath. **Stop** is the top-right `REPLAY` status badge (`RecordingOverlay`) — tap it to call `requestStop`. The badge is a small hit target and is marked as BugSession chrome so capture ignores it.

## Literal 1:1 replay (recommended for QA)

Replay should match what the user saw, not a shortened path:

1. **Snapshot** developer `isFirstLaunch`, `hasSeenOnboarding`, and tokens before replay.
2. **Reset** persisted state to match the clip (e.g. first-launch + no token when onboarding/login are in the buffer).
3. **Bootstrap** to the first recorded navigation (skip replaying that one duplicate nav action).
4. **Replay every remaining action** (onboarding, login, taps, backs) against the **live API**.
5. **Restore** the developer snapshot after replay (`restoreSessionAfterReplay`).

Mobile technician: `bug_session_replay_state.dart`, `bug_session_credential_injector.dart` (prefs snapshot), `bug_session_kit.dart`.

Do **not** use `trimBeforeMainShell` or `dropOnboardingAndSplashNavigations` for this mode.

## Recording artifacts (not UX changes)

These dedupe steps remove **duplicate recorder events** so one user gesture does not replay twice:

### 2. Double push on detail screens (back needs two pops)

**Cause:** Opening a screen often records **both** a `navigation` push (observer) **and** a coordinate `tap` on the same InkWell/list row.

**Fix (package):** Dedupe a coordinate-only tap that follows a push navigation within ~1.5s when saving a clip and before replay.

**Fix (host):** Prefer `RecorderTap` on list rows where possible; avoid relying on coordinate-only taps for navigation.

### 3. Back button replay stuck on the same page

**Cause:** Material back `IconButton` records **both** a semantics `Back` tap and a `back` action from `didPop`.

**Fix (package):** Dedupe back-affordance tap + `back` within ~900ms.

**Fix (host):** Navigator observer may skip recording `back` when the previous action was a back tap (mobile technician `BugSessionNavigationObserver`).

### 4. Tap then bloc-driven push (TaskReview / TaskCompletion)

**Cause:** A button tap (Start/Continue on detail) triggers `Navigator.push` from a bloc listener **and** the observer records the same push as a `navigation` action.

**Fix (package):** Dedupe a push to `TaskReviewRoute` / `TaskCompletionRoute` that immediately follows a tap within ~4s when saving a clip and before replay.

**Fix (host):** Skip replay `push` when that route + task id is already on the stack; handle AppBar back taps on review/completion via `tryReplayAction` + `StackRouter.pop`.

### 5. Ambiguous registry wildcards (`*|Back`)

**Cause:** Codegen used to emit `*|Back` for onboarding, which could mis-resolve taps on other screens.

**Fix:** Registry codegen omits wildcard entries for ambiguous labels (`Back`, `Skip`, `Cancel`, …) and when the same label appears on multiple routes. Regenerate:

```bash
dart run ../qa_bug_session/tools/generate_recorder_registry.dart \
  --project-dir . \
  --output lib/generated/bug_session_recorder_registry.g.dart
```

## Text input (1:1 typing)

**Recording:** Wrap `TextFormField` / `TextField` subtrees with [`RecorderInput`](../lib/bug_session/ui/recorder_input.dart). Pass a stable `id` (e.g. `runtimeTextInputRecorderId(routeKey: …, fieldLabel: …)`) and the same `TextEditingController` the field uses. While capturing (full-record **or** Instant Replay), debounced `textInput` actions are appended with `metadata.recorderId`. **Every settled value is recorded, including empty** (deletes/clears). Focus loss flushes immediately so clear-and-blur is not lost.

**Fallback:** [`BugSessionInteractionCaptureLayer`](../lib/bug_session/ui/bug_session_interaction_capture_layer.dart) still snapshots `RenderEditable` text when fields are not wrapped; it flushes on field leave and copies tap metadata (`recorderId`, `semanticsLabel`, `screenRoute`). Empty text is recorded only when clearing a previously captured value for that target. Wrapped fields (semantics `identifier` set) skip the fallback to avoid duplicate rows.

**Replay:** For each `textInput` action, replay focuses the field (coordinates / registry tap when present), then `TextInputTargetRegistry.apply(id, text)` sets controller text and calls `onChanged` (empty string clears the field). Optional host hook: `BugSessionConfig.tryReplayTextInput`. Unwired fields are logged and skipped so the rest of the clip can continue.

**Verify:** Saved session → **What happened?** — typing and clears show as `textInput` steps (including `""`) with stable target ids.

## Host integration checklist (auto_route)

Full agent-oriented guide (search DS trap, workOrder fetch, Jam store, stop badge): **[HOST_IMPLEMENTATION.md](HOST_IMPLEMENTATION.md)**.

| Item | Requirement |
|------|-------------|
| Navigator key | Same instance as `AppRouter.navigatorKey` |
| Observer | `bugSessionNavigationObserver` on `router.delegate` |
| `replayNavigation` | Map route JSON → `push` / `navigate` / `replaceAll`; **fetch** rich args (e.g. `workOrder`) by id |
| Duplicate pushes | Skip review/completion (etc.) when tap already opened that route+id |
| `replayBootstrap` | First recorded route (literal 1:1) or login/home |
| `prepareForReplay` / restore | Snapshot developer prefs+auth; reset to match clip; restore after |
| `currentRouteName` | Tab-aware route for tap/text metadata |
| `resolveRecorderTargetId` | Generated registry lookup |
| Tappable chrome | `BsAppButton` + `RecorderTap`; raw `IconButton` uses coordinates + dedupe |
| Text fields | `RecorderInput` + shared `TextEditingController`; empty clears recorded (v1.5.3+) |
| Search fields | If DS `AppSearchField` ignores `controller`, host `TextFormField` + `RecorderInput` (do not wrap dead controller) |
| Stop replay | Top-right **`REPLAY`** badge (not a left Stop chip) |
| Jam | Pass `jamDevCredentialsStore` or Jam UI stays hidden |
| One-time funnels | For literal 1:1, **do not** strip onboarding/login; only skip in non-literal modes |

## API reference

- `bugSessionPrepareActionsForReplay` — `lib/bug_session/replay/bug_session_replay_action_filter.dart`
- `BugSessionReplayActionFilterOptions` — trim/dedupe flags
- `bugSessionSessionIncludesAuthentication` — auth bootstrap + credential skip
- `BugSessionConfig.prepareRecordedActionsForReplay` — host final pass

## Testing

Package tests: `test/replay_action_filter_test.dart`, `test/text_input_replay_test.dart`

Host: staging build → Instant Replay → login → task list → detail → back → Save clip → Replay. Expect no onboarding flash (after first launch) and a single back to task list.
