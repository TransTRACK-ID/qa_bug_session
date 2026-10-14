import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/bug_session/models/recorded_action.dart';
import 'package:qa_bug_session/bug_session/qa_testing/human_step_reproduce.dart';

void main() {
  test('formats interaction steps in order', () {
    final text = formatHumanStepReproduce([
      const RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: 0,
        route: 'lib/modules/bunkering/flow_in',
      ),
      const RecordedAction(
        type: RecordedActionType.tap,
        timestampMs: 100,
        target: '/flow_in/Submit',
      ),
    ]);

    expect(text, contains('1.'));
    expect(text, contains('Flow In'));
    expect(text, contains('Submit'));
    expect(text, contains('On '));
  });

  test('uses last navigation when tap route is unknown', () {
    final text = formatHumanStepReproduce([
      const RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: 0,
        route: '{"name":"DetailTaskRoute"}',
      ),
      const RecordedAction(
        type: RecordedActionType.tap,
        timestampMs: 50,
        target: 'unknown_route/Dialog',
      ),
    ]);
    expect(text, contains('Detail Task'));
    expect(text, isNot(contains('Unknown Route')));
  });

  test('back step names current screen', () {
    final text = formatHumanStepReproduce([
      const RecordedAction(
        type: RecordedActionType.navigation,
        timestampMs: 0,
        route: 'lib/modules/foo/bar_screen',
      ),
      const RecordedAction(
        type: RecordedActionType.back,
        timestampMs: 50,
      ),
    ]);
    expect(text.toLowerCase(), contains('go back from'));
  });

  test('tap step prefers screenLabel and widgetType metadata', () {
    final text = formatHumanStepReproduce([
      const RecordedAction(
        type: RecordedActionType.tap,
        timestampMs: 0,
        target: 'unknown_route/tap',
        metadata: {
          'screenLabel': 'HomePage',
          'widgetType': 'CustomTaskCardViewWidget',
        },
      ),
    ]);
    expect(text, contains('HomePage'));
    expect(text, contains('CustomTaskCardViewWidget'));
    expect(text, isNot(contains('unlabeled control')));
  });

  test('resolves module from modules path', () {
    final label = resolveTestingModuleLabel(
      currentRoute: 'lib/modules/bunkering/flow_in',
      actions: const [],
    );
    expect(label, 'Flow In');
  });
}
