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

## Scope

- **Read:** data-source query (filtered), page properties, block tree.
- **Write:** `to_do.checked` only via `submitTodoChanges` / `sync-todos`; optional status via `NotionTaskStatusService` / default `nts` mode.
- Acceptance criteria must be native Notion **to-do** blocks (not manual `[ ]` text in paragraphs).
