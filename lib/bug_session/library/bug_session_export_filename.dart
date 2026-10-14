/// Sanitizes [displayName] for use in export zip filenames.
String bugSessionExportNameSlug(String displayName) {
  var slug = displayName.trim();
  slug = slug.replaceAll(RegExp(r'[/\\:\0]'), '-');
  slug = slug.replaceAll(RegExp(r'\s+'), ' ');
  if (slug.length > 80) {
    slug = slug.substring(0, 80).trimRight();
  }
  if (slug.isEmpty) {
    return 'session';
  }
  return slug;
}

/// Builds export zip basename: `{displayName}_BugSesh.zip`.
///
/// When [disambiguateSuffix] is set (e.g. last 8 chars of session id), produces
/// `{displayName}-{suffix}_BugSesh.zip`.
String bugSessionExportZipBasename({
  required String sessionId,
  required String displayName,
  required DateTime startedAt,
  String? disambiguateSuffix,
}) {
  final slug = bugSessionExportNameSlug(displayName);
  if (disambiguateSuffix != null && disambiguateSuffix.isNotEmpty) {
    return '$slug-${disambiguateSuffix}_BugSesh.zip';
  }
  return '${slug}_BugSesh.zip';
}
