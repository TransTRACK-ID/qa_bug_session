import 'dart:io';
import 'dart:typed_data';

import '../models/bug_session.dart';
import '../serialization/bug_session_serializer.dart';

class BugSessionExportWriter {
  BugSessionExportWriter({BugSessionSerializer? serializer})
      : _serializer = serializer ?? BugSessionSerializer();

  final BugSessionSerializer _serializer;

  Uint8List toZipBytes(BugSession session) =>
      Uint8List.fromList(_serializer.toZipBytes(session));

  Future<File> writeToFile({
    required BugSession session,
    required File destination,
    Map<String, List<int>> binaryFiles = const {},
  }) async {
    final bytes = _serializer.toZipBytes(session, binaryFiles: binaryFiles);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    return destination;
  }
}
