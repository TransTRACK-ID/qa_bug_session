// @dart=3.12
import 'setup_scan.dart';

Map<String, String> generateBugSessionFiles({
  required String packageName,
  required String packageLibPath,
  required BugSessionProjectScan scan,
}) {
  final p = packageName;
  final lp = packageLibPath;
  final gate = "import 'package:$p/$lp/bug_session_gate.dart';";
  final env = "import 'package:$p/$lp/bug_session_environment.dart';";
  final cred = "import 'package:$p/$lp/bug_session_credential_injector.dart';";
  final picker = "import 'package:$p/$lp/bug_session_file_picker.dart';";
  final share = "import 'package:$p/$lp/bug_session_share.dart';";
  final nav = "import 'package:$p/$lp/bug_session_navigation.dart';";
  final diag = "import 'package:$p/$lp/bug_session_diagnostics.dart';";
  final hooks = "import 'package:$p/$lp/bug_session_error_hooks.dart';";

  final routeMap = _routeMapLiteral(scan.router.routes);
  final storage = _storageTemplate(p, lp, scan.accessTokenKey);
  final navigation = _navigationTemplate(p, lp, routeMap, scan.router.kind);

  return {
    'bug_session_gate.dart': '''
import 'package:flutter_flavor/flutter_flavor.dart';

/// BugSession tools: dev / development / staging flavors only.
bool isBugSessionToolsEnabled() {
  final name = FlavorConfig.instance.name;
  return name == 'dev' || name == 'development' || name == 'staging';
}
''',
    'bug_session_storage.dart': storage,
    'bug_session_credential_injector.dart': _credentialTemplate(p, lp, scan.accessTokenKey),
    'bug_session_file_picker.dart': _filePickerTemplate(),
    'bug_session_share.dart': _shareTemplate(),
    'bug_session_environment.dart': _environmentTemplate(gate, storage.split('\n').first),
    'bug_session_diagnostics.dart': '''
$gate
import 'bug_session_kit_holder.dart';

void recordBugSessionDiagnostic(
  String type,
  String message, {
  String? stackTrace,
}) {
  final kit = bugSessionKitOrNull;
  if (!isBugSessionToolsEnabled() || kit == null) {
    return;
  }
  final recorder = kit.recorder;
  if (!recorder.isRecording) {
    return;
  }
  recorder.recordDiagnostic(type, message, stackTrace: stackTrace);
}

String truncateBugSessionLog(String value, {int maxLength = 240}) {
  if (value.length <= maxLength) {
    return value;
  }
  return '\${value.substring(0, maxLength)}…';
}
''',
    'bug_session_error_hooks.dart': '''
import 'package:flutter/foundation.dart';
$gate
$diag

FlutterExceptionHandler? _previousFlutterErrorHandler;
bool _hooksInstalled = false;

void installBugSessionErrorHooks() {
  if (!isBugSessionToolsEnabled() || _hooksInstalled) {
    return;
  }
  _hooksInstalled = true;
  _previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    recordBugSessionDiagnostic(
      'flutter_error',
      truncateBugSessionLog(details.exceptionAsString()),
      stackTrace: truncateBugSessionLog(
        details.stack?.toString() ?? '',
        maxLength: 1200,
      ),
    );
    _previousFlutterErrorHandler?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    recordBugSessionDiagnostic(
      'platform_error',
      truncateBugSessionLog(error.toString()),
      stackTrace: truncateBugSessionLog(stack.toString(), maxLength: 1200),
    );
    return false;
  };
}
''',
    'bug_session_navigation.dart': navigation,
    'bug_session_kit_holder.dart': '''
import 'package:qa_bug_session/qa_bug_session.dart';

BugSessionKit? _bugSessionKit;

BugSessionKit? get bugSessionKitOrNull => _bugSessionKit;

BugSessionKit get bugSessionKit {
  final kit = _bugSessionKit;
  if (kit == null) {
    throw StateError('Call initializeBugSession() before using BugSessionKit');
  }
  return kit;
}

void registerBugSessionKit(BugSessionKit kit) {
  _bugSessionKit = kit;
}
''',
    'bs_recorder_button.dart': _bsRecorderButtonTemplate(),
    'bug_session_kit.dart': _kitTemplate(p, lp, gate, env, cred, picker, share, nav, hooks),
  };
}

