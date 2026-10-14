import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

void main() {
  group('bugSessionPrepareActionsForReplay', () {
    test('keeps onboarding navigation for literal replay', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 100,
          route: '{"name":"OnboardingRoute"}',
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 200,
          route: '{"name":"LoginRoute"}',
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 2);
      expect(
        bugSessionParseRouteName(out.first.route),
        'OnboardingRoute',
      );
    });

    test('dedupes push navigation followed by coordinate tap', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 1000,
          route: '{"name":"DetailTaskRoute","args":{"id":"t1"}}',
        ),
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 1100,
          target: 'TaskRoute/tap',
          metadata: {'globalX': 10, 'globalY': 20},
        ),
        RecordedAction(
          type: RecordedActionType.back,
          timestampMs: 2000,
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 2);
      expect(out.first.type, RecordedActionType.navigation);
      expect(out.last.type, RecordedActionType.back);
    });

    test('dedupes back affordance tap before pop action', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 500,
          target: 'DetailTaskRoute/Back',
          metadata: {'semanticsLabel': 'Back', 'globalX': 1, 'globalY': 2},
        ),
        RecordedAction(
          type: RecordedActionType.back,
          timestampMs: 550,
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 1);
      expect(out.single.type, RecordedActionType.back);
    });

    test('dedupes tap before bloc-driven child push navigation', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 1000,
          target: 'DetailTaskRoute/Continue',
          metadata: {'recorderId': 'mobile_technician.widgets.appbutton_filledbig.continue'},
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 1800,
          route: '{"name":"TaskReviewRoute","args":{"id":"t1"}}',
        ),
        RecordedAction(
          type: RecordedActionType.back,
          timestampMs: 3000,
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 2);
      expect(out.first.type, RecordedActionType.tap);
      expect(out.last.type, RecordedActionType.back);
    });

    test('keeps tap and TaskReview nav when outside bloc-push window', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 1000,
          target: 'DetailTaskRoute/Continue',
          metadata: {'recorderId': 'continue'},
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 6000,
          route: '{"name":"TaskReviewRoute","args":{"id":"t1"}}',
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 2);
    });

    test('does not drop DetailTask push after tap', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 1000,
          target: 'TaskRoute/card',
          metadata: {'globalX': 1, 'globalY': 2},
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 1500,
          route: '{"name":"DetailTaskRoute","args":{"id":"t1"}}',
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 2);
    });

    test('review back sequence keeps single back after tap dedupe', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 1000,
          target: 'DetailTaskRoute/Continue',
          metadata: {'recorderId': 'continue'},
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 1800,
          route: '{"name":"TaskReviewRoute","args":{"id":"t1"}}',
        ),
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 5000,
          target: 'TaskReviewRoute/Back',
          metadata: {'semanticsLabel': 'Back'},
        ),
        RecordedAction(
          type: RecordedActionType.back,
          timestampMs: 5100,
        ),
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 7000,
          target: 'DetailTaskRoute/Back',
          metadata: {'semanticsLabel': 'Back'},
        ),
        RecordedAction(
          type: RecordedActionType.back,
          timestampMs: 7100,
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(actions);
      expect(out.length, 3);
      expect(out[0].type, RecordedActionType.tap);
      expect(out[1].type, RecordedActionType.back);
      expect(out[2].type, RecordedActionType.back);
    });

    test('trimBeforeMainShell drops login funnel prefix', () {
      final actions = [
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 10,
          route: '{"name":"LoginRoute"}',
        ),
        RecordedAction(
          type: RecordedActionType.tap,
          timestampMs: 20,
          target: 'LoginRoute/Login',
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 30,
          route: '{"name":"NavbarRoute"}',
        ),
        RecordedAction(
          type: RecordedActionType.navigation,
          timestampMs: 40,
          route: '{"name":"TaskRoute"}',
        ),
      ];
      final out = bugSessionPrepareActionsForReplay(
        actions,
        options: const BugSessionReplayActionFilterOptions(
          trimBeforeMainShell: true,
        ),
      );
      expect(out.length, 2);
      expect(bugSessionParseRouteName(out.first.route), 'NavbarRoute');
    });
  });
}
