import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/qa_bug_session.dart';

void main() {
  group('runtimeTextInputRecorderId', () {
    test('builds stable ids from route and label', () {
      expect(
        runtimeTextInputRecorderId(
          routeKey: 'LoginRoute',
          fieldLabel: 'Email',
        ),
        'mobile_technician.login.input.email',
      );
    });
  });

  group('TextInputTargetRegistry', () {
    test('apply invokes registered handler', () async {
      var applied = '';
      const id = 'mobile_technician.login.input.email';
      TextInputTargetRegistry.instance.register(id, (text) async {
        applied = text;
      });
      try {
        await TextInputTargetRegistry.instance.apply(id, 'qa@example.com');
        expect(applied, 'qa@example.com');
      } finally {
        TextInputTargetRegistry.instance.unregister(id);
      }
    });

    test('apply times out when id is missing', () async {
      expect(
        () => TextInputTargetRegistry.instance.apply(
          'missing.input.id',
          'x',
          timeout: const Duration(milliseconds: 120),
        ),
        throwsA(isA<TextInputTargetNotFoundException>()),
      );
    });
  });

  group('RecorderInput', () {
    testWidgets('replay apply sets controller text', (tester) async {
      const id = 'mobile_technician.test.input.note';
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecorderInput(
              id: id,
              controller: controller,
              child: TextField(controller: controller),
            ),
          ),
        ),
      );
      await TextInputTargetRegistry.instance.apply(id, 'hello replay');
      expect(controller.text, 'hello replay');
      controller.dispose();
    });

    testWidgets('replay apply of empty clears controller and onChanged', (
      tester,
    ) async {
      const id = 'mobile_technician.test.input.search';
      final controller = TextEditingController(text: 'hazel');
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecorderInput(
              id: id,
              controller: controller,
              onChanged: (v) => changed = v,
              child: TextField(controller: controller),
            ),
          ),
        ),
      );
      await TextInputTargetRegistry.instance.apply(id, '');
      expect(controller.text, '');
      expect(changed, '');
      controller.dispose();
    });

    testWidgets('records empty clear after non-empty text', (tester) async {
      const id = 'mobile_technician.test.input.search';
      final controller = TextEditingController();
      final recorder = BugSessionRecorder();
      await recorder.start(sessionId: 'text-clear-test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecorderInput(
              id: id,
              controller: controller,
              recorder: recorder,
              recordDebounce: const Duration(milliseconds: 50),
              child: TextField(controller: controller),
            ),
          ),
        ),
      );

      controller.text = 'hazel';
      await tester.pump(const Duration(milliseconds: 60));
      controller.text = '';
      await tester.pump(const Duration(milliseconds: 60));

      final texts = recorder.semantic.actions
          .where((a) => a.type == RecordedActionType.textInput)
          .map((a) => a.text)
          .toList();
      expect(texts, contains('hazel'));
      expect(texts, contains(''));
      expect(texts.last, '');

      controller.dispose();
    });
  });
}