String _routeMapLiteral(List<BugSessionRouteEntry> routes) {
  if (routes.isEmpty) {
    return '<String, String>{}';
  }
  final lines = routes.map((r) => "  '${_escape(r.name)}': '${_escape(r.path)}',");
  return '<String, String>{\n${lines.join('\n')}\n}';
}

String _escape(String s) => s.replaceAll(r"'", r"\'");

String _storageTemplate(String p, String lp, String? tokenKey) {
  if (tokenKey == 'kAccessToken') {
    return '''
import 'package:$p/utils/constants.dart';
import 'package:$p/utils/get_it.dart';

abstract final class BugSessionStorage {
  static Future<String?> readAccessToken() =>
      secureStorage.read(key: kAccessToken);

  static Future<String?> readUserId() async {
    final profile = userHelper.getUserProfile();
    return profile?.id ?? profile?.email;
  }

  static Future<String?> readDisplayHint() async {
    final profile = userHelper.getUserProfile();
    return profile?.name ?? profile?.email;
  }

  static Future<void> writeAccessToken(String value) =>
      secureStorage.write(key: kAccessToken, value: value);

  static Future<void> writeUserId(String value) async {}

  static Future<void> writeDisplayHint(String value) async {}

  static Future<void> clearDisplayHint() async {}
}
''';
  }
  return '''
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class BugSessionStorage {
  static const _secure = FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  static Future<String?> readAccessToken() => _secure.read(key: _tokenKey);
  static Future<String?> readUserId() async => null;
  static Future<String?> readDisplayHint() async => null;
  static Future<void> writeAccessToken(String value) =>
      _secure.write(key: _tokenKey, value: value);
  static Future<void> writeUserId(String value) async {}
  static Future<void> writeDisplayHint(String value) async {}
  static Future<void> clearDisplayHint() async {}
}
''';
}

String _credentialTemplate(String p, String lp, String? tokenKey) {
  if (tokenKey == 'kAccessToken') {
    return '''
import 'package:$p/utils/constants.dart';
import 'package:$p/utils/get_it.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

class BugSessionCredentialInjector implements CredentialInjector {
  String? _tokenSnapshot;

  @override
  Future<void> inject(
    BugSessionCredential credential, {
    BugSessionUser? user,
  }) async {
    _tokenSnapshot = await secureStorage.read(key: kAccessToken);
    await secureStorage.write(
      key: kAccessToken,
      value: credential.accessToken,
    );
  }

  @override
  Future<String> resolveUserId() async {
    final profile = userHelper.getUserProfile();
    return profile?.id ?? profile?.email ?? '';
  }

  @override
  Future<bool> tryRefresh(BugSessionCredential credential) async => false;

  @override
  Future<void> restorePreviousSession() async {
    final token = _tokenSnapshot;
    if (token != null) {
      await secureStorage.write(key: kAccessToken, value: token);
    }
    _tokenSnapshot = null;
  }
}
''';
  }
  return '''
import 'package:qa_bug_session/qa_bug_session.dart';
import 'bug_session_storage.dart';

class BugSessionCredentialInjector implements CredentialInjector {
  String? _tokenSnapshot;

  @override
  Future<void> inject(
    BugSessionCredential credential, {
    BugSessionUser? user,
  }) async {
    _tokenSnapshot = await BugSessionStorage.readAccessToken();
    await BugSessionStorage.writeAccessToken(credential.accessToken);
  }

  @override
  Future<String> resolveUserId() async =>
      await BugSessionStorage.readUserId() ?? '';

  @override
  Future<bool> tryRefresh(BugSessionCredential credential) async => false;

  @override
  Future<void> restorePreviousSession() async {
    final token = _tokenSnapshot;
    if (token != null) {
      await BugSessionStorage.writeAccessToken(token);
    }
    _tokenSnapshot = null;
  }
}
''';
}

