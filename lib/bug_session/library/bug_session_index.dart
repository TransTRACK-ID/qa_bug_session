import 'bug_session_catalog_entry.dart';

/// On-disk catalog index (`index.json`).
class BugSessionIndex {
  const BugSessionIndex({
    required this.entries,
    this.lastSessionId,
    this.version = 2,
  });

  final int version;
  final String? lastSessionId;
  final List<BugSessionCatalogEntry> entries;

  Map<String, Object?> toJson() => {
        'version': version,
        if (lastSessionId != null) 'lastSessionId': lastSessionId,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static BugSessionIndex fromJson(Map<String, Object?> map) {
    final version = map['version'];
    final entriesRaw = map['entries'];
    final entries = entriesRaw is List
        ? entriesRaw
            .map(
              (e) => BugSessionCatalogEntry.fromJson(
                Map<String, Object?>.from(e as Map),
              ),
            )
            .toList()
        : <BugSessionCatalogEntry>[];
    final lastSessionId = map['lastSessionId'] as String?;
    return BugSessionIndex(
      version: version is int ? version : 1,
      lastSessionId: lastSessionId,
      entries: entries,
    );
  }
}
