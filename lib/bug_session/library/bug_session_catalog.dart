import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../export/bug_session_export_writer.dart';
import '../import/bug_session_import_reader.dart';
import '../models/bug_session.dart';
import '../recording/bug_session_recorder.dart';
import '../models/visual_evidence_frame.dart';
import 'bug_session_catalog_entry.dart';
import 'bug_session_export_filename.dart';
import 'bug_session_store.dart';

abstract interface class BugSessionCatalog {
  Stream<List<BugSessionCatalogEntry>> watchEntries();

  Future<List<BugSessionCatalogEntry>> listEntries();

  Future<BugSessionCatalogEntry> addFromStoppedSession(
    BugSession session, {
    Map<String, List<int>> visualArchiveFiles,
    String? displayName,
  });

  Future<BugSessionCatalogEntry> renameSession(
    String sessionId,
    String displayName,
  );

  Future<BugSessionCatalogEntry> importFromZipBytes(
    Uint8List bytes, {
    String? suggestedName,
  });

  Future<BugSessionCatalogEntry> exportSessionToDisk(String sessionId);

  Future<BugSession> loadSession(String sessionId);

  Future<void> delete(String sessionId);

  Future<void> clearAll();

  Future<bool> containsSession(String sessionId);

  Future<String?> getLastSessionId();

  Future<void> restoreRecorderLastSession(BugSessionRecorder recorder);
}

class FileBugSessionCatalog implements BugSessionCatalog {
  FileBugSessionCatalog({
    required BugSessionStore store,
    BugSessionExportWriter? exportWriter,
    BugSessionImportReader? importReader,
  })  : _store = store,
        _exportWriter = exportWriter ?? BugSessionExportWriter(),
        _importReader = importReader ?? BugSessionImportReader();

  final BugSessionStore _store;
  final BugSessionExportWriter _exportWriter;
  final BugSessionImportReader _importReader;

  final _entriesController =
      StreamController<List<BugSessionCatalogEntry>>.broadcast();

  List<BugSessionCatalogEntry> _entries = [];
  String? _lastSessionId;
  final Map<String, BugSession> _memorySessions = {};
  final Map<String, Map<String, List<int>>> _visualArchiveBySession = {};
  bool _loaded = false;

