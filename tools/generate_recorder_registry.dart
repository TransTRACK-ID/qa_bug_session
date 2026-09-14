// @dart=3.12
// ignore_for_file: avoid_print
//
// Scans a Flutter app for tappable widgets and generates BugSession registry
// lookup + optional BsAppButton codemod.
//
// Usage (from any Flutter project root):
//   dart run ../qa_bug_session/tools/generate_recorder_registry.dart \
//     --project-dir . \
//     --output lib/generated/bug_session_recorder_registry.g.dart
//
//   dart run ../qa_bug_session/tools/generate_recorder_registry.dart \
//     --project-dir . --apply-bs-app-button
//
import 'dart:io';

void main(List<String> args) {
  final options = _parseArgs(args);
  final projectDir = Directory(options.projectDir);
  if (!projectDir.existsSync()) {
    stderr.writeln('Project dir not found: ${options.projectDir}');
    exitCode = 1;
    return;
  }

  final pubspec = File('${options.projectDir}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in ${options.projectDir}');
    exitCode = 1;
    return;
  }

  final packageName = options.packageName ?? _readPackageName(pubspec.readAsStringSync());
  final libRoot = Directory('${options.projectDir}/${options.libDir}');
  if (!libRoot.existsSync()) {
    stderr.writeln('lib dir not found: ${libRoot.path}');
    exitCode = 1;
    return;
  }

  final targets = <_Target>[];
  for (final entity in libRoot.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.contains('.g.dart') ||
        entity.path.contains('.gr.dart') ||
        entity.path.contains('bug_session_recorder_registry.g.dart')) {
      continue;
    }
    final content = entity.readAsStringSync();
    targets.addAll(_scanFile(
      filePath: entity.path,
      content: content,
      packageName: packageName,
      projectDir: options.projectDir,
    ));
  }

  targets.sort((a, b) => a.id.compareTo(b.id));
  final unique = <String, _Target>{};
  for (final t in targets) {
    unique.putIfAbsent(t.id, () => t);
  }
  final list = unique.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  final outputFile = File('${options.projectDir}/${options.output}');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(_generateDart(packageName, list));
  print('Wrote ${list.length} targets → ${outputFile.path}');

  if (options.applyBsAppButton) {
    var filesChanged = 0;
    for (final entity in libRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.contains('.g.dart') || entity.path.contains('.gr.dart')) {
        continue;
      }
      final original = entity.readAsStringSync();
      final updated = _applyBsAppButton(
        original,
        entity.path,
        packageName: packageName,
      );
      if (updated != original) {
        entity.writeAsStringSync(updated);
        filesChanged++;
      }
    }
    print('BsAppButton apply: updated $filesChanged files');
  }
}

class _Options {
  _Options({
    required this.projectDir,
    required this.libDir,
    required this.output,
    required this.packageName,
    required this.applyBsAppButton,
  });

  final String projectDir;
  final String libDir;
  final String output;
  final String? packageName;
  final bool applyBsAppButton;
}

_Options _parseArgs(List<String> args) {
  var projectDir = '.';
  var libDir = 'lib';
  var output = 'lib/generated/bug_session_recorder_registry.g.dart';
  String? packageName;
  var apply = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project-dir':
        projectDir = args[++i];
      case '--lib-dir':
        libDir = args[++i];
      case '--output':
        output = args[++i];
      case '--package-name':
        packageName = args[++i];
      case '--apply-bs-app-button':
        apply = true;
      case '--help':
        print(_help);
        exit(0);
    }
  }

  return _Options(
    projectDir: projectDir,
    libDir: libDir,
    output: output,
    packageName: packageName,
    applyBsAppButton: apply,
  );
}

const _help = '''
generate_recorder_registry.dart — BugSession tap target codegen

  --project-dir PATH     Flutter app root (default: .)
  --lib-dir PATH         Source root under project (default: lib)
  --output PATH          Generated Dart file path
  --package-name NAME    Override pubspec name
  --apply-bs-app-button  Replace AppButton. with BsAppButton. + import
''';

class _Target {
  _Target({
    required this.id,
    required this.label,
    required this.filePath,
    required this.routeHint,
    required this.kind,
  });

  final String id;
  final String label;
  final String filePath;
  final String routeHint;
  final String kind;
}

String _readPackageName(String pubspec) {
  final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (match == null) {
    return 'app';
  }
  return match.group(1)!;
}

