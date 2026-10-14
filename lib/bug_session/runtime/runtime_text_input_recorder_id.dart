/// Stable recorder id for text fields when codegen registry is not used.
String runtimeTextInputRecorderId({
  required String routeKey,
  required String fieldLabel,
  String packagePrefix = 'mobile_technician',
}) {
  final routePart = _slug(routeKey);
  final fieldPart = _slug(fieldLabel);
  return '$packagePrefix.$routePart.input.$fieldPart';
}

String _slug(String raw) {
  var s = raw.trim();
  if (s.endsWith('Route')) {
    s = s.substring(0, s.length - 5);
  }
  final spaced = s
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('/', ' ')
      .replaceAll('|', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  return spaced.replaceAll(' ', '_');
}
