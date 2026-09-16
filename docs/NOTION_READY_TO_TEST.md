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
