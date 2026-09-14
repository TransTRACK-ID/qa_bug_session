import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kDebugMode) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('BugSession tools are disabled in release builds.'),
          ),
        ),
      ),
    );
    return;
  }

  final kit = await BugSessionKit.initialize(
    config: BugSessionConfig(
      enabled: true,
      environmentLabel: 'development',
      credentialInjector: _DemoCredentialInjector(expectedUserId: 'demo-user-1'),
      environmentBuilder: _demoEnvironment,
    ),
  );

  runApp(
    kit.wrap(
      app: MaterialApp(
        builder: kit.wrapMaterialAppBuilder(),
        home: const _DemoHome(),
      ),
    ),
  );
}

BugSessionEnvironment _demoEnvironment() {
  return BugSessionEnvironment(
    packageId: 'com.transtrack.bug_session_demo',
    appVersion: '0.2.0',
    buildNumber: '1',
    platform: defaultTargetPlatform.name,
    osVersion: 'demo',
    environment: 'development',
    user: const BugSessionUser(userId: 'demo-user-1', displayHint: 'qa@demo'),
    credential: const BugSessionCredential(
      type: 'bearer',
      accessToken: 'demo-token',
    ),
  );
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BugSession demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Use the draggable BugSession panel to record, stop, replay, '
              'export, import, and manage saved sessions.',
            ),
            const SizedBox(height: 16),
            RecorderTap(
              id: 'demo.increment',
              onPressed: () => setState(() => _counter++),
              child: ElevatedButton(
                onPressed: null,
                child: Text('Count: $_counter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoCredentialInjector implements CredentialInjector {
  _DemoCredentialInjector({required this.expectedUserId});

  final String expectedUserId;

  @override
  Future<void> inject(BugSessionCredential credential) async {}

  @override
  Future<String> resolveUserId() async => expectedUserId;

  @override
  Future<bool> tryRefresh(BugSessionCredential credential) async => false;

  @override
  Future<void> restorePreviousSession() async {}
}
