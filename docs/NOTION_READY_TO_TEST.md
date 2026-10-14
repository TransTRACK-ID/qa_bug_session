# Ready to Test (Notion)

QA-facing Notion queue: list cards with the same filters as your Notion view, open read-only detail, and sync **to-do** checkboxes back to Notion on submit.

## Dart (`qa_bug_session`)

Import from the package:

```dart
import 'package:qa_bug_session/notion/notion.dart';

final client = NotionClient(
  NotionApiConfig(
    token: notionToken,
    dataSourceId: dataSourceId,
  ),
);
final readyToTest = ReadyToTestService(client);

final tasks = await readyToTest.listTasks(
  ReadyToTestConfig(
    qaUserId: qaNotionUserId,
    productDomain: 'Product A', // optional
    statusEquals: 'Ready to Test',
  ),
);

final detail = await readyToTest.loadTaskDetail(tasks.first.pageId);
await readyToTest.submitTodoChanges({
  detail.todos.first.blockId: true,
});
```

Status-only updates (legacy `nts` behaviour):

```dart
await NotionTaskStatusService(client).updateStatus(
  pageId: pageId,
  newStatus: 'Completed',
);
```

## CLI (`tools/nts`)

Copy or symlink `tools/nts` onto your PATH. Same environment as before:

- `NOTION_TOKEN`
- `NOTION_DATA_SOURCE_ID`
- `NOTION_VERSION` (default `2025-09-03`)

Ready to Test:

| Command | Purpose |
|---------|---------|
| `nts list` | Filtered task list |
| `nts show --page <id>` | Page metadata + to-do blocks |
| `nts sync-todos --page <id> --file changes.json` | PATCH to-do checked state |

List filters (env or flags):

- `NOTION_QA_USER_ID` / `--qa-user-id` (required)
- `NOTION_PRODUCT_DOMAIN` / `--product` (optional)
- `NOTION_READY_STATUS` / `--status` (default: `Ready to Test`)
- `NOTION_PRODUCT_PROPERTY`, `NOTION_QA_PROPERTY` (defaults: `Product domain`, `QA`)

Add `--json` on `list` or `show` for machine-readable output.

`changes.json` shape:

```json
{
  "block-uuid-1": true,
  "block-uuid-2": false
}
```

## Zero-touch host setup

From `qa_bug_session/tools`:

```bash
dart run setup_bug_session.dart --project-dir /path/to/app --force \
  --git-ref v1.3.0 \
  --notion-data-source-id '<NOTION_DATA_SOURCE_ID>' \
  --notion-qa-user-id '<QA_NOTION_USER_ID>' \
  --notion-product 'Product A'
```

Generates under `lib/bug_session/`:

- `notion_ready_to_test_defaults.dart` — non-secret ids
- `notion_ready_to_test_storage.dart` — `flutter_secure_storage` for token
- `notion_ready_to_test_host.dart` — `wrapReadyToTestTools` in `MaterialApp.builder`

Re-run setup with `--force` to refresh generated files.

## Scope

- **Read:** data-source query (filtered), page properties, block tree.
- **Write:** `to_do.checked` only via `submitTodoChanges` / `sync-todos`; optional status via `NotionTaskStatusService` / default `nts` mode.
- Acceptance criteria must be native Notion **to-do** blocks (not manual `[ ]` text in paragraphs).

## QA card testing mode (1.4+)

From **Ready to Test → task detail → Start testing this card**:

1. Sets status **On Testing**, switches BugSession to **Full Record**, collapses the FAB/sheets, and shows a draggable **Objective** checklist (unchecked items first).
2. **Complete testing** (pass): confirm dialog → Jam upload → **Archived** + comment `PASSED ✅` + Jam link; syncs checklist changes to Notion. If **Archived** is missing from the database, QA is prompted to enter the exact status name.
3. **Generate issue**: auto or manual bug fields → Jam video from session start → child bug card (Type/Status **Issues**, parent relation) or re-issue on existing child; parent → **On Feedback** on first issue; **Screenshoot** lists Jam + BugSession replay `.zip` (uploaded to Notion as a file block, or a public URL from `uploadIssueZipBytes`).
4. **Stop testing** after feedback: ends recording without changing pass status.

Configure **Jam PAT + team id** in the same Notion connection settings pane (`BugSessionConfig.jamDevCredentialsStore`). Optional `uploadIssueZipBytes` host callback returns a public URL for the zip comment.

### Paste JSON (connection settings)

On **Notion connection**, use **Paste JSON to fill all fields** to import a single object instead of typing each field. Example:

```json
{
  "notion_token": "ntn_…",
  "data_source_id": "c2046e5d-68c6-440d-83b3-4fdb2c1cefb6",
  "qa_user_id": "223d872b-594c-8189-b6f5-000289706377",
  "product_domain": "",
  "jam_personal_access_token": "jam_pat_…",
  "jam_team_id": "240214cc-9ec4-4aa6-a9a5-c2cd34b7e272"
}
```

Aliases such as `user_id`, `jam_pat`, `group_jam`, and nested `"notion"` / `"jam"` objects are also accepted. Then tap **Save & validate**.

Status chips on task detail: **On Testing**, **On Feedback**, **Hold Test**, **Archived** (unknown presets prompt for a custom status name).

During card testing, the recording badge and tap ripples can hide (`hideRecordingChromeDuringQaTest`, default true); use the objective panel or Android notification **Stop testing**.
