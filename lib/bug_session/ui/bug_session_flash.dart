import 'dart:developer' as developer;

import 'package:flash/flash.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../kit/bug_session_config.dart';
import '../kit/bug_session_modal_context.dart';
import '../kit/bug_session_theme.dart';
import 'glass/glass_panel.dart';

class BugSessionFlash {
  BugSessionFlash._();

  static const _width = 559.0;

  static void showTopFlash(
    BugSessionConfig config, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    _logToConsole(message, isError: isError);

    final context = bugSessionModalContext(config);
    if (context == null || !context.mounted) {
      _logToConsole(
        'Top flash skipped (no modal context). Message was: $message',
        isError: true,
      );
      return;
    }
    if (Navigator.maybeOf(context) == null) {
      _logToConsole(
        'Top flash skipped (no Navigator). Message was: $message',
        isError: true,
      );
      return;
    }
    final theme = config.resolvedTheme;
    showFlash(
      context: context,
      duration: duration,
      builder: (context, controller) {
        return Flash(
          controller: controller,
          position: FlashPosition.top,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _width),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: GlassPanel(
                  theme: theme,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isError ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Visible in `flutter run` / logcat (including release staging builds).
  static void _logToConsole(String message, {required bool isError}) {
    final prefix = isError ? '[BugSession] ERROR: ' : '[BugSession] ';
    developer.log(
      message,
      name: 'BugSession',
      level: isError ? 1000 : 800,
    );
    if (kDebugMode) {
      debugPrint('$prefix$message');
    } else {
      // ignore: avoid_print
      print('$prefix$message');
    }
  }
}
