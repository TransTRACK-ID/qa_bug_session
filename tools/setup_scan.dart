// @dart=3.12
// ignore_for_file: avoid_print
import 'dart:io';

enum BugSessionRouterKind { goRouter, autoRoute, unknown }

class BugSessionRouteEntry {
  BugSessionRouteEntry({required this.name, required this.path});

  final String name;
  final String path;
}

class BugSessionRouterScan {
  BugSessionRouterScan({
    required this.kind,
    required this.routes,
    required this.sourceFile,
    this.routerDirUsed,
  });

  final BugSessionRouterKind kind;
  final List<BugSessionRouteEntry> routes;
  final String sourceFile;
  final String? routerDirUsed;

  bool get isUsable =>
      kind == BugSessionRouterKind.goRouter && routes.isNotEmpty;
}

class BugSessionProjectScan {
  BugSessionProjectScan({
    required this.mainFile,
    required this.appFile,
    required this.router,
    required this.accessTokenKey,
    required this.dioSetupFile,
    required this.hasDesignSystem,
  });

  final String mainFile;
  final String appFile;
  final BugSessionRouterScan router;
  final String? accessTokenKey;
  final String? dioSetupFile;
  final bool hasDesignSystem;
}

String? resolveMainFile(String projectDir) {
  for (final rel in [
    'lib/main_development.dart',
    'lib/main_staging.dart',
    'lib/main.dart',
  ]) {
    if (File('$projectDir/$rel').existsSync()) {
      return rel;
    }
  }
  return null;
}

String resolveAppFile(String projectDir) {
  const preferred = 'lib/app/app.dart';
  if (File('$projectDir/$preferred').existsSync()) {
    return preferred;
  }
  final found = _findAppDartFile(Directory('$projectDir/lib'));
  if (found != null) {
    return found;
  }
  throw StateError('No lib/app/app.dart and no MaterialApp.router / class App found');
}

String? _findAppDartFile(Directory libRoot) {
  String? materialAppFile;
  String? appClassFile;
  for (final entity in libRoot.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.contains('.g.dart') || entity.path.contains('.gr.dart')) {
      continue;
    }
    final content = entity.readAsStringSync();
    if (content.contains('MaterialApp.router')) {
      materialAppFile ??= entity.path;
    }
    if (RegExp(r'class\s+App\s+extends\s+').hasMatch(content)) {
      appClassFile ??= entity.path;
    }
  }
  if (materialAppFile != null) {
    final rel = materialAppFile.replaceFirst('$libRoot.parent.path/', '');
    return rel.startsWith('lib/') ? rel : 'lib/$rel';
  }
  if (appClassFile != null) {
    return appClassFile.replaceFirst('${libRoot.parent.path}/', '');
  }
  return null;
}

BugSessionRouterScan scanRouter({
  required String projectDir,
  String? routerDir,
  bool routerDirRetry = false,
}) {
  final candidates = <File>[];
  if (routerDir != null) {
    final dir = Directory('$projectDir/$routerDir');
    if (dir.existsSync()) {
      candidates.addAll(_dartFilesUnder(dir));
    }
  } else {
    candidates.addAll(_dartFilesUnder(Directory('$projectDir/lib')));
  }

  BugSessionRouterScan? best;
  for (final file in candidates) {
    final content = file.readAsStringSync();
    final rel = _relPath(projectDir, file.path);
    if (content.contains('GoRouter(') || content.contains('GoRouter ')) {
      final routes = _extractGoRoutes(content);
      if (routes.isNotEmpty &&
          (best == null || routes.length > best.routes.length)) {
        best = BugSessionRouterScan(
          kind: BugSessionRouterKind.goRouter,
          routes: routes,
          sourceFile: rel,
          routerDirUsed: routerDir,
        );
      }
    }
    if (rel.endsWith('.gr.dart') && content.contains('Route(')) {
      final routes = _extractAutoRouteNames(content);
      if (routes.isNotEmpty) {
        return BugSessionRouterScan(
          kind: BugSessionRouterKind.autoRoute,
          routes: routes,
          sourceFile: rel,
          routerDirUsed: routerDir,
        );
      }
    }
  }

  if (best != null) {
    return best;
  }

  return BugSessionRouterScan(
    kind: BugSessionRouterKind.unknown,
    routes: const [],
    sourceFile: routerDir != null ? 'dir:$routerDir' : 'lib/',
    routerDirUsed: routerDir,
  );
}

