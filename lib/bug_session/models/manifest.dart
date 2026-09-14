import 'package:meta/meta.dart';

@immutable
class BugSessionUser {
  const BugSessionUser({
    required this.userId,
    this.displayHint,
    this.profileData,
  });

  final String userId;
  final String? displayHint;
  final Map<String, Object?>? profileData;

  Map<String, Object?> toJson() => {
        'userId': userId,
        if (displayHint != null) 'displayHint': displayHint,
        if (profileData != null && profileData!.isNotEmpty)
          'profileData': profileData,
      };

  factory BugSessionUser.fromJson(Map<String, Object?> json) {
    return BugSessionUser(
      userId: json['userId'] as String,
      displayHint: json['displayHint'] as String?,
      profileData: json['profileData'] == null
          ? null
          : Map<String, Object?>.from(json['profileData'] as Map),
    );
  }
}

@immutable
class BugSessionCredential {
  const BugSessionCredential({
    required this.type,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String type;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
        'type': type,
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
      };

  factory BugSessionCredential.fromJson(Map<String, Object?> json) {
    return BugSessionCredential(
      type: json['type'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}

@immutable
class BugSessionLock {
  const BugSessionLock({
    required this.packageId,
    required this.appVersion,
    required this.buildNumber,
    required this.userId,
    required this.lockChecksum,
  });

  final String packageId;
  final String appVersion;
  final String buildNumber;
  final String userId;
  final String lockChecksum;

  Map<String, Object?> toJson() => {
        'packageId': packageId,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'userId': userId,
        'lockChecksum': lockChecksum,
      };

  factory BugSessionLock.fromJson(Map<String, Object?> json) {
    return BugSessionLock(
      packageId: json['packageId'] as String,
      appVersion: json['appVersion'] as String,
      buildNumber: json['buildNumber'] as String,
      userId: json['userId'] as String,
      lockChecksum: json['lockChecksum'] as String,
    );
  }
}

@immutable
class BugSessionManifest {
  const BugSessionManifest({
    required this.sessionId,
    required this.startedAt,
    this.stoppedAt,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    this.deviceModel,
    this.initialRoute,
    this.environment,
    required this.user,
    required this.credential,
    required this.lock,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String? deviceModel;
  final String? initialRoute;
  final String? environment;
  final BugSessionUser user;
  final BugSessionCredential credential;
  final BugSessionLock lock;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (stoppedAt != null)
          'stoppedAt': stoppedAt!.toUtc().toIso8601String(),
        'app': {'version': appVersion, 'build': buildNumber},
        'platform': {'name': platform, 'osVersion': osVersion},
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (initialRoute != null) 'initialRoute': initialRoute,
        if (environment != null) 'environment': environment,
        'user': user.toJson(),
        'credential': credential.toJson(),
        'lock': lock.toJson(),
      };

  factory BugSessionManifest.fromJson(Map<String, Object?> json) {
    final app = json['app'] as Map;
    final platform = json['platform'] as Map;
    return BugSessionManifest(
      sessionId: json['sessionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] != null
          ? DateTime.parse(json['stoppedAt'] as String)
          : null,
      appVersion: app['version'] as String,
      buildNumber: app['build'] as String,
      platform: platform['name'] as String,
      osVersion: platform['osVersion'] as String,
      deviceModel: json['deviceModel'] as String?,
      initialRoute: json['initialRoute'] as String?,
      environment: json['environment'] as String?,
      user: BugSessionUser.fromJson(
        Map<String, Object?>.from(json['user'] as Map),
      ),
      credential: BugSessionCredential.fromJson(
        Map<String, Object?>.from(json['credential'] as Map),
      ),
      lock: BugSessionLock.fromJson(
        Map<String, Object?>.from(json['lock'] as Map),
      ),
    );
  }
}
