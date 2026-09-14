import '../models/manifest.dart';

/// Runtime app metadata supplied by the host application.
class BugSessionEnvironment {
  const BugSessionEnvironment({
    required this.packageId,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    this.deviceModel,
    this.environment,
    required this.user,
    required this.credential,
  });

  final String packageId;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String? deviceModel;
  final String? environment;
  final BugSessionUser user;
  final BugSessionCredential credential;
}