  BugSession _mergeVisualArchiveIntoSession(
    BugSession session,
    Map<String, List<int>> visualArchiveFiles,
  ) {
    if (visualArchiveFiles.isEmpty) {
      return session;
    }
    final existing = session.visualEvidence.map((f) => f.archivePath).toSet();
    final added = <VisualEvidenceFrame>[
      for (final path in visualArchiveFiles.keys)
        if (!existing.contains(path))
          VisualEvidenceFrame(timestampMs: 0, archivePath: path),
    ];
    if (added.isEmpty) {
      return session;
    }
    return BugSession(
      formatVersion: session.formatVersion,
      manifest: session.manifest,
      actions: session.actions,
      networkEvents: session.networkEvents,
      diagnostics: session.diagnostics,
      visualEvidence: [...session.visualEvidence, ...added],
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final index = await _store.readIndexFile();
    _entries = List<BugSessionCatalogEntry>.from(index.entries);
    _lastSessionId = index.lastSessionId;
    _loaded = true;
    _emit();
  }

  Future<void> _writeIndex() async {
    await _store.writeIndex(_entries, lastSessionId: _lastSessionId);
  }

  Future<void> _markLastSession(String sessionId) async {
    _lastSessionId = sessionId;
  }

  Future<void> _persistSessionArchive(
    BugSession session,
    Map<String, List<int>> visualArchiveFiles,
  ) async {
    await _store.ensureLayout();
    final zip = _store.sessionZipFile(session.manifest.sessionId);
    await _exportWriter.writeToFile(
      session: session,
      destination: zip,
      binaryFiles: visualArchiveFiles,
    );
  }

  void _emit() {
    if (!_entriesController.isClosed) {
      _entriesController.add(List.unmodifiable(_entries));
    }
  }

  @override
  Stream<List<BugSessionCatalogEntry>> watchEntries() {
    return Stream.multi((controller) async {
      await _ensureLoaded();
      controller.add(List.unmodifiable(_entries));
      final sub = _entriesController.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<BugSessionCatalogEntry>> listEntries() async {
    await _ensureLoaded();
    return List.unmodifiable(_entries);
  }

  BugSessionCatalogEntry _entryFromSession(
    BugSession session, {
    required BugSessionCatalogSource source,
    String? filePath,
    String? displayName,
  }) {
    final manifest = session.manifest;
    return BugSessionCatalogEntry(
      sessionId: manifest.sessionId,
      displayName: displayName ??
          defaultBugSessionDisplayName(
            startedAt: manifest.startedAt,
            actionCount: session.actions.length,
          ),
      source: source,
      filePath: filePath,
      startedAt: manifest.startedAt,
      stoppedAt: manifest.stoppedAt,
      actionCount: session.actions.length,
      appVersion: manifest.appVersion,
      buildNumber: manifest.buildNumber,
      environment: manifest.environment,
      userDisplayHint: manifest.user.displayHint,
    );
  }

  @override
  Future<BugSessionCatalogEntry> addFromStoppedSession(
    BugSession session, {
    Map<String, List<int>> visualArchiveFiles = const {},
    String? displayName,
  }) async {
    await _ensureLoaded();
    final id = session.manifest.sessionId;
    final stored = _mergeVisualArchiveIntoSession(session, visualArchiveFiles);
    _memorySessions[id] = stored;
    if (visualArchiveFiles.isNotEmpty) {
      _visualArchiveBySession[id] = visualArchiveFiles;
    }
    final videoSidecarPath =
        await _persistVideoSidecar(id, visualArchiveFiles);
    _entries.removeWhere((e) => e.sessionId == id);
    final entry = _entryFromSession(
      stored,
      source: BugSessionCatalogSource.recorded,
      displayName: displayName,
    ).copyWith(videoSidecarPath: videoSidecarPath);
    _entries.insert(0, entry);
    await _persistSessionArchive(stored, visualArchiveFiles);
    await _markLastSession(id);
    await _writeIndex();
    _emit();
    return entry;
  }

  @override
  Future<BugSessionCatalogEntry> renameSession(
    String sessionId,
    String displayName,
  ) async {
    await _ensureLoaded();
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }
    final index = _entries.indexWhere((e) => e.sessionId == sessionId);
    if (index < 0) {
      throw StateError('Unknown session $sessionId');
    }
    var entry = _entries[index].copyWith(displayName: trimmed);
    entry = await _reconcileExportZipName(entry);
    _entries[index] = entry;
    await _writeIndex();
    _emit();
    return _entries[index];
  }

  Future<BugSessionCatalogEntry> _reconcileExportZipName(
    BugSessionCatalogEntry entry,
  ) async {
    final oldPath = entry.filePath;
    if (oldPath == null) {
      return entry;
    }
    final basename = bugSessionExportZipBasename(
      sessionId: entry.sessionId,
      displayName: entry.displayName,
      startedAt: entry.startedAt,
    );
    final newFile = _store.exportZipFile(basename);
    if (newFile.path == oldPath) {
      return entry;
    }
    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      if (await newFile.exists()) {
        await newFile.delete();
      }
      await oldFile.rename(newFile.path);
    }
    return entry.copyWith(filePath: newFile.path);
  }

  Future<String?> _persistVideoSidecar(
    String sessionId,
    Map<String, List<int>> visualArchiveFiles,
  ) async {
    List<int>? bytes;
    var ext = 'gif';
    for (final entry in visualArchiveFiles.entries) {
      final path = entry.key.toLowerCase();
      if (path.endsWith('.gif') || path.endsWith('.mp4')) {
        bytes = entry.value;
        ext = path.endsWith('.mp4') ? 'mp4' : 'gif';
        break;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    await _store.ensureLayout();
    final file = _store.sessionVideoSidecarFile(sessionId, extension: ext);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<BugSessionCatalogEntry> importFromZipBytes(
    Uint8List bytes, {
    String? suggestedName,
  }) async {
    await _ensureLoaded();
    final session = _importReader.fromZipBytes(bytes);
    final id = session.manifest.sessionId;
    final displayName = suggestedName ??
        defaultBugSessionDisplayName(
          startedAt: session.manifest.startedAt,
          actionCount: session.actions.length,
        );
    final basename = bugSessionExportZipBasename(
      sessionId: id,
      displayName: displayName,
      startedAt: session.manifest.startedAt,
    );
    final zipFile = _store.exportZipFile(basename);
    final visualFiles = await _visualFilesFromZipBytes(bytes);
    await _exportWriter.writeToFile(
      session: session,
      destination: zipFile,
      binaryFiles: visualFiles,
    );

    _memorySessions[id] = session;
    _entries.removeWhere((e) => e.sessionId == id);
    final videoSidecarPath = await _persistVideoSidecar(id, visualFiles);
    final entry = _entryFromSession(
      session,
      source: BugSessionCatalogSource.imported,
      filePath: zipFile.path,
      displayName: displayName,
    ).copyWith(videoSidecarPath: videoSidecarPath);
    _entries.insert(0, entry);
    await _markLastSession(id);
    await _writeIndex();
    _emit();
    return entry;
  }

  @override
  Future<BugSessionCatalogEntry> exportSessionToDisk(String sessionId) async {
    await _ensureLoaded();
    final session = await loadSession(sessionId);
    final index = _entries.indexWhere((e) => e.sessionId == sessionId);
    if (index < 0) {
      throw StateError('Unknown session $sessionId');
    }
    final entry = _entries[index];
    final basename = bugSessionExportZipBasename(
      sessionId: sessionId,
      displayName: entry.displayName,
      startedAt: entry.startedAt,
    );
    final zipFile = _store.exportZipFile(basename);
    final oldPath = entry.filePath;
    if (oldPath != null && oldPath != zipFile.path) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }
    final binaryFiles = await _exportBinaryFiles(sessionId, entry);
    await _exportWriter.writeToFile(
      session: session,
      destination: zipFile,
      binaryFiles: binaryFiles,
    );

    var updated = entry.copyWith(
      filePath: zipFile.path,
      source: entry.source == BugSessionCatalogSource.imported
          ? BugSessionCatalogSource.imported
          : BugSessionCatalogSource.exported,
    );
    if (updated.videoSidecarPath == null && binaryFiles.isNotEmpty) {
      final sidecar =
          await _persistVideoSidecar(sessionId, binaryFiles);
      if (sidecar != null) {
        updated = updated.copyWith(videoSidecarPath: sidecar);
      }
    }
    _entries[index] = updated;
    await _writeIndex();
    _emit();
    return updated;
  }

  Future<Map<String, List<int>>> _exportBinaryFiles(
    String sessionId,
    BugSessionCatalogEntry entry,
  ) async {
    final memory = _visualArchiveBySession[sessionId];
    if (memory != null && memory.isNotEmpty) {
      return memory.map((key, value) => MapEntry(key, value));
    }
    final sidecar = entry.videoSidecarPath;
    if (sidecar != null) {
      final file = File(sidecar);
      if (await file.exists()) {
        final lower = sidecar.toLowerCase();
        if (lower.endsWith('.mp4')) {
          return {'visual/session.mp4': await file.readAsBytes()};
        }
        return {'visual/session.gif': await file.readAsBytes()};
      }
    }
    final path = entry.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        return _visualFilesFromZipBytes(await file.readAsBytes());
      }
    }
    return const {};
  }

  Future<Map<String, List<int>>> _visualFilesFromZipBytes(
    Uint8List bytes,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final map = <String, List<int>>{};
    for (final file in archive.files) {
      final name = file.name;
      if (name.startsWith('visual/') && file.content is List<int>) {
        map[name] = List<int>.from(file.content as List<int>);
      }
    }
    return map;
  }

  @override
  Future<BugSession> loadSession(String sessionId) async {
    await _ensureLoaded();
    final cached = _memorySessions[sessionId];
    if (cached != null) return cached;

    final entry = _findEntry(sessionId);
    if (entry == null) {
      throw StateError('Unknown session $sessionId');
    }

    final catalogZip = _store.sessionZipFile(sessionId);
    if (await catalogZip.exists()) {
      final session =
          _importReader.fromZipBytes(await catalogZip.readAsBytes());
      _memorySessions[sessionId] = session;
      return session;
    }

    final path = entry.filePath;
    if (path == null) {
      throw StateError('Session $sessionId has no on-disk export');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Missing zip for session $sessionId');
    }
    final session = _importReader.fromZipBytes(await file.readAsBytes());
    _memorySessions[sessionId] = session;
    return session;
  }

  @override
  Future<String?> getLastSessionId() async {
    await _ensureLoaded();
    return _lastSessionId;
  }

  @override
  Future<void> restoreRecorderLastSession(BugSessionRecorder recorder) async {
    await _ensureLoaded();
    if (recorder.lastSession != null) {
      return;
    }
    final id = _lastSessionId;
    if (id == null || _findEntry(id) == null) {
      return;
    }
    try {
      final session = await loadSession(id);
      recorder.restoreLastSession(session);
    } catch (_) {
      _lastSessionId = null;
      await _writeIndex();
    }
  }

  @override
  Future<void> delete(String sessionId) async {
    await _ensureLoaded();
    _memorySessions.remove(sessionId);
    _visualArchiveBySession.remove(sessionId);
    final entry = _findEntry(sessionId);
    if (entry?.filePath != null) {
      final file = File(entry!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (entry?.videoSidecarPath != null) {
      final video = File(entry!.videoSidecarPath!);
      if (await video.exists()) {
        await video.delete();
      }
    }
    _entries.removeWhere((e) => e.sessionId == sessionId);
    final catalogZip = _store.sessionZipFile(sessionId);
    if (await catalogZip.exists()) {
      await catalogZip.delete();
    }
    if (_lastSessionId == sessionId) {
      _lastSessionId = _entries.isEmpty ? null : _entries.first.sessionId;
    }
    await _writeIndex();
    _emit();
  }

  @override
  Future<bool> containsSession(String sessionId) async {
    await _ensureLoaded();
    return _findEntry(sessionId) != null;
  }

  @override
  Future<void> clearAll() async {
    await _ensureLoaded();
    for (final entry in _entries) {
      if (entry.filePath != null) {
        final file = File(entry.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      final catalogZip = _store.sessionZipFile(entry.sessionId);
      if (await catalogZip.exists()) {
        await catalogZip.delete();
      }
    }
    _memorySessions.clear();
    _entries = [];
    _lastSessionId = null;
    await _writeIndex();
    _emit();
  }

  Future<void> dispose() async {
    await _entriesController.close();
  }

  BugSessionCatalogEntry? _findEntry(String sessionId) {
    for (final e in _entries) {
      if (e.sessionId == sessionId) return e;
    }
    return null;
  }
}
