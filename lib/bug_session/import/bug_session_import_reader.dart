import 'dart:typed_data';

import '../models/bug_session.dart';
import '../serialization/bug_session_serializer.dart';

class BugSessionImportReader {
  BugSessionImportReader({BugSessionSerializer? serializer})
      : _serializer = serializer ?? BugSessionSerializer();

  final BugSessionSerializer _serializer;

  BugSession fromZipBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw FormatException('Empty BugSession archive');
    }
    return _serializer.fromZipBytes(bytes);
  }
}
