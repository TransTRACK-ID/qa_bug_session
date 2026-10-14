import 'package:meta/meta.dart';

import 'bug_session_recording_kind.dart';

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
    this.jamShareUrl,
    this.recordingKind,
  });

  final String sessionId;
  final String displayName;
  final BugSessionCatalogSource source;
  final String? filePath;
  final String? videoSidecarPath;
  final String? jamShareUrl;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final int actionCount;
  final String appVersion;
  final String buildNumber;
  final String? environment;
  final String? userDisplayHint;
  final BugSessionRecordingKind? recordingKind;

  /// User-facing capture label; legacy rows without kind show [savedSessionLabel].
  String get recordingKindLabel =>
      recordingKind?.label ?? savedSessionLabel;

  static const savedSessionLabel = 'Saved session';

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
        if (jamShareUrl != null) 'jamShareUrl': jamShareUrl,
        if (recordingKind != null) 'recordingKind': recordingKind!.name,
      };

  factory BugSessionCatalogEntry.fromJson(Map<String, Object?> json) {
    final source =
        BugSessionCatalogSource.values.byName(json['source'] as String);
    final displayName = json['displayName'] as String;
    return BugSessionCatalogEntry(
      sessionId: json['sessionId'] as String,
      displayName: displayName,
      source: source,
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
      jamShareUrl: json['jamShareUrl'] as String?,
      recordingKind: inferBugSessionRecordingKind(
        displayName: displayName,
        catalogSourceName: source.name,
        recordingKindJson: json['recordingKind'] as String?,
      ),
    );
  }

  BugSessionCatalogEntry copyWith({
    String? displayName,
    BugSessionCatalogSource? source,
    BugSessionRecordingKind? recordingKind,
    String? filePath,
    String? videoSidecarPath,
    String? jamShareUrl,
    bool clearFilePath = false,
    bool clearVideoSidecarPath = false,
    bool clearJamShareUrl = false,
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
      videoSidecarPath: clearVideoSidecarPath
          ? null
          : (videoSidecarPath ?? this.videoSidecarPath),
      jamShareUrl:
          clearJamShareUrl ? null : (jamShareUrl ?? this.jamShareUrl),
      recordingKind: recordingKind ?? this.recordingKind,
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
