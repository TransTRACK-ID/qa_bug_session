// @dart=3.12
import 'dart:io';

const bugSessionSetupMarker = 'BUG_SESSION_SETUP';

void ensureImport(String content, String importLine) {
  if (content.contains(importLine)) {
    return;
  }
  throw StateError('ensureImport helper misuse — use patchImport instead');
}

String patchImport(String content, String importLine) {
  if (content.contains(importLine.trim())) {
    return content;
  }
  final lastImport = content.lastIndexOf(RegExp(r"^import\s+'", multiLine: true));
  if (lastImport == -1) {
    return "$importLine\n$content";
  }
  final lineEnd = content.indexOf('\n', lastImport);
  final insertAt = lineEnd == -1 ? content.length : lineEnd + 1;
  return '${content.substring(0, insertAt)}$importLine\n${content.substring(insertAt)}';
}

String patchMainDart({
  required String content,
  required String packageName,
  required String packageLibPath,
}) {
  var out = content;
  final kitImport =
      "import 'package:$packageName/$packageLibPath/bug_session_kit.dart';";
  out = patchImport(out, kitImport);

  if (!out.contains('initializeBugSession')) {
    out = _insertAfterFlavorOrBeforeRun(out, '''
  // $bugSessionSetupMarker
  await initializeBugSession();
''');
  }

  if (!out.contains('wrapWithBugSession')) {
    out = _wrapRunApp(out);
  }

  return out;
}

String _insertAfterFlavorOrBeforeRun(String content, String snippet) {
  final flavorClose = content.indexOf(');', content.indexOf('FlavorConfig('));
  if (flavorClose != -1) {
    final insertAt = flavorClose + 2;
    return '${content.substring(0, insertAt)}\n$snippet${content.substring(insertAt)}';
  }
  final runApp = content.indexOf('runApp(');
  if (runApp != -1) {
    return '${content.substring(0, runApp)}$snippet\n${content.substring(runApp)}';
  }
  final datadog = content.indexOf('DatadogSdk.runApp(');
  if (datadog != -1) {
    return '${content.substring(0, datadog)}$snippet\n${content.substring(datadog)}';
  }
  return '$content\n$snippet';
}

String _wrapRunApp(String content) {
  // DatadogSdk.runApp(..., () async { runApp( WIDGET ); });
  final datadogRunApp = RegExp(
    r'runApp\s*\(\s*([\s\S]*?)\s*\)\s*;\s*\}\s*,\s*\)\s*;',
  ).firstMatch(content);
  if (datadogRunApp != null) {
    final widget = datadogRunApp.group(1)!.trim();
    if (widget.contains('wrapWithBugSession')) {
      return content;
    }
    return content.replaceFirst(
      datadogRunApp.group(0)!,
      'runApp(\n        wrapWithBugSession(app: $widget),\n      );\n    },\n  );',
    );
  }

  final simple = RegExp(r'runApp\s*\(\s*([\s\S]*?)\s*\)\s*;').firstMatch(content);
  if (simple != null) {
    final widget = simple.group(1)!.trim();
    if (widget.contains('wrapWithBugSession')) {
      return content;
    }
    return content.replaceFirst(
      simple.group(0)!,
      'runApp(wrapWithBugSession(app: $widget));',
    );
  }
  return content;
}

String patchAppDart({
  required String content,
  required String packageName,
  required String packageLibPath,
}) {
  var out = content;
  final kitImport =
      "import 'package:$packageName/$packageLibPath/bug_session_kit.dart';";
  out = patchImport(out, kitImport);

  if (out.contains('bugSessionMaterialAppBuilder')) {
    return out;
  }

  if (out.contains('builder: (context, child)') &&
      !out.contains('bugSessionMaterialAppBuilder')) {
    out = out.replaceFirstMapped(
      RegExp(
        r'builder:\s*\(context,\s*child\)\s*\{([\s\S]*?)\n\s*\},\s*\n\s*theme:',
      ),
      (match) {
        final body = match.group(1)!;
        return '''builder: (context, child) {
          Widget bugSessionBody;
$body
          final bugSessionBuilder = bugSessionMaterialAppBuilder();
          if (bugSessionBuilder != null) {
            bugSessionBody = bugSessionBuilder(context, bugSessionBody);
          }
          return bugSessionBody;
        },
        theme:''';
      },
    );
    if (!out.contains('bugSessionMaterialAppBuilder')) {
      out = out.replaceFirstMapped(
        RegExp(
          r'(builder:\s*\(context,\s*child\)\s*\{[\s\S]*?)(return\s+[^;]+;)([\s\S]*?\},)',
        ),
        (m) {
          final ret = m.group(2)!;
          final expr = ret.replaceFirst('return ', '').replaceAll(';', '').trim();
          return '${m.group(1)}Widget bugSessionBody = $expr;\n'
              '          final bugSessionBuilder = bugSessionMaterialAppBuilder();\n'
              '          if (bugSessionBuilder != null) {\n'
              '            bugSessionBody = bugSessionBuilder(context, bugSessionBody);\n'
              '          }\n'
              '          return bugSessionBody;${m.group(3)}';
        },
      );
    }
  } else if (out.contains('MaterialApp.router(')) {
    out = out.replaceFirst(
      'MaterialApp.router(',
      'MaterialApp.router(\n        builder: bugSessionMaterialAppBuilder(),',
    );
  }

  return out;
}

String patchRouterFile({
  required String content,
  required String packageName,
  required String packageLibPath,
}) {
  var out = content;
  final navImport =
      "import 'package:$packageName/$packageLibPath/bug_session_navigation.dart';";
  out = patchImport(out, navImport);

  if (!out.contains('bugSessionNavigationObserver')) {
    out = out.replaceFirst(
      RegExp(r'observers:\s*\['),
      'observers: [\n      bugSessionNavigationObserver,',
    );
  }

  out = out.replaceAllMapped(
    RegExp(r'navigatorKey:\s*[^,\n]+,'),
    (m) {
      if (m.group(0)!.contains('bugSessionNavigatorKey')) {
        return m.group(0)!;
      }
      return 'navigatorKey: bugSessionNavigatorKey,';
    },
  );

  return out;
}

String patchDioFile({
  required String content,
  required String packageName,
  required String packageLibPath,
}) {
  var out = content;
  final kitImport =
      "import 'package:$packageName/$packageLibPath/bug_session_kit.dart';";
  out = patchImport(out, kitImport);

  if (out.contains('attachBugSessionToDio')) {
    return out;
  }

  final dioCreate = RegExp(r'final\s+dio\s*=\s*Dio\([^;]*\)\s*;');
  final match = dioCreate.firstMatch(out);
  if (match != null) {
    return out.replaceFirst(
      match.group(0)!,
      '${match.group(0)!}\n    attachBugSessionToDio(dio);',
    );
  }
  return out;
}

void writeIfChanged(File file, String content, {required bool force}) {
  if (file.existsSync() && file.readAsStringSync() == content) {
    return;
  }
  if (file.existsSync() && !force && !file.readAsStringSync().contains(bugSessionSetupMarker)) {
    // allow overwriting generated bug_session only — host patches always apply
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
