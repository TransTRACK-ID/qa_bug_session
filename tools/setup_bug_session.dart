// @dart=3.12
// ignore_for_file: avoid_print
//
// Zero-touch BugSession host setup: scan, generate, patch, verify.
//
//   cd qa_bug_session/tools && dart pub get && dart run setup_bug_session.dart --project-dir /path/to/app
//
import 'dart:io';

import 'setup_patch.dart';
import 'setup_scan.dart';
import 'setup_templates.dart';

void main(List<String> args) async {
  final options = _parseArgs(args);
  final projectDir = options.projectDir;
  if (!Directory(projectDir).existsSync()) {
    stderr.writeln('Project dir not found: $projectDir');
    exitCode = 1;
    return;
  }

  final pubspecFile = File('$projectDir/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No pubspec.yaml in $projectDir');
    exitCode = 1;
    return;
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final packageName =
      options.packageName ?? _readPackageName(pubspecContent);
  final packageLibPath = _packageLibPath(options.outputDir);

  print('BugSession zero-touch setup → $packageName');

  BugSessionProjectScan scan;
  try {
    scan = scanProject(
      projectDir: projectDir,
      pubspecContent: pubspecContent,
      routerDir: options.routerDir,
    );
  } catch (e) {
    stderr.writeln('Scan failed: $e');
    exitCode = 1;
    return;
  }

  print('  main: ${scan.mainFile}');
  print('  app:  ${scan.appFile}');
  print('  router: ${scan.router.kind} (${scan.router.routes.length} routes)');

  if (!_routerAcceptable(scan.router)) {
    if (options.routerDir == null) {
      stderr.writeln('');
      stderr.writeln(
        'Could not read GoRouter name/path pairs under lib/.',
      );
      stderr.writeln(
        'Re-run with: --router-dir lib/helpers  (directory that contains GoRoute definitions)',
      );
      exitCode = 1;
      return;
    }
    stderr.writeln('');
    stderr.writeln(
      'Still could not read routes under ${options.routerDir}. Setup aborted.',
    );
    exitCode = 1;
    return;
  }

  _mergePubspecDependencies(
    pubspecFile,
    gitUrl: options.gitUrl,
    gitRef: options.gitRef,
  );

  final files = generateBugSessionFiles(
    packageName: packageName,
    packageLibPath: packageLibPath,
    scan: scan,
  );

  for (final entry in files.entries) {
    final file = File('$projectDir/${options.outputDir}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
    print('  wrote: ${file.path}');
  }

  await _runRegistry(
    toolsDir: options.toolsDir,
    projectDir: projectDir,
    registryOutput: options.registryOutput,
    applyDesignSystem: scan.hasDesignSystem,
    packageName: packageName,
    packageLibPath: packageLibPath,
  );

  _patchHostFiles(
    projectDir: projectDir,
    scan: scan,
    packageName: packageName,
    packageLibPath: packageLibPath,
    force: options.force,
  );

  print('  running flutter pub get…');
  final pubGet = await Process.run(
    'flutter',
    ['pub', 'get'],
    workingDirectory: projectDir,
  );
  stdout.write(pubGet.stdout);
  stderr.write(pubGet.stderr);
  if (pubGet.exitCode != 0) {
    exitCode = pubGet.exitCode;
    return;
  }

  print('  running flutter analyze (lib/bug_session + patched files)…');
  final analyze = await Process.run(
    'flutter',
    [
      'analyze',
      options.outputDir,
      scan.mainFile,
      scan.appFile,
      if (scan.dioSetupFile != null) scan.dioSetupFile!,
      if (scan.router.kind == BugSessionRouterKind.goRouter)
        scan.router.sourceFile,
    ],
    workingDirectory: projectDir,
  );
  stdout.write(analyze.stdout);
  stderr.write(analyze.stderr);
  if (analyze.exitCode != 0) {
    stderr.writeln('flutter analyze reported issues — fix or re-run with --force.');
    exitCode = analyze.exitCode;
    return;
  }

  print('');
  print('BugSession setup complete. Run your dev/staging main: ${scan.mainFile}');
}

bool _routerAcceptable(BugSessionRouterScan router) {
  if (router.kind == BugSessionRouterKind.goRouter && router.routes.isNotEmpty) {
    return true;
  }
  if (router.kind == BugSessionRouterKind.autoRoute && router.routes.isNotEmpty) {
    return true;
  }
  return false;
}

void _patchHostFiles({
  required String projectDir,
  required BugSessionProjectScan scan,
  required String packageName,
  required String packageLibPath,
  required bool force,
}) {
  final mainFile = File('$projectDir/${scan.mainFile}');
  mainFile.writeAsStringSync(
    patchMainDart(
      content: mainFile.readAsStringSync(),
      packageName: packageName,
      packageLibPath: packageLibPath,
    ),
  );
  print('  patched: ${mainFile.path}');

  final appFile = File('$projectDir/${scan.appFile}');
  if (appFile.existsSync()) {
    appFile.writeAsStringSync(
      patchAppDart(
        content: appFile.readAsStringSync(),
        packageName: packageName,
        packageLibPath: packageLibPath,
      ),
    );
    print('  patched: ${appFile.path}');
  }

  if (scan.router.kind == BugSessionRouterKind.goRouter) {
    final routerFile = File('$projectDir/${scan.router.sourceFile}');
    if (routerFile.existsSync()) {
      routerFile.writeAsStringSync(
        patchRouterFile(
          content: routerFile.readAsStringSync(),
          packageName: packageName,
          packageLibPath: packageLibPath,
        ),
      );
      print('  patched: ${routerFile.path}');
    }
  }

  if (scan.dioSetupFile != null) {
    final dioFile = File('$projectDir/${scan.dioSetupFile}');
    if (dioFile.existsSync()) {
      dioFile.writeAsStringSync(
        patchDioFile(
          content: dioFile.readAsStringSync(),
          packageName: packageName,
          packageLibPath: packageLibPath,
        ),
      );
      print('  patched: ${dioFile.path}');
    }
  }
}

Future<void> _runRegistry({
  required String toolsDir,
  required String projectDir,
  required String registryOutput,
  required bool applyDesignSystem,
  required String packageName,
  required String packageLibPath,
}) async {
  final registryScript = File('$toolsDir/generate_recorder_registry.dart');
  if (!registryScript.existsSync()) {
    stderr.writeln('Registry script missing: ${registryScript.path}');
    exitCode = 1;
    return;
  }
  print('  running registry codegen…');
  final args = [
    registryScript.path,
    '--project-dir',
    projectDir,
    '--output',
    registryOutput,
  ];
  if (applyDesignSystem) {
    args.add('--apply-bs-app-button');
    print('  (AppButton → BsAppButton codemod: transtrack_design_system detected)');
  }
  final result = await Process.run('dart', args);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }
  _wireRegistryImport(
    File('$projectDir/$packageLibPath/bug_session_kit.dart'),
    packageName: packageName,
    packageLibPath: packageLibPath,
    registryOutput: registryOutput,
  );
}

