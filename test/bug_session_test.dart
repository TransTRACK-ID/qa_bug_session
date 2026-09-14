import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

class _TestCredentialInjector implements CredentialInjector {
  BugSessionCredential? lastInjected;
  String resolved = 'user-qa-1';

  @override
  Future<void> inject(
    BugSessionCredential credential, {
    BugSessionUser? user,
  }) async {
    lastInjected = credential;
  }

  @override
  Future<String> resolveUserId() async => resolved;

  @override
  Future<bool> tryRefresh(BugSessionCredential credential) async => false;

  @override
  Future<void> restorePreviousSession() async {}
}

BugSessionEnvironment _env({String userId = 'user-qa-1'}) {
  return BugSessionEnvironment(
    packageId: 'com.transtrack.demo',
    appVersion: '0.1.0',
    buildNumber: '1',
    platform: 'test',
    osVersion: '1',
    environment: 'development',
    user: BugSessionUser(userId: userId, displayHint: 'qa@example.com'),
    credential: const BugSessionCredential(
      type: 'bearer',
      accessToken: 'token-abc',
    ),
  );
}

void main() {
  group('Session lock', () {
    test('checksum detects tampering', () {
      const sessionId = 'bug-session-001';
      final checksum = SessionLockValidator.computeLockChecksum(
        packageId: 'com.app',
        appVersion: '1.0.0',
        buildNumber: '1',
        userId: 'u1',
        sessionId: sessionId,
      );
      final lock = BugSessionLock(
        packageId: 'com.app',
        appVersion: '1.0.0',
        buildNumber: '1',
        userId: 'u1',
        lockChecksum: checksum,
      );
      expect(SessionLockValidator.verifyChecksum(lock, sessionId), isTrue);

      final tampered = BugSessionLock(
        packageId: 'com.app',
        appVersion: '1.0.0',
        buildNumber: '1',
        userId: 'u2',
        lockChecksum: checksum,
      );
      expect(SessionLockValidator.verifyChecksum(tampered, sessionId), isFalse);
    });

    test('validator aggregates failures', () {
      final checksum = SessionLockValidator.computeLockChecksum(
        packageId: 'com.app',
        appVersion: '1.0.0',
        buildNumber: '1',
        userId: 'u1',
        sessionId: 's1',
      );
      final result = SessionLockValidator().validate(
        lock: BugSessionLock(
          packageId: 'com.app',
          appVersion: '1.0.0',
          buildNumber: '1',
          userId: 'u1',
          lockChecksum: checksum,
        ),
        sessionId: 's1',
        runningPackageId: 'com.other',
        runningAppVersion: '2.0.0',
        runningBuildNumber: '9',
        resolvedUserId: 'u2',
      );
      expect(result.isValid, isFalse);
      expect(result.failures.length, greaterThan(1));
      expect(result.flashMessage(), contains('Cannot replay'));
    });
  });

  group('Export/import round trip', () {
    test('zip preserves tap action', () async {
      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'bug-session-test');
      recorder.semantic.recordTap('demo.tap');
      final session = await recorder.stop(_env());
      expect(
        session.actions,
        hasLength(1),
        reason: session.actions.map((a) => a.target).toList().toString(),
      );

      final bytes = BugSessionSerializer().toZipBytes(session);
      final imported = BugSessionSerializer().fromZipBytes(bytes);

      expect(imported.formatVersion, BugSession.supportedFormatVersion);
      expect(imported.actions, hasLength(1));
      expect(imported.actions.first.target, 'demo.tap');
      expect(imported.manifest.lock.lockChecksum, isNotEmpty);
    });

    test('zip uses utf8 sizes and stores mp4 uncompressed', () async {
      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'bug-session-zip-binary');
      recorder.semantic.recordTap('café.demo.tap');
      final session = await recorder.stop(_env());
      final fakeMp4 = Uint8List.fromList([
        0,
        0,
        0,
        24,
        0x66,
        0x74,
        0x79,
        0x70,
        0x69,
        0x73,
        0x6f,
        0x6d,
        0,
        0,
        0,
        0,
        0x69,
        0x73,
        0x6f,
        0x6d,
        0x6d,
        0x70,
        0x34,
        0x31,
      ]);
      final zipBytes = BugSessionSerializer().toZipBytes(
        session,
        binaryFiles: {'visual/session.mp4': fakeMp4},
      );
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final markdownFile = archive.findFile('what_happened.md');
      expect(markdownFile, isNotNull);
      final markdown = utf8.decode(markdownFile!.content as List<int>);
      expect(markdown, contains('café'));
      expect(markdownFile.size, utf8.encode(markdown).length);

      final mp4File = archive.findFile('visual/session.mp4');
      expect(mp4File, isNotNull);
      expect(mp4File!.size, fakeMp4.length);
      expect(mp4File.compression, CompressionType.none);
      expect(mp4File.content, fakeMp4);

      final imported = BugSessionSerializer().fromZipBytes(zipBytes);
      expect(imported.actions.first.target, 'café.demo.tap');
    });

    test('rejects unknown format version', () {
      expect(
        () => BugSessionArchiveParser().parseParts(
          manifestJson: '{"formatVersion":99,"sessionId":"x"}',
          actionsJson: '{"actions":[]}',
          networkJson: '{"events":[]}',
          diagnosticsJson: '{"diagnostics":[]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('Network correlation', () {
    test('matches by method and path', () {
      const corr = 'abc';
      final original = [
        NetworkEvent.response(
          const NetworkResponseEvent(
            timestampMs: 1,
            method: 'POST',
            url: 'https://api.example/orders/123/refund',
            statusCode: 500,
            correlationId: corr,
          ),
        ),
      ];
      final replay = [
        NetworkEvent.response(
          const NetworkResponseEvent(
            timestampMs: 50,
            method: 'POST',
            url: 'https://api.example/orders/123/refund',
            statusCode: 200,
            correlationId: corr,
          ),
        ),
      ];

      final comparison = SessionComparator().compare(
        originalNetwork: original,
        replayNetwork: replay,
      );
      expect(comparison.responseDifferences, 1);
      expect(comparison.summaryMessage, contains('Further investigation'));
    });
  });

  group('Session catalog', () {
    test('import → list → delete → list empty', () async {
      final root = await Directory.systemTemp.createTemp('bug_session_catalog');
      addTearDown(() => root.delete(recursive: true));

      final kit = BugSessionKit.initializeSync(
        config: BugSessionConfig(
          enabled: true,
          environmentLabel: 'test',
          credentialInjector: _TestCredentialInjector(),
          storageDirectory: root,
        ),
      );

      final recorder = kit.recorder;
      await recorder.start(sessionId: 'bug-session-catalog');
      recorder.semantic.recordTap('demo.tap');
      final session = await recorder.stop(_env());
      await kit.catalog.addFromStoppedSession(session);

      var entries = await kit.catalog.listEntries();
      expect(entries, hasLength(1));
      expect(entries.first.sessionId, 'bug-session-catalog');

      final replayLoaded = await kit.catalog.loadSession('bug-session-catalog');
      expect(replayLoaded.actions, hasLength(1));

      final exported = await kit.catalog.exportSessionToDisk('bug-session-catalog');
      expect(exported.filePath, isNotNull);

      final bytes = Uint8List.fromList(BugSessionSerializer().toZipBytes(session));
      await kit.catalog.importFromZipBytes(bytes, suggestedName: 'Imported QA');
      entries = await kit.catalog.listEntries();
      expect(entries.length, greaterThanOrEqualTo(1));

      await kit.catalog.delete('bug-session-catalog');
      entries = await kit.catalog.listEntries();
      expect(entries.where((e) => e.sessionId == 'bug-session-catalog'), isEmpty);
    });

    test('stop and replay without export uses in-memory cache', () async {
      final root = await Directory.systemTemp.createTemp('bug_session_memory');
      addTearDown(() => root.delete(recursive: true));

      final kit = BugSessionKit.initializeSync(
        config: BugSessionConfig(
          enabled: true,
          environmentLabel: 'test',
          credentialInjector: _TestCredentialInjector(),
          storageDirectory: root,
        ),
      );

      await kit.recorder.start(sessionId: 'mem-session');
      kit.recorder.semantic.recordTap('demo.replay');
      final session = await kit.recorder.stop(_env());
      await kit.catalog.addFromStoppedSession(session);

      final loaded = await kit.catalog.loadSession('mem-session');
      expect(loaded.actions.first.target, 'demo.replay');
    });
  });

  group('Replay pipeline', () {
    test('record tap → export → import → replay tap', () async {
      var tapped = false;
      RecorderTargetRegistry.instance.register('demo.replay', () async {
        tapped = true;
      });

      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'bug-session-replay');
      recorder.semantic.recordTap('demo.replay');
      final session = await recorder.stop(_env());

      final imported = BugSessionSerializer().fromZipBytes(
        BugSessionSerializer().toZipBytes(session),
      );

      final injector = _TestCredentialInjector();
      final replayer = BugSessionReplayer(
        credentialInjector: injector,
        interactionRecorder: SemanticInteractionRecorder(),
      );

      final result = await replayer.replay(
        session: imported,
        current: _env(),
      );

      expect(result.success, isTrue);
      expect(tapped, isTrue);
      expect(injector.lastInjected?.accessToken, 'token-abc');
    });

    test('stop requested mid-replay returns partial result', () async {
      var stop = false;
      RecorderTargetRegistry.instance.register('demo.stop.a', () async {});
      RecorderTargetRegistry.instance.register('demo.stop.b', () async {});

      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'bug-session-stop');
      recorder.semantic.recordTap('demo.stop.a');
      recorder.semantic.recordTap('demo.stop.b');
      final session = await recorder.stop(_env());

      final injector = _TestCredentialInjector();
      final replayer = BugSessionReplayer(
        credentialInjector: injector,
        interactionRecorder: SemanticInteractionRecorder(),
      );

      final result = await replayer.replay(
        session: session,
        current: _env(),
        shouldStop: () => stop,
      );

      expect(result.actionsSucceeded, 2);
      expect(result.success, isTrue);

      stop = true;
      final stopped = await replayer.replay(
        session: session,
        current: _env(),
        shouldStop: () => stop,
      );
      expect(stopped.cancelled, isTrue);
      expect(stopped.actionsSucceeded, 0);
    });
  });

  group('Replay auth detection', () {
    test('login navigation in session is detected', () async {
      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'auth-detect');
      recorder.semantic.recordNavigation('LoginRoute');
      final session = await recorder.stop(_env());
      expect(bugSessionSessionIncludesAuthentication(session), isTrue);
    });

    test('login tap on opening screen is detected', () async {
      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'auth-tap');
      recorder.semantic.recordNavigation(
        '{"name":"LoginRoute","label":"session_start"}',
      );
      recorder.semantic.recordTap('LoginRoute/Sign in');
      final session = await recorder.stop(_env());
      expect(bugSessionSessionIncludesAuthentication(session), isTrue);
    });
  });
}