String _navigationTemplate(
  String p,
  String lp,
  String routeMap,
  BugSessionRouterKind kind,
) {
  final getItImport = "import 'package:$p/utils/get_it.dart';";
  final replayBody = kind == BugSessionRouterKind.goRouter
      ? '''
  final router = navigation.goRouter;
  if (action.type == RecordedActionType.back) {
    if (router.canPop()) {
      router.pop();
    }
    await replayBugSessionSettle(
      completedAction: action,
      shouldStop: shouldStop,
    );
    return;
  }
  final payload = action.route;
  if (payload == null || payload.isEmpty) {
    throw FormatException('Navigation action missing route payload');
  }
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final name = decoded['name'] as String;
  final label = decoded['label'] as String?;
  if (label == 'session_start') {
    return;
  }
  final path = _bugSessionRouteNameToPath[name];
  if (path == null) {
    throw FormatException('Unknown go_router name for replay: \$name');
  }
  router.go(path);
  await replayBugSessionSettle(
    completedAction: action,
    shouldStop: shouldStop,
  );
'''
      : '''
  throw UnimplementedError(
    'Navigation replay requires GoRouter routes in this app. Use registry/coordinate taps.',
  );
''';

  return '''
import 'dart:convert';

import 'package:flutter/material.dart';
$getItImport
import 'package:qa_bug_session/qa_bug_session.dart';

import 'bug_session_kit_holder.dart';

final bugSessionNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'bugSessionRoot');

final _bugSessionRouteNameToPath = $routeMap;

String? encodeBugSessionRoute(Route<dynamic> route) {
  final name = route.settings.name;
  if (name == null || name.isEmpty) {
    return null;
  }
  final args = route.settings.arguments;
  Object? encodedArgs;
  if (args is Map<String, dynamic>) {
    encodedArgs = args;
  } else if (args != null) {
    encodedArgs = {
      'runtimeType': args.runtimeType.toString(),
      'value': args.toString(),
    };
  }
  return jsonEncode({
    'name': name,
    if (encodedArgs != null) 'args': encodedArgs,
  });
}

String? bugSessionCurrentRouteName() {
  ${kind == BugSessionRouterKind.goRouter ? '''
  try {
    return navigation.goRouter.routerDelegate.currentConfiguration.uri.toString();
  } catch (_) {
    return null;
  }
  ''' : 'return null;'}
}

class BugSessionNavigationObserver extends NavigatorObserver {
  void _append(RecordedAction action) {
    final kit = bugSessionKitOrNull;
    if (kit == null) {
      return;
    }
    final recorder = kit.recorder;
    if (recorder.isRecording) {
      recorder.semantic.recordAction(action);
    } else if (recorder.isShadowplayActive) {
      recorder.recordShadowplayAction(action);
    }
  }

  void _record(Route<dynamic> route) {
    final kit = bugSessionKitOrNull;
    if (kit == null || !kit.recorder.isCapturing) {
      return;
    }
    final payload = encodeBugSessionRoute(route);
    if (payload == null) {
      return;
    }
    final recorder = kit.recorder;
    final ts = recorder.isShadowplayActive
        ? recorder.shadowplay.elapsedMs()
        : recorder.semantic.elapsedMs();
    _append(RecordedAction(
      type: RecordedActionType.navigation,
      timestampMs: ts,
      route: payload,
    ));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _record(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final kit = bugSessionKitOrNull;
    if (kit == null || !kit.recorder.isCapturing) {
      return;
    }
    final recorder = kit.recorder;
    final ts = recorder.isShadowplayActive
        ? recorder.shadowplay.elapsedMs()
        : recorder.semantic.elapsedMs();
    _append(RecordedAction(
      type: RecordedActionType.back,
      timestampMs: ts,
    ));
  }
}

final bugSessionNavigationObserver = BugSessionNavigationObserver();

Future<void> replayBugSessionNavigation(
  RecordedAction action, {
  bool Function()? shouldStop,
}) async {
$replayBody
}

Future<void> replayBugSessionSettle({
  required RecordedAction completedAction,
  RecordedAction? nextAction,
  bool Function()? shouldStop,
}) async {
  var remaining = 450;
  while (remaining > 0) {
    if (shouldStop?.call() == true) {
      return;
    }
    final chunk = remaining > 100 ? 100 : remaining;
    await Future<void>.delayed(Duration(milliseconds: chunk));
    remaining -= chunk;
  }
}
''';
}

