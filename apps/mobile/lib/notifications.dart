/// Device notifications (founder directive 2026-10-04): the app used to
/// request the notification permission but never post anything, so
/// nothing ever "dropped" on the phone. This service wraps
/// flutter_local_notifications - review-due nudges and download
/// completions land as real Android notifications on the 'renance'
/// channel. Everything is best-effort: a notification failure never
/// blocks study, and every call is safe before init or without the
/// permission (it just no-ops).
library;

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RenanceNotifications {
  RenanceNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Call once at app start. Android-only (the shell ships Android
  /// builds; other platforms no-op).
  static Future<void> init() async {
    if (_ready || !Platform.isAndroid) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    try {
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      // Notifications are sugar, never a gate.
    }
  }

  /// Asks for the runtime permission (Android 13+); returns whether
  /// notifications may be shown. Safe to call repeatedly.
  static Future<bool> ensurePermission() async {
    await init();
    if (!_ready) return false;
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      final bool? granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Posts one immediate notification. Silently ignored before init or
  /// without the permission.
  static Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    const AndroidNotificationDetails channel = AndroidNotificationDetails(
      'renance',
      'Renance updates',
      channelDescription: 'Study reminders and download progress',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails details = NotificationDetails(
      android: channel,
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Never crash study over a notification.
    }
  }

  /// Stable ids so a second notification replaces (not stacks with) the
  /// same kind.
  static const int downloadDoneId = 2001;
  static const int reviewDueId = 2002;
}
