import 'package:flutter/widgets.dart';

/// Marks BugSession-owned UI so capture, replay, and hit tests ignore it.
class BugSessionChromeScope extends StatelessWidget {
  const BugSessionChromeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'BugSession',
      identifier: 'BugSession',
      child: child,
    );
  }
}
