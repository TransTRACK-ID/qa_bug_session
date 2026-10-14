# Host implementation guide (agents)

Use this checklist when wiring **qa_bug_session** into a **new** Flutter app. Setup scripts generate a skeleton; **replay fidelity depends on host work** that agents often skip.

**Package:** [README](../README.md) · [ARCHITECTURE](../ARCHITECTURE.md) · [REPLAY_AND_SHADOWPLAY](REPLAY_AND_SHADOWPLAY.md) · [NOTION_READY_TO_TEST](NOTION_READY_TO_TEST.md) · [tools/README](../tools/README.md)

**Reference host:** TransTRACK `regist-mobile-technician` (`lib/bug_session/`, `lib/widgets/bs_app_*.dart`, `docs/BUG_SESSION.md`).

Minimum package version for this guide: **v1.5.3** (empty text clears, `REPLAY` badge stop, text registry).

---

## 0. Do not assume zero-touch is enough

`tools/setup_bug_session.dart` / `setup_bug_session.sh`:

- Generates `lib/bug_session/`, patches main / app / Dio, runs registry codegen.
- Defaults to **GoRouter** patterns; **auto_route** hosts must fix navigator key + observer (see §2).
- Does **not** wrap text/search fields, does **not** implement rich route args for replay, does **not** generate Jam credential storage.

Treat setup as day-0 scaffolding. Complete every section below before claiming “BugSession is integrated.”

---

## 1. Dependency and gate

```yaml
# Prefer git tag in CI; path only for local package iteration
qa_bug_session:
  git:
    url: https://github.com/TransTRACK-ID/qa_bug_session.git
    ref: v1.5.3
```

1. `enabled` / flavor gate: **dev / development / staging only** — never production/store.
2. Call `BugSessionKit.initialize` once from the gated main (e.g. `main_staging.dart`).
3. Wrap root with `kit.wrap` and `MaterialApp.builder: kit.wrapMaterialAppBuilder(...)`.
4. `kit.attachDio(dio)` on the shared API client.
5. Gate UI wrappers (`BsAppButton`, `RecorderInput`) behind the same flavor check so release builds stay clean.

Bootstrap:

```bash
# From host app root (sibling clone of qa_bug_session)
../qa_bug_session/tools/setup_bug_session.sh --force
```

---

## 2. Navigator key and observer (critical)

| Router | Requirement |
|--------|-------------|
| **auto_route** | `bugSessionNavigatorKey` **must be** `AppRouter.navigatorKey` (same instance). Never `GlobalKey()` in generated navigation glue. Pass that key on `BugSessionConfig.navigatorKey`. Attach `bugSessionNavigationObserver` via `router.delegate(navigatorObservers: …)`. |
| **GoRouter** | Same `navigatorKey` on `GoRouter` and config; observer on the router. |

Wrong key → Ready to Test / library sheets fail with “navigatorKey with an active route” or silent overlay failures while the app looks fine.

---

## 3. `BugSessionConfig` hooks (required vs optional)

### Required for usable replay

| Hook | Purpose |
|------|---------|
| `credentialInjector` | Inject QA session user; optional snapshot/restore for literal 1:1 |
| `environmentBuilder` | Package id, app version, user id into export lock |
| `navigatorKey` | Modals / Ready to Test / library |
| `replayNavigation` | Map recorded route JSON → live `push` / `navigate` / `replaceAll` |
| `replayBootstrap` | Land on first clip route (or login/home); set skip-duplicate for that nav |
| `currentRouteName` | Tab-aware route name for tap/text metadata |
| `resolveRecorderTargetId` | Generated registry lookup |

### Strongly recommended

| Hook | Purpose |
|------|---------|
| `prepareForReplay` | Reset first-launch / onboarding / auth to match clip; capture developer snapshot |
| `restoreSessionAfterReplay: true` | Return developer session after replay |
| `tryReplayAction` | Login tap, AppBar back on detail/review, other host-only gestures |
| `replaySettle` | Wait for API + navigation before next step |
| `activeNavbarTabRouteName` | Bottom-nav tab in `session_start` marker |
| `shareExport` / `filePicker` | Export and import UX |
| `videoCapture` + `wrapBugSessionDefaultVideoHost` | Screen recording sidecar |
| `readyToTestStore` + `readyToTestDefaults` | Notion Ready to Test |
| `jamDevCredentialsStore` | **Required for Jam fields** — setup does not generate this; UI stays hidden until set |

