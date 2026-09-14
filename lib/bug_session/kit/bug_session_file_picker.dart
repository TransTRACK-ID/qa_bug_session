import 'dart:typed_data';

/// Host-injectable zip picker (keeps `file_picker` optional at app level).
abstract interface class BugSessionFilePicker {
  Future<Uint8List?> pickBugSessionZip();
}
