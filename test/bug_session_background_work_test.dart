import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/bug_session/kit/bug_session_background_work.dart';

void main() {
  group('bugSessionWeightedProgress', () {
    final phases = [
      BugSessionWorkPhase(label: 'a', weight: 1, run: (_) async {}),
      BugSessionWorkPhase(label: 'b', weight: 3, run: (_) async {}),
    ];

    test('start of first step', () {
      expect(
        bugSessionWeightedProgress(
          phases: phases,
          stepIndex: 0,
          stepProgress: 0,
        ),
        0,
      );
    });

    test('half of first step', () {
      expect(
        bugSessionWeightedProgress(
          phases: phases,
          stepIndex: 0,
          stepProgress: 0.5,
        ),
        0.125,
      );
    });

    test('start of second step', () {
      expect(
        bugSessionWeightedProgress(
          phases: phases,
          stepIndex: 1,
          stepProgress: 0,
        ),
        0.25,
      );
    });

    test('complete', () {
      expect(
        bugSessionWeightedProgress(
          phases: phases,
          stepIndex: 1,
          stepProgress: 1,
        ),
        1,
      );
    });
  });
}
