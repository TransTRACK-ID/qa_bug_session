/// Default Notion **Status** select/status labels used by QA tooling.
abstract final class QaNotionStatusNames {
  /// Set on parent task when QA passes (formerly "Ready Code Review").
  static const passedParent = 'Archived';

  /// Quick-set chips on Ready to Test task detail.
  static const quickSetStatuses = <String>[
    'On Testing',
    'On Feedback',
    'Hold Test',
    passedParent,
  ];
}
