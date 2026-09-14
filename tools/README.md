# BugSession recorder registry codegen

Generates `lib/generated/bug_session_recorder_registry.g.dart` (tap target ids + route/label lookup) for host apps. Optionally wraps `AppButton.` → `BsAppButton.` (host must provide `BsAppButton`).

From a Flutter **app** root (with this package checked out or on `PATH`):

```bash
../qa_bug_session/tools/generate_bug_session_recorder_registry.sh
../qa_bug_session/tools/generate_bug_session_recorder_registry.sh --apply-bs-app-button
```

Or with an explicit path:

```bash
dart path/to/qa_bug_session/tools/generate_recorder_registry.dart \
  --project-dir . \
  --output lib/generated/bug_session_recorder_registry.g.dart
```

Wire in `BugSessionConfig`:

- `resolveRecorderTargetId: resolveBugSessionRecorderTargetId`
- `tryReplayAction` / `resolveReplayTapPosition` as needed for custom navigation

Re-run after adding or renaming tappable widgets that should replay by registry id.
