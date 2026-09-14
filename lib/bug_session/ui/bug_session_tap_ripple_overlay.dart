import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import 'bug_session_tap_ripple_notifier.dart';

/// Non-interactive tap rings drawn above app content (inside screen recorder).
class BugSessionTapRippleOverlay extends StatelessWidget {
  const BugSessionTapRippleOverlay({super.key, required this.kit});

  final BugSessionKit kit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kit.tapRipples,
      builder: (context, _) {
        final ripples = kit.tapRipples.ripples;
        if (ripples.isEmpty) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _TapRipplePainter(
                ripples: ripples,
                now: DateTime.now(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TapRipplePainter extends CustomPainter {
  _TapRipplePainter({required this.ripples, required this.now});

  final List<BugSessionTapRipple> ripples;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final ageMs = now.difference(ripple.createdAt).inMilliseconds;
      final t = (ageMs / 750).clamp(0.0, 1.0);
      final center = ripple.globalPosition;
      final radius = 14.0 + (28.0 * t);
      final opacity = (1.0 - t) * 0.95;

      final fill = Paint()
        ..color = const Color(0xFFFF453A).withValues(alpha: opacity * 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.45, fill);

      final ring = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _TapRipplePainter oldDelegate) => true;
}