void _wireRegistryImport(
  File kitFile, {
  required String packageName,
  required String packageLibPath,
  required String registryOutput,
}) {
  if (!kitFile.existsSync()) {
    return;
  }
  var content = kitFile.readAsStringSync();
  if (content.contains('resolveBugSessionRecorderTargetId')) {
    return;
  }
  final registryPath = registryOutput.replaceAll('\\', '/');
  final registryLib = registryPath.startsWith('lib/')
      ? registryPath.substring(4)
      : registryPath;
  final registryImport =
      "import 'package:$packageName/$registryLib';";
  final importAnchor =
      "import 'package:$packageName/$packageLibPath/bug_session_gate.dart';";
  content = content.replaceFirst(
    importAnchor,
    "$importAnchor\n$registryImport",
  );
  content = content.replaceFirst(
    '// BUG_SESSION_REGISTRY resolveRecorderTargetId',
    'resolveRecorderTargetId: resolveBugSessionRecorderTargetId,',
  );
  kitFile.writeAsStringSync(content);
}

class _Options {
  _Options({
    required this.projectDir,
    required this.outputDir,
    required this.registryOutput,
    required this.packageName,
    required this.gitUrl,
    required this.gitRef,
    required this.routerDir,
    required this.force,
    required this.toolsDir,
  });