List<_Target> _scanFile({
  required String filePath,
  required String content,
  required String packageName,
  required String projectDir,
}) {
  final rel = filePath.startsWith(projectDir)
      ? filePath.substring(projectDir.length + 1)
      : filePath;
  final routeHint = _routeHintFromPath(rel);
  final module = _moduleFromPath(rel);
  final out = <_Target>[];

  void add(String kind, String label) {
    if (label.isEmpty || label == 'tap') {
      return;
    }
    if (label.contains(r'$')) {
      return;
    }
    final id = _registryId(
      packageName: packageName,
      module: module,
      label: label,
      kind: kind,
    );
    out.add(
      _Target(
        id: id,
        label: label,
        filePath: rel,
        routeHint: routeHint,
        kind: kind,
      ),
    );
  }

  for (final match in RegExp(
    r'AppButton\.(\w+)\(',
  ).allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    final label = _extractStringParam(block, 'label');
    if (label != null) {
      add('AppButton.${match.group(1)}', label);
    }
  }

  for (final match in RegExp(
    r'(FilledButton|ElevatedButton|OutlinedButton|TextButton)\(',
  ).allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    final label = _extractStringParam(block, 'label') ??
        _childTextLiteral(block);
    if (label != null) {
      add(match.group(1)!, label);
    }
  }

  for (final match in RegExp(r'IconButton\s*\(').allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    final label = _extractStringParam(block, 'tooltip') ??
        _extractStringParam(block, 'semanticLabel');
    if (label != null) {
      add('IconButton', label);
    }
  }

  for (final match in RegExp(r'ListTile\s*\(').allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    final label = _extractStringParam(block, 'title');
    if (label != null) {
      add('ListTile', label);
    }
  }

  for (final match in RegExp(r'InkWell\s*\(').allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    if (!block.contains('onTap')) {
      continue;
    }
    final label = _extractStringParam(block, 'semanticLabel');
    if (label != null) {
      add('InkWell', label);
    }
  }

  for (final match in RegExp(r'GestureDetector\s*\(').allMatches(content)) {
    final block = _readParenBlock(content, match.end - 1);
    if (!block.contains('onTap')) {
      continue;
    }
    final label = _extractStringParam(block, 'semanticLabel');
    if (label != null) {
      add('GestureDetector', label);
    }
  }

  return out;
}

String _moduleFromPath(String relPath) {
  final parts = relPath.split('/');
  if (parts.contains('modules') && parts.length > 2) {
    final idx = parts.indexOf('modules');
    if (idx + 1 < parts.length) {
      return parts[idx + 1];
    }
  }
  if (parts.length >= 2 && parts[0] == 'lib') {
    return parts[1];
  }
  return 'app';
}

String _routeHintFromPath(String relPath) {
  final module = _moduleFromPath(relPath);
  if (module == 'app') {
    return '';
  }
  final words = module.split('_');
  final route = words.map((w) {
    if (w.isEmpty) {
      return w;
    }
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }).join();
  return '${route}Route';
}

String _registryId({
  required String packageName,
  required String module,
  required String label,
  required String kind,
}) {
  final slug = _slug(label);
  final kindSlug = _slug(kind.replaceAll('.', '_'));
  if (kindSlug.isEmpty || kindSlug == slug) {
    return '$packageName.$module.$slug';
  }
  return '$packageName.$module.$kindSlug.$slug';
}

String _slug(String input) {
  final lower = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return lower.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}

String _readParenBlock(String content, int openParenIndex) {
  if (openParenIndex < 0 || openParenIndex >= content.length) {
    return '';
  }
  var depth = 0;
  final buffer = StringBuffer();
  for (var i = openParenIndex; i < content.length; i++) {
    final ch = content[i];
    if (ch == '(') {
      depth++;
    }
    if (depth > 0) {
      buffer.write(ch);
    }
    if (ch == ')') {
      depth--;
      if (depth == 0) {
        break;
      }
    }
  }
  return buffer.toString();
}

String? _extractStringParam(String block, String name) {
  final match = RegExp(
    '$name\\s*:\\s*([\'"])(.*?)(?<!\\\\)\\1',
    dotAll: true,
  ).firstMatch(block);
  return match?.group(2);
}

String? _childTextLiteral(String block) {
  final single = RegExp(
    r"child\s*:\s*(?:const\s+)?Text\s*\(\s*'([^']*)'",
    dotAll: true,
  ).firstMatch(block);
  if (single != null) {
    return single.group(1);
  }
  final double = RegExp(
    r'child\s*:\s*(?:const\s+)?Text\s*\(\s*"([^"]*)"',
    dotAll: true,
  ).firstMatch(block);
  return double?.group(1);
}

