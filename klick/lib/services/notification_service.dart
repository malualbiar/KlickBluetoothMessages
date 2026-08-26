import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Channel IDs
  static const String _messageChannelId = 'klick_messages';
  static const String _klickRequestChannelId = 'klick_requests';

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Channel 1: Incoming messages — high importance, sound, vibrate
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _messageChannelId,
          'Klick Messages',
          description: 'Notifications for incoming Bluetooth messages',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFFFB300),
        ),
      );

      // Channel 2: Klick connection requests — max importance, interrupting
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _klickRequestChannelId,
          'Klick Requests',
          description: 'Notifications when someone wants to connect with you',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFFFB300),
        ),
      );

      // Request notification permission on Android 13+
      await androidPlugin?.requestNotificationsPermission();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Show notification for incoming message — fires even with screen off
  Future<void> showMessageNotification({
    required String senderName,
    required String messageBody,
    String? endpointId,
  }) async {
    if (!_isInitialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _messageChannelId,
      'Klick Messages',
      channelDescription: 'Notifications for incoming Bluetooth messages',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,       // wakes screen even when off
      playSound: true,
      enableVibration: true,
      ticker: 'New Klick message',
      showWhen: true,
      styleInformation: BigTextStyleInformation(
        messageBody,
        contentTitle: '📡 Klick from $senderName',
        summaryText: 'Klick Messenger',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        _stableId(endpointId ?? senderName),
        '📡 Klick from $senderName',
        messageBody,
        details,
        payload: endpointId,
      );
    } catch (e) {
      debugPrint('Error showing message notification: $e');
    }
  }

  /// Show notification for incoming Klick connection request — interrupts immediately
  Future<void> showKlickRequestNotification({
    required String requesterName,
    String? endpointId,
  }) async {
    if (!_isInitialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _klickRequestChannelId,
      'Klick Requests',
      channelDescription: 'Notifications when someone wants to connect with you',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,       // wakes screen even when off
      playSound: true,
      enableVibration: true,
      ticker: 'Incoming Klick request',
      showWhen: true,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        '$requesterName wants to Klick! Open the app to Accept or Reject.',
        contentTitle: '⚡ Incoming Klick!',
        summaryText: 'Klick Messenger',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        _stableId('request_${endpointId ?? requesterName}'),
        '⚡ Incoming Klick!',
        '$requesterName wants to Klick!',
        details,
        payload: endpointId,
      );
    } catch (e) {
      debugPrint('Error showing Klick request notification: $e');
    }
  }

  /// Dismiss any existing Klick request notification once handled
  Future<void> dismissKlickRequestNotification(String endpointId) async {
    try {
      await _notificationsPlugin.cancel(
        _stableId('request_$endpointId'),
      );
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  /// Stable integer ID from a string key (avoids duplicates per-peer)
  int _stableId(String key) => key.hashCode.abs() % 100000;
}
