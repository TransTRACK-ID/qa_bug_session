# BugSession package UI (v0.2)

## Visual language

- **Frosted overlays** — `BackdropFilter` blur, semi-transparent dark tint, soft white borders (`BugSessionThemeData`).
- **Draggable FAB** — collapsed glass pill; expanded panel with transport + library actions.
- **Bottom sheets** — saved session list and per-session replay/export/delete.

Tokens live in `lib/bug_session/kit/bug_session_theme.dart`. Hosts may override blur, tint, accent, and corner radius without pulling in TransTRACK design system packages.

## Ethical inspiration

Floating recorder tools on pub.dev (for example packages that advertise glassmorphism FABs and session libraries) informed **product UX categories** only: draggable control surface, session list, import/export. All widgets in `lib/bug_session/ui/` are **original TransTRACK code** — no copied layout metrics, assets, or widget trees. See [ATTRIBUTION.md](../ATTRIBUTION.md).

## Screenshots

Add captures from **this repository’s example app** only when publishing release notes.
