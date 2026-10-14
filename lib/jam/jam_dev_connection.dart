abstract class JamDevCredentialsStore {
  Future<JamDevConnection?> read();

  Future<void> write(JamDevConnection connection);

  Future<void> clear();
}

class JamDevConnection {
  const JamDevConnection({
    required this.personalAccessToken,
    required this.teamId,
  });

  final String personalAccessToken;
  final String teamId;

  bool get isComplete =>
      personalAccessToken.isNotEmpty && teamId.isNotEmpty;
}
