import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android ongoing notification with stop action during QA testing.
class QaTestingNotification {
  QaTestingNotification._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'qa_bug_session_testing';
  static const _notificationId = 4242;
  static VoidCallback? _onStop;

  static Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'stop_testing') {
          _onStop?.call();
        }
      },
    );
  }

  static Future<void> showActive({required VoidCallback onStop}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _onStop = onStop;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'QA testing',
      channelDescription: 'Active card testing sessions',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      actions: [
        AndroidNotificationAction(
          'stop_testing',
          'Stop testing',
          showsUserInterface: true,
        ),
      ],
    );
    await _plugin.show(
      id: _notificationId,
      title: 'QA testing in progress',
      body: 'Use Stop testing or the objective panel to finish.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> dismiss() async {
    if (kIsWeb) {
      return;
    }
    await _plugin.cancel(id: _notificationId);
    _onStop = null;
  }
}
