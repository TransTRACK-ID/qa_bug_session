/// Builds a human-readable export zip name from QA [displayName].
String bugSessionExportZipBasename({
  required String sessionId,
  required String displayName,
  required DateTime startedAt,
}) {
  var slug = displayName.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '-',
      );
  slug = slug.replaceAll(RegExp(r'-+'), '-');
  slug = slug.replaceAll(RegExp(r'^-|-$'), '');
  if (slug.isEmpty) {
    slug = 'session';
  } else if (slug.length > 48) {
    slug = slug.substring(0, 48);
  }

  final local = startedAt.toLocal();
  final date =
      '${local.year}${local.month.toString().padLeft(2, '0')}${local.day.toString().padLeft(2, '0')}';
  final tail = sessionId.length > 12
      ? sessionId.substring(sessionId.length - 12)
      : sessionId;
  return 'bug-session-$slug-$date-$tail.zip';
}