String _generateDart(String packageName, List<_Target> targets) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED by qa_bug_session/tools/generate_recorder_registry.dart')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("import 'package:qa_bug_session/qa_bug_session.dart';")
    ..writeln()
    ..writeln('/// Semantic ids for [RecorderTap] / replay registry lookup.')
    ..writeln('abstract final class BugSessionRecorderIds {');
  for (final t in targets) {
    final field = _uniqueFieldName(t, targets);
    buffer.writeln("  static const $field = '${t.id}';");
  }
  buffer
    ..writeln('}')
    ..writeln()
    ..writeln('/// Maps recorded route/label pairs to registry ids.')
    ..writeln('String? resolveBugSessionRecorderTargetId(RecordedAction action) {')
    ..writeln('  final metaId = action.metadata[\'recorderId\'];')
    ..writeln('  if (metaId is String && metaId.isNotEmpty) {')
    ..writeln('    return metaId;')
    ..writeln('  }')
    ..writeln('  final target = action.target;')
    ..writeln('  if (target == null || !target.contains(\'/\')) {')
    ..writeln('    return null;')
    ..writeln('  }')
    ..writeln('  final slash = target.lastIndexOf(\'/\');')
    ..writeln('  final route = target.substring(0, slash);')
    ..writeln('  final label = target.substring(slash + 1);')
    ..writeln('  return _byRouteLabel[\'\$route|\$label\'];')
    ..writeln('}')
    ..writeln()
    ..writeln('String? bugSessionRecorderIdForLabel(String label) {')
    ..writeln('  return _byRouteLabel[\'*|\$label\'];')
    ..writeln('}')
    ..writeln()
    ..writeln('const _byRouteLabel = <String, String>{');
  final mapKeys = <String>{};
  for (final t in targets) {
    final route = t.routeHint.isEmpty ? '*' : t.routeHint;
    final field = _uniqueFieldName(t, targets);
    final keys = <String>[
      if (route != '*') '$route|${t.label}',
      '*|${t.label}',
    ];
    for (final key in keys) {
      if (!mapKeys.add(key)) {
        continue;
      }
      buffer.writeln(
        '  ${_dartQuote(key)}: BugSessionRecorderIds.$field,',
      );
    }
  }
  buffer.writeln('};');
  return buffer.toString();
}

String _dartQuote(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}

String _uniqueFieldName(_Target t, List<_Target> all) {
  final base = _fieldName(t.id);
  final sameId = all.where((o) => o.id == t.id).length;
  if (sameId <= 1) {
    return base;
  }
  final kindSlug = _slug(t.kind.replaceAll('.', '_'));
  return '${base}_$kindSlug';
}

String _fieldName(String id) {
  final tail = id.split('.').skip(1).join('_');
  var name = _slug(tail).replaceAll('_', ' ');
  name = name.split(' ').map((w) {
    if (w.isEmpty) {
      return w;
    }
    return w[0].toUpperCase() + w.substring(1);
  }).join();
  if (name.isEmpty) {
    name = 'Target';
  }
  if (RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'k$name';
  }
  return name;
}

String _applyBsAppButton(
  String content,
  String filePath, {
  required String packageName,
}) {
  if (!content.contains('AppButton.') || content.contains('BsAppButton.')) {
    return content;
  }
  if (filePath.contains('bs_app_button.dart')) {
    return content;
  }

  var updated = content.replaceAllMapped(
    RegExp(r'AppButton\.(\w+)\('),
    (m) => 'BsAppButton.${m.group(1)}(',
  );

  final importLine =
      "import 'package:$packageName/widgets/bs_app_button.dart';\n";
  if (!updated.contains('bs_app_button.dart')) {
    if (updated.contains("import 'package:")) {
      final firstImport = RegExp(r"import 'package:[^']+';").firstMatch(updated);
      if (firstImport != null) {
        updated = updated.replaceRange(
          firstImport.end,
          firstImport.end,
          '\n$importLine',
        );
      } else {
        updated = '$importLine$updated';
      }
    } else {
      updated = '$importLine$updated';
    }
  }

  // Drop duplicate transtrack AppButton import if only used via BsAppButton — keep it (BsAppButton re-exports usage internally)

  return updated;
}