List<File> _dartFilesUnder(Directory dir) {
  final out = <File>[];
  if (!dir.existsSync()) {
    return out;
  }
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.contains('.g.dart')) {
      out.add(entity);
    }
  }
  return out;
}

List<BugSessionRouteEntry> _extractGoRoutes(String content) {
  final routes = <BugSessionRouteEntry>[];
  final blocks = content.split('GoRoute(');
  for (var i = 1; i < blocks.length; i++) {
    final chunk = blocks[i];
    final path = _firstQuotedAfter(chunk, 'path');
    final name = _firstQuotedAfter(chunk, 'name');
    if (path != null && name != null) {
      routes.add(BugSessionRouteEntry(name: name, path: path));
    }
  }
  final unique = <String, BugSessionRouteEntry>{};
  for (final r in routes) {
    unique[r.name] = r;
  }
  return unique.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

List<BugSessionRouteEntry> _extractAutoRouteNames(String content) {
  final routes = <BugSessionRouteEntry>[];
  for (final match in RegExp(r"name:\s*'([^']+)'").allMatches(content)) {
    final name = match.group(1)!;
    routes.add(BugSessionRouteEntry(name: name, path: '/$name'));
  }
  return routes;
}

String? _firstQuotedAfter(String chunk, String key) {
  final match = RegExp('$key\\s*:\\s*\'([^\']*)\'').firstMatch(chunk);
  return match?.group(1);
}

String? scanAccessTokenKey(String projectDir) {
  for (final file in _dartFilesUnder(Directory('$projectDir/lib'))) {
    final content = file.readAsStringSync();
    final m1 = RegExp(r"const\s+kAccessToken\s*=\s*'([^']+)'").firstMatch(content);
    if (m1 != null) {
      return 'kAccessToken';
    }
    if (content.contains('kAccessToken')) {
      return 'kAccessToken';
    }
  }
  return null;
}

String? scanDioSetupFile(String projectDir) {
  for (final file in _dartFilesUnder(Directory('$projectDir/lib'))) {
    final content = file.readAsStringSync();
    if (content.contains('class MainRepository') &&
        content.contains('Dio(') &&
        content.contains('_setupDio')) {
      return _relPath(projectDir, file.path);
    }
  }
  for (final file in _dartFilesUnder(Directory('$projectDir/lib'))) {
    final content = file.readAsStringSync();
    if (file.path.contains('main_repository') && content.contains('Dio(')) {
      return _relPath(projectDir, file.path);
    }
  }
  return null;
}

bool pubspecHasDesignSystem(String pubspecContent) {
  return pubspecContent.contains('transtrack_design_system');
}

String _relPath(String projectDir, String filePath) {
  final norm = projectDir.endsWith('/')
      ? projectDir.substring(0, projectDir.length - 1)
      : projectDir;
  if (filePath.startsWith('$norm/')) {
    return filePath.substring(norm.length + 1);
  }
  return filePath;
}

BugSessionProjectScan scanProject({
  required String projectDir,
  required String pubspecContent,
  String? routerDir,
}) {
  final main = resolveMainFile(projectDir);
  if (main == null) {
    throw StateError('No main_development.dart, main_staging.dart, or main.dart');
  }
  final app = resolveAppFile(projectDir);
  final router = scanRouter(projectDir: projectDir, routerDir: routerDir);
  return BugSessionProjectScan(
    mainFile: main,
    appFile: app,
    router: router,
    accessTokenKey: scanAccessTokenKey(projectDir),
    dioSetupFile: scanDioSetupFile(projectDir),
    hasDesignSystem: pubspecHasDesignSystem(pubspecContent),
  );
}