String _kitTemplate(
  String p,
  String lp,
  String gate,
  String env,
  String cred,
  String picker,
  String share,
  String nav,
  String hooks,
) {
  return '''
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:qa_bug_session/qa_bug_session.dart';
$gate
$env
$cred
$picker
$share
$nav
$hooks

import 'bug_session_kit_holder.dart';

Future<void> initializeBugSession() async {
  if (!isBugSessionToolsEnabled() || bugSessionKitOrNull != null) {
    return;
  }

  installBugSessionErrorHooks();
  await refreshBugSessionEnvironmentSnapshot();

  final kit = await BugSessionKit.initialize(
    config: BugSessionConfig(
      enabled: true,
      environmentLabel: FlavorConfig.instance.name ?? 'development',
      credentialInjector: BugSessionCredentialInjector(),
      navigatorKey: bugSessionNavigatorKey,
      filePicker: BugSessionHostFilePicker(),
      refreshEnvironment: refreshBugSessionEnvironmentSnapshot,
      openLibraryAfterImport: true,
      replayNavigation: replayBugSessionNavigation,
      replaySettle: replayBugSessionSettle,
      manualRecordWithShadowplay: true,
      expandPanelWhenSheetClosed: true,
      validateUserIdentityOnReplay: false,
      restoreSessionAfterReplay: false,
      currentRouteName: bugSessionCurrentRouteName,
      shareExport: shareBugSessionZipExport,
      openShareSheetAfterExport: true,
      // BUG_SESSION_REGISTRY resolveRecorderTargetId
      videoCapture: BugSessionDefaultVideoCapture(),
      maxVideoDuration: const Duration(minutes: 1),
      shadowplay: const BugSessionShadowplaySettings(
        enabled: true,
        mode: BugSessionShadowplayMode.raw,
        rawEventRetention: Duration(seconds: 90),
        semanticEventRetention: Duration(seconds: 90),
        defaultVideoRetention: Duration(seconds: 90),
        maxVideoRetention: Duration(seconds: 90),
      ),
      environmentBuilder: () {
        return bugSessionEnvironmentSnapshot.build() ??
            bugSessionEnvironmentSnapshot.buildForReplay();
      },
    ),
  );
  registerBugSessionKit(kit);
}

Widget wrapWithBugSession({required Widget app}) {
  final kit = bugSessionKitOrNull;
  if (kit == null) {
    return app;
  }
  return kit.wrap(app: app);
}

TransitionBuilder? bugSessionMaterialAppBuilder() {
  if (bugSessionKitOrNull == null) {
    return null;
  }
  return bugSessionKit.wrapMaterialAppBuilder(
    (context, child) => wrapBugSessionDefaultVideoHost(
      child ?? const SizedBox.shrink(),
      enabled: isBugSessionToolsEnabled,
    ),
  );
}

void attachBugSessionToDio(Dio dio) {
  bugSessionKitOrNull?.attachDio(dio);
}
''';
}