  final String projectDir;
  final String outputDir;
  final String registryOutput;
  final String? packageName;
  final String gitUrl;
  final String gitRef;
  final String? routerDir;
  final bool force;
  final String toolsDir;
}

_Options _parseArgs(List<String> args) {
  var projectDir = Directory.current.path;
  var outputDir = 'lib/bug_session';
  var registryOutput = 'lib/generated/bug_session_recorder_registry.g.dart';
  String? packageName;
  var gitUrl = 'https://github.com/TransTRACK-ID/qa_bug_session.git';
  var gitRef = 'v1.1.0';
  String? routerDir;
  var force = false;

  final scriptPath = Platform.script.toFilePath();
  var toolsDir = File(scriptPath).parent.path;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project-dir':
        projectDir = _abs(args[++i], base: Directory.current.path);
      case '--output-dir':
        outputDir = args[++i].replaceAll('\\', '/');
      case '--registry-output':
        registryOutput = args[++i];
      case '--package-name':
        packageName = args[++i];
      case '--git-url':
        gitUrl = args[++i];
      case '--git-ref':
        gitRef = args[++i];
      case '--router-dir':
        routerDir = args[++i].replaceAll('\\', '/');
      case '--force':
        force = true;
      case '--tools-dir':
        toolsDir = args[++i];
      case '--help':
        print(_help);
        exit(0);
    }
  }

  return _Options(
    projectDir: projectDir,
    outputDir: outputDir,
    registryOutput: registryOutput,
    packageName: packageName,
    gitUrl: gitUrl,
    gitRef: gitRef,
    routerDir: routerDir,
    force: force,
    toolsDir: toolsDir,
  );
}

String _abs(String path, {required String base}) {
  final d = Directory(path);
  if (d.isAbsolute) {
    return d.path;
  }
  return Directory('$base/$path').absolute.path;
}

String _packageLibPath(String outputDir) {
  final norm = outputDir.replaceAll('\\', '/');
  return norm.startsWith('lib/') ? norm.substring(4) : norm;
}

const _help = '''
setup_bug_session.dart — zero-touch BugSession host integration

  --project-dir PATH     Flutter app root (default: cwd)
  --router-dir PATH      Retry: directory with GoRoute definitions
  --git-ref REF          qa_bug_session tag (default: v1.1.0)
  --force                Overwrite generated lib/bug_session/*
  --help

Always: registry codegen, package video capture, patch main/app/router/dio.
Gate: dev / development / staging flavors only.
Main: main_development.dart → main_staging.dart → main.dart
''';

String _readPackageName(String pubspec) {
  final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (match == null) {
    throw StateError('Could not read name: from pubspec.yaml');
  }
  return match.group(1)!;
}

void _mergePubspecDependencies(
  File pubspecFile, {
  required String gitUrl,
  required String gitRef,
}) {
  var content = pubspecFile.readAsStringSync();
  if (!content.contains('qa_bug_session:')) {
    final block = '''
  qa_bug_session:
    git:
      url: $gitUrl
      ref: $gitRef
''';
    content = _insertIntoDependencies(content, block);
  } else if (content.contains('ref: v1.0.0')) {
    content = content.replaceAll('ref: v1.0.0', 'ref: $gitRef');
  }

  final deps = <String, String>{
    'device_info_plus': '^11.2.0',
    'package_info_plus': '^8.1.2',
    'file_picker': '^8.1.7',
    'share_plus': '^10.1.4',
    'flutter_secure_storage': '^9.2.4',
    'dio': '^5.9.0',
  };

  for (final entry in deps.entries) {
    if (!content.contains(RegExp('^\\s*${entry.key}:', multiLine: true))) {
      content = _insertIntoDependencies(
        content,
        '  ${entry.key}: ${entry.value}\n',
      );
    }
  }

  pubspecFile.writeAsStringSync(content);
}

String _insertIntoDependencies(String content, String snippet) {
  final match =
      RegExp(r'^dependencies:\s*$', multiLine: true).firstMatch(content);
  if (match == null) {
    return '$content\n$snippet';
  }
  final insertAt = match.end;
  return '${content.substring(0, insertAt)}\n$snippet${content.substring(insertAt)}';
}
