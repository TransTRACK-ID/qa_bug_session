import 'dart:convert';

import 'package:archive/archive.dart';

import '../models/bug_session.dart';
import '../runtime/timeline_builder.dart';
import '../runtime/timeline_presenter.dart';
import 'bug_session_parser.dart';

class BugSessionSerializer {
  List<int> toZipBytes(
    BugSession session, {
    Map<String, List<int>> binaryFiles = const {},
  }) {
    final archive = Archive();

    void addJsonFile(String name, Object jsonObject) {
      archive.addFile(
        ArchiveFile.bytes(name, utf8.encode(jsonEncode(jsonObject))),
      );
    }

    addJsonFile('manifest.json', session.toArchiveManifestJson());
    addJsonFile(
      'actions.json',
      {'actions': session.actions.map((a) => a.toJson()).toList()},
    );
    addJsonFile(
      'network.json',
      {'events': session.networkEvents.map((e) => e.toJson()).toList()},
    );
    addJsonFile(
      'diagnostics.json',
      {'diagnostics': session.diagnostics.map((d) => d.toJson()).toList()},
    );
    final timeline = TimelineBuilder().build(
      actions: session.actions,
      networkEvents: session.networkEvents,
      diagnostics: session.diagnostics,
      visualFrames: session.visualEvidence,
    );
    final timelineJson = {
      'entries': timeline
          .map(
            (e) => {
              'timestampMs': e.timestampMs,
              'clock': e.formatClock(),
              'label': e.label,
              'detail': e.detail,
            },
          )
          .toList(),
    };
    addJsonFile('timeline.json', timelineJson);
    addJsonFile('what_happened.json', timelineJson);

    final presenter = TimelinePresenter();
    final markdown = StringBuffer('# What happened\n\n');
    for (final entry in timeline) {
      markdown.writeln(presenter.formatLine(entry));
    }
    archive.addFile(ArchiveFile.string('what_happened.md', markdown.toString()));

    if (session.visualEvidence.isNotEmpty) {
      addJsonFile(
        'visual_evidence.json',
        {
          'frames': session.visualEvidence.map((f) => f.toJson()).toList(),
        },
      );
    }
    for (final entry in binaryFiles.entries) {
      final bytes = entry.value;
      final name = entry.key;
      final lower = name.toLowerCase();
      if (lower.endsWith('.mp4') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.png')) {
        archive.addFile(ArchiveFile.noCompress(name, bytes.length, bytes));
      } else {
        archive.addFile(ArchiveFile.bytes(name, bytes));
      }
    }

    return ZipEncoder().encode(archive)!;
  }

  BugSession fromZipBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String readJson(String name) {
      final file = archive.findFile(name);
      if (file == null) {
        throw FormatException('BugSession archive missing $name');
      }
      return utf8.decode(file.content as List<int>);
    }

    String? visualJson;
    try {
      visualJson = readJson('visual_evidence.json');
    } catch (_) {
      visualJson = null;
    }

    return BugSessionArchiveParser().parseParts(
      manifestJson: readJson('manifest.json'),
      actionsJson: readJson('actions.json'),
      networkJson: readJson('network.json'),
      diagnosticsJson: readJson('diagnostics.json'),
      visualEvidenceJson: visualJson,
    );
  }
}