### Optional

| Hook | Purpose |
|------|---------|
| `tryReplayTextInput` | Override default `TextInputTargetRegistry.apply` |
| `prepareRecordedActionsForReplay` | Extra trim after package dedupe |
| `resolveReplayTapPosition` / `resolveTapScreenLabel` | Better tap metadata |
| `uploadIssueZipBytes` | Host CDN for issue zip URLs |

---

## 4. Taps — `RecorderTap` / design-system buttons

1. Prefer semantic taps: wrap buttons with `RecorderTap` (or host `BsAppButton` that embeds it).
2. If the DS button absorbs pointers, put `IgnorePointer` on the **inner** button so `RecorderTap` receives the hit.
3. Regenerate registry after adding/renaming labels:

```bash
dart run ../qa_bug_session/tools/generate_recorder_registry.dart \
  --project-dir . \
  --output lib/generated/bug_session_recorder_registry.g.dart
```

4. Ambiguous labels (`Back`, `Skip`, `Cancel`, …) are not emitted as `*|label` wildcards — handle via `tryReplayAction` or coordinates + package dedupe.

---

## 5. Text input — do not skip (1:1 typing)

Without this, replay types nothing; Instant Replay / full record also miss deletes.

1. Every important `TextField` / `TextFormField` (login, search, forms): wrap with **`RecorderInput`**.
2. Pass a **stable** `id` — e.g. `runtimeTextInputRecorderId(routeKey: …, fieldLabel: …)` — and the **same** `TextEditingController` the field uses.
3. Optional host helper (flavor-gated):

```dart
Widget wrapBugSessionInput({
  required String fieldLabel,
  required TextEditingController controller,
  required Widget child,
  String? recorderId,
  void Function(String)? onChanged,
}) { /* RecorderInput when tools enabled */ }
```

4. **Empty values are recorded** (clears/deletes). Focus loss flushes immediately. Do not filter out `""`.
5. Fallback capture exists for unwired fields but is weaker; wrapped fields skip fallback to avoid duplicates.
6. Verify in Saved session → **What happened?** — typing and clears appear as `textInput` with stable ids.

### Design-system search fields (common trap)

Some DS widgets (e.g. TransTRACK `AppSearchField`) declare `controller` but **ignore it** and keep an internal `SearchController`. Replay then fills a dead controller; UI and filters never update.

**Fix:** host wrapper (`BsAppSearchField`) with a real `TextEditingController` + `TextFormField` + `RecorderInput`. On replay `onChanged`, also call the same submit/filter path the user triggers (search-on-submit screens).

Do **not** wrap the broken DS search alone and call it done.

---

## 6. Navigation replay — rich args and duplicates

Recorded navigation JSON often has **ids only**. Screens that need live domain objects will crash or show validation errors if you push with nulls.

| Pattern | Host fix |
|---------|----------|
| Route needs `workOrder` / entity | Before push, **fetch** by recorded id (or build a minimal valid model). Pass into page constructor. |
| Tap already opened the route (Start/Continue → review) | Observer still records a later `navigation`. **Skip push** if that route+id is already on the stack (`tryReplayAction` / early return in `replayNavigation`). |
| Detail push + list coordinate tap | Package dedupes; still prefer `RecorderTap` on rows. |
| AppBar Back + `back` action | Package dedupes; host may handle Back tap via `tryReplayAction` + `pop`. |
| Routes with unreplayable args (e.g. notification payloads) | Return/skip rather than throw; taps may still run. |
| Navbar tabs | `navigate` / nested stack, not a root `push` that duplicates shells. |

Literal **1:1** mode (recommended): reset `isFirstLaunch` / onboarding / tokens to match the clip in `prepareForReplay`, bootstrap to the first recorded route, **do not** strip onboarding/login from the buffer, restore developer session after.

