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

Requires **`qa_bug_session` v1.3.0+** (git ref in pubspec).

### Ready to Test (Notion)

Setup always wires the **Ready to Test** FAB (dev/staging). Pass Notion ids once:

```bash
dart run setup_bug_session.dart --project-dir /path/to/app \
  --notion-data-source-id 'c2046e5d-...' \
  --notion-qa-user-id '223d872b-...' \
  --notion-product 'Product A'
```

QA still enters the integration **token** in-app (secure storage). See [docs/NOTION_READY_TO_TEST.md](../docs/NOTION_READY_TO_TEST.md).

---

## Recorder registry codegen (standalone)

```bash
dart run generate_recorder_registry.dart --project-dir /path/to/app
```

See generated `lib/generated/bug_session_recorder_registry.g.dart`.

---

## Notion — Ready to Test (`tools/nts`)

Bash CLI shipped with this repo (also usable from PATH). Requires bash 4+, `curl`, and `jq`.

```bash
export NOTION_TOKEN='ntn_...'
export NOTION_DATA_SOURCE_ID='...'
export NOTION_QA_USER_ID='...'   # QA people-property user id

./tools/nts list --product "Product A" --json
./tools/nts show --page <page-id> --json
./tools/nts sync-todos --page <page-id> --file todo-changes.json -y
```

Dart API: see [docs/NOTION_READY_TO_TEST.md](../docs/NOTION_READY_TO_TEST.md).
