# BugSession host tools

## Zero-touch project setup

From your **Flutter app root**:

```bash
../qa_bug_session/tools/setup_bug_session.sh --force
```

Or:

```bash
cd path/to/qa_bug_session/tools && dart pub get && dart run setup_bug_session.dart --project-dir /path/to/app
```

The script:

- Resolves **main**: `main_development.dart` → `main_staging.dart` → `main.dart` (patches only that file)
- Generates **`lib/bug_session/`** (kit, auth, navigation, share, …)
- **Scans** GoRouter / auto_route; on failure, re-run with `--router-dir lib/helpers`
- Patches **`lib/app/app.dart`** (or scanned `App` / `MaterialApp.router`)
- Patches **router file** (navigator key + observer) and **MainRepository** Dio hookup
- Always runs **registry codegen**; **AppButton → BsAppButton** only if `transtrack_design_system` is in pubspec
- Wires **package video capture** (`BugSessionDefaultVideoCapture`)
- Runs **`flutter pub get`** and **`flutter analyze`**

Gate: **`dev`**, **`development`**, **`staging`** flavors only.

Requires **`qa_bug_session` v1.1.0+** (git ref in pubspec).

---

## Recorder registry codegen (standalone)

```bash
dart run generate_recorder_registry.dart --project-dir /path/to/app
```

See generated `lib/generated/bug_session_recorder_registry.g.dart`.
