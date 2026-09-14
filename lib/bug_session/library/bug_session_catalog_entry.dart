import 'package:meta/meta.dart';

enum BugSessionCatalogSource {
  recorded,
  exported,
  imported,
}

/// Metadata row in `index.json` — never includes access tokens.
@immutable
class BugSessionCatalogEntry {
  const BugSessionCatalogEntry({
    required this.sessionId,
    required this.displayName,
    required this.source,
    this.filePath,
    required this.startedAt,
    this.stoppedAt,
    required this.actionCount,
    required this.appVersion,
    required this.buildNumber,
    this.environment,
    this.userDisplayHint,
    this.videoSidecarPath,
  });

  final String sessionId;
  final String displayName;
  final BugSessionCatalogSource source;
  final String? filePath;
  final String? videoSidecarPath;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final int actionCount;
  final String appVersion;
  final String buildNumber;
  final String? environment;
  final String? userDisplayHint;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'displayName': displayName,
        'source': source.name,
        if (filePath != null) 'filePath': filePath,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (stoppedAt != null)
          'stoppedAt': stoppedAt!.toUtc().toIso8601String(),
        'actionCount': actionCount,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        if (environment != null) 'environment': environment,
        if (userDisplayHint != null) 'userDisplayHint': userDisplayHint,
        if (videoSidecarPath != null) 'videoSidecarPath': videoSidecarPath,
      };

  factory BugSessionCatalogEntry.fromJson(Map<String, Object?> json) {
    return BugSessionCatalogEntry(
      sessionId: json['sessionId'] as String,
      displayName: json['displayName'] as String,
      source: BugSessionCatalogSource.values.byName(json['source'] as String),
      filePath: json['filePath'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] != null
          ? DateTime.parse(json['stoppedAt'] as String)
          : null,
      actionCount: json['actionCount'] as int,
      appVersion: json['appVersion'] as String,
      buildNumber: json['buildNumber'] as String,
      environment: json['environment'] as String?,
      userDisplayHint: json['userDisplayHint'] as String?,
      videoSidecarPath: json['videoSidecarPath'] as String?,
    );
  }

  BugSessionCatalogEntry copyWith({
    String? displayName,
    BugSessionCatalogSource? source,
    String? filePath,
    String? videoSidecarPath,
    bool clearFilePath = false,
  }) {
    return BugSessionCatalogEntry(
      sessionId: sessionId,
      displayName: displayName ?? this.displayName,
      source: source ?? this.source,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      actionCount: actionCount,
      appVersion: appVersion,
      buildNumber: buildNumber,
      environment: environment,
      userDisplayHint: userDisplayHint,
      videoSidecarPath: videoSidecarPath ?? this.videoSidecarPath,
    );
  }
}

String defaultBugSessionDisplayName({
  required DateTime startedAt,
  required int actionCount,
}) {
  final local = startedAt.toLocal();
  final stamp =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$stamp · $actionCount action${actionCount == 1 ? '' : 's'}';
}