String _environmentTemplate(String gateImport, String storageImportLine) {
  return '''
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:package_info_plus/package_info_plus.dart';
$gateImport
import 'bug_session_storage.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

final bugSessionEnvironmentSnapshot = BugSessionEnvironmentSnapshot();

class BugSessionEnvironmentSnapshot {
  PackageInfo? packageInfo;
  String? osVersion;
  String? deviceModel;
  String? accessToken;
  String? userId;
  String? displayHint;

  BugSessionEnvironment? build() {
    final info = packageInfo;
    final token = accessToken;
    final userId = this.userId;
    if (info == null || token == null || userId == null) {
      return null;
    }
    if (token.isEmpty || userId.isEmpty) {
      return null;
    }
    return _environment(
      info: info,
      userId: userId,
      token: token,
      displayHint: displayHint,
    );
  }

  BugSessionEnvironment buildForReplay() {
    final info = packageInfo;
    if (info == null) {
      throw StateError('BugSession package info is not loaded yet');
    }
    return _environment(
      info: info,
      userId: userId ?? '',
      token: accessToken ?? '',
      displayHint: displayHint,
    );
  }

  BugSessionEnvironment _environment({
    required PackageInfo info,
    required String userId,
    required String token,
    required String? displayHint,
  }) {
    return BugSessionEnvironment(
      packageId: info.packageName,
      appVersion: info.version,
      buildNumber: info.buildNumber,
      platform: Platform.operatingSystem,
      osVersion: osVersion ?? Platform.operatingSystemVersion,
      deviceModel: deviceModel,
      environment: FlavorConfig.instance.name ?? 'development',
      user: BugSessionUser(
        userId: userId,
        displayHint: displayHint,
        profileData: displayHint == null
            ? null
            : {'profileName': displayHint},
      ),
      credential: BugSessionCredential(
        type: 'bearer',
        accessToken: token,
        refreshToken: userId.isNotEmpty ? userId : null,
      ),
    );
  }
}

Future<void> refreshBugSessionEnvironmentSnapshot() async {
  if (!isBugSessionToolsEnabled()) {
    return;
  }
  bugSessionEnvironmentSnapshot.packageInfo =
      await PackageInfo.fromPlatform();
  bugSessionEnvironmentSnapshot.accessToken =
      await BugSessionStorage.readAccessToken();
  bugSessionEnvironmentSnapshot.userId =
      await BugSessionStorage.readUserId();
  bugSessionEnvironmentSnapshot.displayHint =
      await BugSessionStorage.readDisplayHint();

  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final android = await deviceInfo.androidInfo;
    bugSessionEnvironmentSnapshot.osVersion = android.version.release;
    bugSessionEnvironmentSnapshot.deviceModel = android.model;
  } else if (Platform.isIOS) {
    final ios = await deviceInfo.iosInfo;
    bugSessionEnvironmentSnapshot.osVersion = ios.systemVersion;
    bugSessionEnvironmentSnapshot.deviceModel = ios.utsname.machine;
  } else {
    bugSessionEnvironmentSnapshot.osVersion = Platform.operatingSystemVersion;
  }
}
''';
}

String _filePickerTemplate() => '''
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

class BugSessionHostFilePicker implements BugSessionFilePicker {
  @override
  Future<Uint8List?> pickBugSessionZip() async {
    final files = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (files == null || files.files.isEmpty) {
      return null;
    }
    final path = files.files.single.path;
    if (path == null) {
      return null;
    }
    return File(path).readAsBytes();
  }
}
''';

String _shareTemplate() => '''
import 'dart:io';

import 'package:qa_bug_session/qa_bug_session.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareBugSessionZipExport(BugSessionShareExportRequest request) async {
  final zipFile = File(request.zipPath);
  if (!await zipFile.exists()) {
    throw StateError('Export file not found');
  }
  final zipName = request.zipPath.split(Platform.pathSeparator).last;
  final files = <XFile>[
    XFile(request.zipPath, name: zipName, mimeType: 'application/zip'),
  ];

  final videoPath = request.videoPath ??
      await resolveBugSessionShareVideoPath(
        zipPath: request.zipPath,
        videoSidecarPath: null,
      );
  if (videoPath != null) {
    final videoFile = File(videoPath);
    if (await videoFile.exists()) {
      files.insert(
        0,
        XFile(
          videoPath,
          name: videoPath.split(Platform.pathSeparator).last,
          mimeType: bugSessionShareVideoMimeType(videoPath),
        ),
      );
    }
  }

  const caption =
      'BugSession export — may contain credentials. Share only with trusted recipients.';

  await Share.shareXFiles(
    files,
    subject: caption,
    text: Platform.isAndroid ? null : caption,
  );
}
''';

String _bsRecorderButtonTemplate() => '''
import 'package:flutter/material.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

class BsRecorderButton extends StatelessWidget {
  const BsRecorderButton({
    super.key,
    required this.id,
    required this.label,
    required this.onPressed,
  });

  final String id;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return RecorderTap(
      id: id,
      onPressed: onPressed ?? () {},
      child: ElevatedButton(
        onPressed: null,
        child: Text(label),
      ),
    );
  }
}
''';
