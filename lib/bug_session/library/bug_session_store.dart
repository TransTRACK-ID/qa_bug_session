import 'dart:convert';
import 'dart:io';

import 'bug_session_catalog_entry.dart';
import 'bug_session_index.dart';

/// Default layout: `{root}/index.json`, `{root}/sessions/{sessionId}.zip`.
class BugSessionStore {
  BugSessionStore(this.root);

  final Directory root;

  Directory get sessionsDir => Directory('${root.path}/sessions');

  Directory get videosDir => Directory('${root.path}/videos');

  File get indexFile => File('${root.path}/index.json');

  Future<void> ensureLayout() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }
  }

  Future<BugSessionIndex> readIndexFile() async {
    await ensureLayout();
    if (!await indexFile.exists()) {
      return const BugSessionIndex(entries: []);
    }
    try {
      final map = jsonDecode(await indexFile.readAsString()) as Map;
      return BugSessionIndex.fromJson(Map<String, Object?>.from(map));
    } catch (_) {
      return const BugSessionIndex(entries: []);
    }
  }

  Future<List<BugSessionCatalogEntry>> readIndex() async {
    return (await readIndexFile()).entries;
  }

  Future<void> writeIndex(
    List<BugSessionCatalogEntry> entries, {
    String? lastSessionId,
  }) async {
    await ensureLayout();
    final payload = BugSessionIndex(
      entries: entries,
      lastSessionId: lastSessionId,
    );
    await indexFile.writeAsString(jsonEncode(payload.toJson()));
  }

  File sessionZipFile(String sessionId) =>
      File('${sessionsDir.path}/$sessionId.zip');

  File exportZipFile(String basename) => File('${sessionsDir.path}/$basename');

  File sessionVideoSidecarFile(
    String sessionId, {
    String extension = 'mp4',
  }) =>
      File('${videosDir.path}/$sessionId.$extension');
}
