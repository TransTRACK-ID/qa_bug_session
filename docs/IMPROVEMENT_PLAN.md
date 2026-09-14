# qa_bug_session — Product & implementation plan (v0.2+)

**Status:** Draft for package development (TransTRACK-owned)  
**Audience:** Maintainers of [`qa_bug_session`](https://github.com/TransTRACK-ID/qa_bug_session) and host apps (Regist Mobile Technician and future Flutter projects)  
**Canonical home:** Copy or move this document into the package repo as `docs/IMPROVEMENT_PLAN.md` when work starts there.

---

## 1. Goals

1. **Multi-project reuse** — Any TransTRACK Flutter app adds a git/path dependency, wraps the app once, and gets the full QA BugSession experience with minimal host code (auth, Dio, flavor gating).
2. **Package-owned UI** — Recording controls, session library list, import/export flows, replay/delete actions, and recording indicator live **inside `qa_bug_session`**, not duplicated per host.
3. **Clear recording lifecycle** — **Stop**, **Export**, **Replay**, and **Delete** are separate user actions. QA can stop and replay the in-memory session without exporting; export is optional for handoff.
4. **Session library** — Persisted catalog of sessions (recorded, exported on device, imported from zip). Import adds an entry to the list; each entry supports **Replay** and **Delete**.
5. **Visual quality** — Floating control surface with a **glassmorphism-inspired** look (blur, translucency, soft borders), comparable in *feel* to packages like [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder), implemented as **original TransTRACK UI code**.

---

## 2. Non-goals (v0.2 scope)

- Replacing host navigation stacks or auto-wiring every router (host hooks remain documented).
- Mocking API responses during replay (live-backend replay stays the guarantee).
- Shipping enabled in production/store release builds (debug / internal QA flavors only).
- Copying or vendoring source from `user_interaction_recorder`, `flutter_user_recorder`, or `requests_inspector`.

---

## 3. Ethical design note (glassmorphism & UX)

[`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder) advertises a “Beautiful glassmorphism design” and a **floating FAB / control panel** with **session list**, **persistence**, and **export/import**. That package is **inspiration for product UX**, not a code donor.

**We will:**

- Implement all widgets **from scratch** in `qa_bug_session` (MIT, TransTRACK copyright).
- Take **category-level** inspiration only: draggable FAB, expandable panel, bottom sheet library, frosted glass panels, responsive layout on small phones.
- Use **standard Flutter APIs** (`BackdropFilter`, `ClipRRect`, semi-transparent `ColorScheme` surfaces, subtle borders/shadows) — these are generic platform patterns, not proprietary to any single package.
- **Document influence** in package `ATTRIBUTION.md` (already started) and in UI module README.
- **Not** copy layout metrics, asset files, color hex values, class names, or widget trees from third-party repos or pub package sources.

**We will not:**

- Add a dependency on `user_interaction_recorder` solely to reuse its UI.
- Claim “glassmorphism” as a trademark of another package; describe ours as “glass-inspired” or “frosted overlay” in docs.

---

## 4. Target host integration (any project)

After v0.2, a host app should need **only**:

```dart
// main_staging.dart (or main_dev.dart)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // … existing init (Firebase, GetIt, flavors) …

  final bugSession = BugSessionKit.initialize(
    config: BugSessionConfig(
      environmentLabel: 'staging', // flavor name
      enabled: true, // or kDebugMode && isInternalBuild
      credentialInjector: MyAppCredentialInjector(), // host implements
    ),
  );

  runApp(
    BugSessionKit.wrap(
      app: const RequestsInspector(child: App()),
      kit: bugSession,
    ),
  );
}
```

Optional one-liners elsewhere:

- Register `BugSessionDioInterceptor` on `Dio` (helper provided: `bugSession.attachDio(dio)`).
- Wrap tap targets: `RecorderTap` / `BugSessionTap` (unchanged API).

**Host must still provide:**

- `CredentialInjector` (secure storage / token shape).
- `BugSessionEnvironment` fields that come from the app (`package_info`, user id) — kit can default-build via `BugSessionEnvironmentBuilder` callback.
- Flavor guard so `enabled: false` in production.

Everything else (FAB, list, import picker, export path, delete, replay confirm) is **inside the package**.

---

## 5. Architecture overview

```text
┌─────────────────────────────────────────────────────────────┐
│ BugSessionKit.wrap(app)                                      │
│  ├─ BugSessionScope (recorder, catalog, replayer, config)   │
│  ├─ child: host App (MaterialApp, etc.)                      │
│  └─ BugSessionOverlayStack (package UI, always on top)       │
│       ├─ RecordingIndicator (glass chip, optional)           │
│       ├─ BugSessionControlPanel (draggable FAB + sheet)      │
│       └─ Modals: LibrarySheet, SessionDetail, ConfirmReplay    │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
 BugSessionRecorder              BugSessionCatalog
 (record / stop)                 (persist index + zip files)
         │                              │
         └──────────┬───────────────────┘
                    ▼
         BugSessionSerializer + BugSessionReplayer
```

**Layering rule:** Package UI is inserted via `MaterialApp.builder` **inside** the host’s `MaterialApp` (or kit provides a `BugSessionMaterialAppBuilder` helper) so `Directionality`, `MediaQuery`, and `Overlay` behave correctly.

---

## 6. Recording lifecycle (explicit API)

| Step | User action | Package API | Result |
|------|-------------|-------------|--------|
| 1 | Record | `recorder.start()` | State: recording |
| 2 | **Stop** | `recorder.stop(environment)` | `BugSession` in memory; `lastSession` set; **catalog.addInMemory(session)** |
| 3 | **Replay (last)** | `replayer.replay(session: lastSession)` | Live replay; no file required |
| 4 | **Export** (optional) | `catalog.exportToZip(sessionId)` or `exportWriter.write(session)` | Zip on disk; catalog entry gets `filePath` |
| 5 | **Import** | `catalog.importFromPicker()` / `importFromPath` | Parse zip → new catalog entry → **list refreshes** |
| 6 | **Replay (from list)** | Load session by id → confirm → replay | Same replayer |
| 7 | **Delete** | `catalog.delete(id)` | Remove index row + delete zip if present |

**Breaking UX change from v0.1 demo:** Remove combined “Stop & export” as the only path. The package UI shows separate **Stop** and **Export** buttons.

---

## 7. Package modules (new / extended)

Suggested layout inside `qa_bug_session` (no new pub package; folders only):

| Path | Responsibility |
|------|----------------|
| `lib/bug_session/kit/bug_session_kit.dart` | `initialize`, `wrap`, `attachDio`, flavor helpers |
| `lib/bug_session/library/bug_session_catalog.dart` | Index + CRUD + disk layout |
| `lib/bug_session/library/bug_session_catalog_entry.dart` | List row model (metadata only in index) |
| `lib/bug_session/library/bug_session_store.dart` | `documents/bug-sessions/`, `index.json` |
| `lib/bug_session/export/bug_session_export_writer.dart` | Zip write + naming convention |
| `lib/bug_session/import/bug_session_import_reader.dart` | Zip read + validation |
| `lib/bug_session/ui/glass/` | Shared glass panel, button, list tile styles |
| `lib/bug_session/ui/bug_session_overlay.dart` | Top-level overlay stack |
| `lib/bug_session/ui/bug_session_control_panel.dart` | Draggable FAB + collapsed/expanded panel |
| `lib/bug_session/ui/bug_session_library_sheet.dart` | “Available reports” list |
| `lib/bug_session/ui/bug_session_session_actions.dart` | Replay / Delete / Export sheet for one entry |
| `lib/bug_session/ui/recording_overlay.dart` | Extend or replace with glass indicator |

Export from `qa_bug_session.dart` so hosts import one library.

---

## 8. Session catalog (multi-project contract)

### 8.1 Storage layout (default store)

```text
{applicationDocumentsDirectory}/bug-sessions/
  index.json                 # metadata list, no raw tokens in index
  sessions/
    {sessionId}.zip          # full BugSession v1 export (contains credentials)
```

Host may override root via `BugSessionConfig.storageDirectory`.

### 8.2 `BugSessionCatalogEntry` (index row)

- `sessionId` (from manifest)
- `displayName` — optional QA label; default generated from `startedAt` + action count
- `source` — `recorded` | `exported` | `imported`
- `filePath` — nullable until exported/imported
- `startedAt`, `stoppedAt`, `actionCount`, `appVersion`, `buildNumber`, `environment`, `userDisplayHint`
- **Never** store `accessToken` in `index.json`

### 8.3 Catalog API

```dart
abstract interface class BugSessionCatalog {
  Stream<List<BugSessionCatalogEntry>> watchEntries();
  Future<List<BugSessionCatalogEntry>> listEntries();

  Future<BugSessionCatalogEntry> addFromStoppedSession(BugSession session);
  Future<BugSessionCatalogEntry> importFromZipBytes(Uint8List bytes, {String? suggestedName});
  Future<BugSessionCatalogEntry> exportSessionToDisk(String sessionId);

  Future<BugSession> loadSession(String sessionId);
  Future<void> delete(String sessionId);
  Future<void> clearAll(); // QA settings; confirm in UI
}
```

**Import success** → `addFromStoppedSession` / `importFromZipBytes` → `watchEntries` emits → library UI updates.

---

## 9. Package UI specification

### 9.1 `BugSessionControlPanel` (replaces host-specific shells)

- **Draggable** floating panel (pointer-driven, clamped to safe area) — behavior parity with common FAB tools, implemented in-package.
- **Collapsed:** glass pill — icon, “BugSession”, recording dot when active.
- **Expanded sections:**
  - **Transport:** Record | **Stop** | **Export** (enabled when `lastSession` or selected catalog id has session)
  - **Library:** “Saved sessions (N)” → opens `BugSessionLibrarySheet`
  - **Import:** file picker (`.zip`) → catalog import
  - Status line (last operation / replay result summary)
- **Button styling (product rule):**
  - Filled / tonal actions (Export, Record): dark text on light frosted button.
  - Disabled / ghost actions: white text on transparent glass.

### 9.2 `BugSessionLibrarySheet` (“available report lists”)

- Modal bottom sheet (glass background, scrollable list).
- Each row: name, date/time, action count, version badge, source chip (recorded/imported).
- Tap row → **Session actions** bottom sheet:
  - **Replay** (destructive confirm + lock/version warnings)
  - **Export** (if not yet on disk)
  - **Delete** (confirm; copy warns about credentials in zip)
- Empty state: hint to Record or Import.

### 9.3 Recording indicator

- Keep lightweight red “Recording” chip (top-trailing), glass variant optional.
- Must not require host `Stack`.

### 9.4 Theming

- `BugSessionThemeData` — blur sigma, base tint, accent, corner radius, text styles.
- Defaults match TransTRACK-friendly neutrals; hosts override optionally.
- **No hard dependency** on `transtrack_design_system` (keeps package usable in non-Regist apps).

### 9.5 Accessibility & responsiveness

- Minimum tap targets 48dp; sheet max height 85% screen; tablet: side panel variant (optional v0.2.1).

---

## 10. `BugSessionKit` API sketch

```dart
class BugSessionConfig {
  final bool enabled;
  final String environmentLabel;
  final CredentialInjector credentialInjector;
  final BugSessionEnvironment Function()? environmentBuilder;
  final Directory? storageDirectory;
  final BugSessionThemeData? theme;
}

class BugSessionKit {
  static BugSessionKit initialize({required BugSessionConfig config});

  Widget wrap({required Widget app});

  void attachDio(Dio dio);

  BugSessionRecorder get recorder;
  BugSessionCatalog get catalog;
  BugSessionReplayer get replayer;
}
```

`wrap` responsibilities:

1. Register recorder/catalog in an internal scope (or expose `InheritedWidget` / interface for `RecorderTap`).
2. Install `MaterialApp.builder` hook **once** via documented pattern:
   - **Option A (recommended):** Host calls `BugSessionKit.wrapMaterialAppBuilder(existingBuilder)`.
   - **Option B:** Kit documents that host must merge builder; provide assert in debug if overlay missing.

For **multi-project** simplicity, prefer **Option A** helper that chains builders.

---

## 11. Security & compliance (unchanged principles, UI-aware)

- Exported/imported zips contain **live credentials** — show persistent warning in library sheet footer.
- Replay always shows confirmation; catalog delete does not leave orphan zips.
- `SessionLockValidator` warnings surface in session actions UI (version / user mismatch).
- `enabled: false` → `wrap` returns child unchanged (zero overlay, no catalog IO).

---

## 12. Migration from v0.1

| v0.1 (today) | v0.2 |
|--------------|------|
| Host `BugSessionStagingShell` | Delete; use `BugSessionKit.wrap` |
| Combined Stop & export | Split in package UI |
| Single `_importedSession` in host | `BugSessionCatalog` |
| Host Dio interceptor copy | `kit.attachDio(dio)` optional helper in package |
| `RecordingOverlay` only | Part of `BugSessionOverlayStack` |

**Regist Mobile Technician** follow-up task (separate PR): remove `lib/widgets/bug_session_staging_shell.dart`, shrink `main_staging.dart` to kit init + `CredentialInjector` only.

---

## 13. Implementation phases

### Phase 1 — Core library (no new UI)

- [ ] `BugSessionCatalog` + file store + tests
- [ ] Export/import helpers wrapping existing serializer
- [ ] `recorder.stop()` docs; `discardLastSession()` naming clarity
- [ ] Unit tests: import → list → delete → list empty

**Exit:** Host can use catalog via API without UI.

### Phase 2 — Kit & overlay wiring

- [ ] `BugSessionKit`, scope, `wrap`, `attachDio`
- [ ] `MaterialApp.builder` helper (Directionality-safe)
- [ ] Feature flag `enabled`

**Exit:** Empty overlay mounts in example app.

### Phase 3 — Glass UI components

- [ ] `BugSessionThemeData`, glass panel/button/tile widgets (original code)
- [ ] Draggable control panel
- [ ] Split Stop / Export / Record / Import
- [ ] Update `ATTRIBUTION.md` (UX inspiration paragraph)

**Exit:** Example app fully usable without custom host UI.

### Phase 4 — Session library UI

- [ ] `BugSessionLibrarySheet` + session actions (replay/delete/export)
- [ ] Wire catalog `watchEntries` to list
- [ ] Import success auto-opens library or shows snackbar (configurable)

**Exit:** QA workflow complete in example app.

### Phase 5 — Host rollouts

- [ ] Regist Mobile Technician staging integration (minimal)
- [ ] Template section in package README (“Add to a new project in 5 minutes”)
- [ ] CHANGELOG v0.2.0

### Phase 6 — Nice-to-have (v0.2.x)

- [ ] Replay comparison summary sheet (`SessionComparator` UI)
- [ ] Session rename in library
- [ ] Share sheet integration hook (host provides `ShareParams` callback)
- [ ] Optional `InteractionRecorder` adapter for pub interaction recorders (API only)

---

## 14. Testing strategy

- **Unit:** catalog CRUD, index corruption recovery, zip round-trip.
- **Widget:** library sheet empty/filled, button enablement (Stop without Export).
- **Integration (example app):** record → stop → replay without export → export → delete.
- **Golden (optional):** glass panel light/dark; avoid copying third-party goldens.

---

## 15. Documentation deliverables (package repo)

- [ ] README — Quick start with `BugSessionKit.wrap`
- [ ] `docs/IMPROVEMENT_PLAN.md` — this document
- [ ] `docs/UI_DESIGN.md` — glass tokens, ethical inspiration note, screenshots from **our** example app only
- [ ] `ARCHITECTURE.md` — update milestone table (library UI = done in-package)
- [ ] `ATTRIBUTION.md` — extend § Design influence with FAB/session-list UX

---

## 16. Success criteria

1. A **new Flutter project** can add the dependency and `BugSessionKit.wrap` and get FAB + library + import/delete/replay with **no copied UI code** in the host.
2. QA can **Stop** and **Replay** without exporting.
3. **Import** adds a visible row in **Saved sessions**; **Delete** and **Replay** work from that row.
4. UI feels modern (frosted glass, draggable panel) while remaining **legally and ethically original** TransTRACK code.
5. All analyzer/tests pass in package CI; host apps only gate by flavor + injector.

---

## 17. Open decisions (resolve before Phase 2)

| Topic | Options | Recommendation |
|-------|---------|----------------|
| State management in UI | Vanilla `StatefulWidget` + `Listenable` catalog vs Cubit | Start with **Catalog `Stream`** + local state; add Cubit only if sheets grow |
| `MaterialApp.builder` chaining | Document merge vs kit helper | **Kit helper** for multi-project consistency |
| Default storage | App documents vs support dir | **App documents** + documented backup warning |
| iOS/Android file picker | `file_picker` dependency | Add as **optional** dependency or interface `BugSessionFilePicker` host injects |

---

*Document version: 1.0 — aligns with qa_bug_session v0.1.0 API and TransTRACK multi-app rollout.*
