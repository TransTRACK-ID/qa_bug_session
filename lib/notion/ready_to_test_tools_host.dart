import 'package:flutter/widgets.dart';

import 'ready_to_test_connection.dart';

/// Legacy MaterialApp wrapper — Ready to Test now opens from the BugSession FAB
/// panel via [BugSessionReadyToTestSheet] when [BugSessionConfig.readyToTestStore]
/// is set.
@Deprecated(
  'Ready to Test is integrated in BugSessionControlPanel; pass '
  'readyToTestStore on BugSessionConfig instead.',
)
class ReadyToTestToolsHost extends StatelessWidget {
  const ReadyToTestToolsHost({
    super.key,
    required this.store,
    required this.defaults,
    required this.child,
    this.enabled = true,
  });

  final ReadyToTestCredentialsStore store;
  final ReadyToTestSetupDefaults defaults;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;
}
