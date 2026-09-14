# qa_bug_session

Flutter package for **QA BugSession** workflows: record what QA did, export a versioned session file, and let developers **replay actions against the live backend** (not mocked network responses).

This package is **TransTRACK original code** for the BugSession product. It is **not** the pub.dev package [`flutter_user_recorder`](https://pub.dev/packages/flutter_user_recorder) and **not** a drop-in replacement for [`user_interaction_recorder`](https://pub.dev/packages/user_interaction_recorder). The design was **influenced by** those interaction-recorder packages and by [`requests_inspector`](https://pub.dev/packages/requests_inspector) for network-observation ideas; see [ATTRIBUTION.md](ATTRIBUTION.md).

## Legal / attribution

- This repository’s Dart implementation is **Copyright © 2026 TransTRACK ID**, licensed under **MIT** ([LICENSE](LICENSE)).
- Upstream interaction-recorder and inspector packages remain separate projects with their own licenses; we do **not** claim their names or trademarks.
- Package name and repository are **distinct** from pub.dev homonyms to avoid confusion.

## Quick start

```yaml
dependencies:
  qa_bug_session:
    git:
      url: https://github.com/TransTRACK-ID/qa_bug_session.git
      ref: v1.0.0
```

```dart
import 'package:qa_bug_session/qa_bug_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final kit = await BugSessionKit.initialize(
    config: BugSessionConfig(
      enabled: kDebugMode, // or internal QA flavor guard
      environmentLabel: 'staging',
      credentialInjector: MyCredentialInjector(),
      environmentBuilder: () => buildBugSessionEnvironment(),
      filePicker: MyZipFilePicker(), // optional; needed for Import in panel
    ),
  );

  runApp(
    kit.wrap(
      app: MaterialApp(
        builder: kit.wrapMaterialAppBuilder(),
        home: const App(),
      ),
    ),
  );
}
```

Register taps with `RecorderTap` (recorder is picked up from `BugSessionScope` when omitted). Attach Dio with `kit.attachDio(dio)`.

Debug / internal QA builds only. See [ARCHITECTURE.md](ARCHITECTURE.md).

### Recorder registry codegen (host app)

For registry-based replay, generate lookup from your app’s tappable widgets:

```bash
dart run path/to/qa_bug_session/tools/generate_recorder_registry.dart \
  --project-dir . \
  --output lib/generated/bug_session_recorder_registry.g.dart
```

Details: [tools/README.md](tools/README.md).

### New project bootstrap

```bash
dart run path/to/qa_bug_session/tools/setup_bug_session.dart --project-dir /path/to/app --with-registry
```

Generates host wiring under `lib/bug_session/` and updates `pubspec.yaml`; see generated `INTEGRATION.md`.

## Add to a new project in 5 minutes

1. Add the git dependency and run `flutter pub get`.
2. Implement `CredentialInjector` against your token storage.
3. Provide `environmentBuilder` with package id, app version, and QA user/credential at export time.
4. Wrap `MaterialApp` with `kit.wrap` and `kit.wrapMaterialAppBuilder()`.
5. Gate `enabled: false` in production/store builds.

## Security

Exported `bug-session.zip` files can contain **live credentials and PII**. They are not redacted by design. Handle them like secrets.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