See [REPLAY_AND_SHADOWPLAY.md](REPLAY_AND_SHADOWPLAY.md).

---

## 7. UX agents must know

| Topic | Behavior (v1.5.2+) |
|-------|---------------------|
| Stop replay | Tap top-right **`REPLAY`** badge on `RecordingOverlay` — not a left “Replay \| Stop” chip (removed). |
| During replay | Large QA chrome uses hit-test passthrough so coordinate taps hit the app; only the small badge remains tappable chrome. |
| Instant Replay | ~90s rolling buffer; Save clip runs package trim/dedupe into the library. |
| Exports | `bug-session.zip` can contain **credentials and PII** — treat as secrets. |

---

## 8. Notion / Jam (Ready to Test)

1. Wire `readyToTestStore` + defaults; QA enters token in-app.
2. Implement **`jamDevCredentialsStore`** (secure storage for Jam PAT + team id) and pass it on config — otherwise Jam fields never appear.
3. Optional `uploadIssueZipBytes` if Notion should get a hosted zip URL.
4. Details: [NOTION_READY_TO_TEST.md](NOTION_READY_TO_TEST.md).

---

## 9. Acceptance checklist (before “done”)

- [ ] Staging/dev build only; production main untouched
- [ ] Same navigator key as router; observer attached
- [ ] Dio attached; FAB opens panel / library / Ready to Test
- [ ] Registry generated; primary CTAs use `RecorderTap` / `BsAppButton`
- [ ] Login + search + critical forms use `RecorderInput` + shared controller
- [ ] DS search that ignores `controller` replaced with host search + real controller
- [ ] `replayNavigation` maps all common routes; rich args fetched or minimized safely
- [ ] Duplicate review/completion (or equivalent) pushes skipped when already open
- [ ] `tryReplayAction` covers login and stubborn Back affordances
- [ ] Literal replay: prepare/restore session; bootstrap without stripping auth funnel when testing login
- [ ] `jamDevCredentialsStore` set if Jam upload is required
- [ ] Manual smoke: Instant Replay → type + clear search → navigate → Save clip → Replay → stop via **REPLAY** badge; “What happened?” shows `textInput` including clears

---

## 10. Suggested host file layout

```text
lib/bug_session/
  bug_session_gate.dart          # flavor enabled?
  bug_session_kit.dart           # BugSessionConfig + initialize / wrap / Dio
  bug_session_navigation.dart    # observer, replayNavigation, tryReplayAction
  bug_session_route_replay.dart  # name → PageRouteInfo (+ fetch entities)
  bug_session_input_wrap.dart    # RecorderInput helper
  bug_session_replay_state.dart  # literal 1:1 prefs/auth snapshot
  jam_dev_credentials_storage.dart
  notion_*                       # Ready to Test
lib/widgets/
  bs_app_button.dart             # AppButton + RecorderTap
  bs_app_search_field.dart       # real controller + RecorderInput
lib/generated/
  bug_session_recorder_registry.g.dart
docs/BUG_SESSION.md              # app-specific notes + link to this guide
```

---

## 11. Common failure → cause

| Symptom | Likely miss |
|---------|-------------|
| Sheets / Ready to Test crash or blank | Detached `navigatorKey` (auto_route) |
| Replay taps wrong / stops early | Tap hit QA chrome; or stop expected on old left chip — use **REPLAY** badge |
| Typing not in timeline / not replayed | Missing `RecorderInput` or wrong controller instance |
| Deletes not recorded | Old package (&lt;1.5.3) or filtering empty text |
| Search records but UI/filter unchanged | DS search ignores external controller |
| “Order type required” / null entity on review | Pushed route with null `workOrder`; need fetch or skip duplicate push |
| Jam fields missing on Notion sheet | `jamDevCredentialsStore == null` |
| Double detail / stuck back | Missing dedupe awareness or `tryReplayAction` for Back |

When in doubt, compare against the reference host’s `lib/bug_session/` and re-read [REPLAY_AND_SHADOWPLAY.md](REPLAY_AND_SHADOWPLAY.md).
