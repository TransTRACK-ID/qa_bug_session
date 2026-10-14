import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_bug_session/bug_session/ui/bug_session_replay_chrome_passthrough.dart';

void main() {
  testWidgets('passthrough chrome does not absorb taps', (tester) async {
    final appTapped = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => appTapped.add(e.position),
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 200,
              height: 200,
              child: BugSessionReplayChromePassthrough(
                passthrough: true,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {},
                  child: const ColoredBox(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 50));
    expect(appTapped, isNotEmpty);
    expect(appTapped.first, const Offset(50, 50));
  });

  testWidgets('chrome receives taps when passthrough is off', (tester) async {
    final appTapped = <Offset>[];
    var chromeTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => appTapped.add(e.position),
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 200,
              height: 200,
              child: BugSessionReplayChromePassthrough(
                passthrough: false,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => chromeTapped = true,
                  child: const ColoredBox(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 50));
    expect(chromeTapped, isTrue);
    expect(appTapped, isEmpty);
  });
}
