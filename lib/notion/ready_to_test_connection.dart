// Connection settings for the Ready to Test Notion queue.

import 'notion_api.dart';
import 'notion_ready_to_test.dart';

/// Non-secret defaults plus token stored via [ReadyToTestCredentialsStore].
class ReadyToTestConnection {
  const ReadyToTestConnection({
    required this.token,
    required this.dataSourceId,
    required this.qaUserId,
    this.productDomain,
    this.statusEquals = 'Ready to Test',
    this.statusPropertyName = 'Status',
    this.productPropertyName = 'Product domain',
    this.qaPropertyName = 'QA',
  });

  final String token;
  final String dataSourceId;
  final String qaUserId;
  final String? productDomain;
  final String statusEquals;
  final String statusPropertyName;
  final String productPropertyName;
  final String qaPropertyName;

  bool get isComplete =>
      token.isNotEmpty && dataSourceId.isNotEmpty && qaUserId.isNotEmpty;

  ReadyToTestConfig toFilterConfig() {
    return ReadyToTestConfig(
      qaUserId: qaUserId,
      statusEquals: statusEquals,
      productDomain: productDomain,
      statusPropertyName: statusPropertyName,
      productPropertyName: productPropertyName,
      qaPropertyName: qaPropertyName,
    );
  }

  NotionApiConfig toApiConfig() {
    return NotionApiConfig(
      token: token,
      dataSourceId: dataSourceId,
    );
  }
}

/// Host-provided persistence (setup generates secure-storage implementation).
abstract class ReadyToTestCredentialsStore {
  Future<ReadyToTestConnection?> read();

  Future<void> write(ReadyToTestConnection connection);

  Future<void> clear();
}

/// Defaults baked in at setup time (data source id, QA user id, optional product).
class ReadyToTestSetupDefaults {
  const ReadyToTestSetupDefaults({
    required this.dataSourceId,
    required this.qaUserId,
    this.productDomain,
    this.statusEquals = 'Ready to Test',
    this.statusPropertyName = 'Status',
    this.productPropertyName = 'Product domain',
    this.qaPropertyName = 'QA',
  });

  final String dataSourceId;
  final String qaUserId;
  final String? productDomain;
  final String statusEquals;
  final String statusPropertyName;
  final String productPropertyName;
  final String qaPropertyName;

  ReadyToTestConnection mergeWithToken(String token) {
    return ReadyToTestConnection(
      token: token,
      dataSourceId: dataSourceId,
      qaUserId: qaUserId,
      productDomain: productDomain,
      statusEquals: statusEquals,
      statusPropertyName: statusPropertyName,
      productPropertyName: productPropertyName,
      qaPropertyName: qaPropertyName,
    );
  }
}
