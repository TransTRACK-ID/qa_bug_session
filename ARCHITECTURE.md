# Architecture

## Scope of this package

Standalone Flutter package for TransTRACK apps. Host apps integrate by:

1. Adding a path/git dependency on `qa_bug_session`
2. Initializing `BugSessionKit` with `CredentialInjector` and `environmentBuilder`
3. Wrapping the app with `kit.wrap` + `MaterialApp.builder` from `wrapMaterialAppBuilder`
4. Wrapping interactive widgets with `RecorderTap` (optional explicit `BugSessionRecorder`)
5. Calling `kit.attachDio(dio)` so network events reach the in-memory recorder

## Navigation / HTTP / auth (host responsibilities)

| Concern | Package support | Host app |
|--------|-----------------|----------|
| Navigation | Records `navigation` actions when host calls `semantic.recordNavigation` | NavigatorObserver / go_router hook |
| HTTP | `BugSessionDioInterceptor` → `NetworkRecorder` | `kit.attachDio(dio)` |
| Auth replay | `CredentialInjector` | Token manager + refresh + restore developer session |
| Import lock | `SessionLockValidator` | Pass running package/version from `package_info` + injected user id |
| Debug-only UI | `BugSessionOverlayStack` (FAB, library, indicator) | `BugSessionConfig.enabled` |

## Replay guarantee

```text
Recorded actions → Flutter UI → app logic → live API
```

Recorded network JSON remains **evidence** for comparison, never substituted for live responses during replay.

## Milestones

| Milestone | Status |
|-----------|--------|
| 1 Spike (tap export/import/replay) | Done |
| 2 Multiple action types | Tap + hooks for text/navigation |
| 3 Network observation | In-memory + Dio interceptor in package |
| 4 Unified export | `bug-session.zip` format v1 |
| 5 Live replay + compare | `BugSessionReplayer` + `SessionComparator` |
| 6 Comparison UI | Data layer; optional future sheet |
| 7 Security hardening | Lock + credential injection |
| 8 Session catalog + library UI (v0.2) | Done in-package |

## Storage layout

```text
{applicationDocumentsDirectory}/bug-sessions/
  index.json
  sessions/{sessionId}.zip
```

Override root with `BugSessionConfig.storageDirectory`.
