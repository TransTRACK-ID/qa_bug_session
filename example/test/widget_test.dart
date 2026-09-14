import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo scaffold smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('BugSession demo')),
        ),
      ),
    );
    expect(find.text('BugSession demo'), findsOneWidget);
  });
}
