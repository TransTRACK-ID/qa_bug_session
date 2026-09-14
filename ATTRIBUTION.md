# Attribution

## What this project is

**`qa_bug_session`** is an **original implementation** by TransTRACK ID for internal QA → developer bug reproduction (BugSession export, import lock, live-backend replay).

It is **not** a fork of, and **does not contain vendored source code from**:

- [`flutter_user_recorder`](https://pub.dev/packages/flutter_user_recorder) on pub.dev  
- [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder) on pub.dev  

Those packages address **generic user-interaction record/replay**. This package adds TransTRACK-specific **BugSession** format, **credential reuse**, **import binding** (app package + version + user), and **QA-vs-replay network comparison** without substituting recorded API responses during normal replay.

## Design influence (ethical disclosure)

Our implementation plan and API shape were **heavily inspired by** (concepts and feature lists, not copied code):

| Project | Role in our design | Relationship to this repo |
|--------|---------------------|---------------------------|
| [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder) / [`flutter_user_recorder`](https://pub.dev/packages/flutter_user_recorder) | Interaction record/replay, semantic targets, session export, **FAB + session list UX** | **Inspiration only**; v0.2 package UI is original frosted overlay code; optional future adapter behind `InteractionRecorder` |
| [`requests_inspector`](https://pub.dev/packages/requests_inspector) | Dio/network logging, export for debugging | **Inspiration only**; optional `NetworkRecorder` backend via interceptors |

If we later **depend on** either package, their licenses apply to **their** code only; this repo’s MIT license applies to **our** code.

## Naming

This package is published as **`qa_bug_session`** so TransTRACK’s Git dependency does not collide with existing pub.dev packages such as [`flutter_user_recorder`](https://pub.dev/packages/flutter_user_recorder) or [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder).

## Runtime dependencies (pub)

Fetched via pub, not vendored — see each package on pub.dev for license terms:

- [`archive`](https://pub.dev/packages/archive)
- [`crypto`](https://pub.dev/packages/crypto)
- [`meta`](https://pub.dev/packages/meta)
- [`dio`](https://pub.dev/packages/dio)
- [`path_provider`](https://pub.dev/packages/path_provider)
- Flutter SDK ([BSD-3-Clause](https://github.com/flutter/flutter/blob/master/LICENSE))

## Copyright

**Copyright © 2026 TransTRACK ID** — [MIT License](LICENSE).
