import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Channel IDs (Versioned to bust Android's cached channel importance)
  static const String _messageChannelId = 'klick_messages_v3';
  static const String _klickRequestChannelId = 'klick_requests_v3';
  static const String _discoveryChannelId = 'klick_discovery_v3';

  // Callback when notification is clicked
  void Function(String? payload)? onNotificationTapped;

  Future<void> init() async {
    if (_isInitialized) return;

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      return;
    }

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
          debugPrint('[NotificationService] Notification tapped payload: ${response.payload}');
          onNotificationTapped?.call(response.payload);
        },
      );

      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Clean up legacy cached channels if any
      await androidPlugin?.deleteNotificationChannel('klick_messages');
      await androidPlugin?.deleteNotificationChannel('klick_requests');
      await androidPlugin?.deleteNotificationChannel('klick_messages_v2');
      await androidPlugin?.deleteNotificationChannel('klick_requests_v2');

      final vibrationPattern = Int64List.fromList([0, 250, 200, 250]);

      // Channel 1: Incoming messages — Max importance (pops up as heads-up banner)
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _messageChannelId,
          'Klick Messages',
          description: 'High-priority heads-up popups for incoming Bluetooth messages',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: const Color(0xFFFFB300),
        ),
      );

      // Channel 2: Klick connection requests — Max importance, interrupting
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _klickRequestChannelId,
          'Klick Requests',
          description: 'High-priority alerts when someone wants to connect with you',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: const Color(0xFFFFB300),
        ),
      );

      // Channel 3: Nearby Device Discoveries — Max importance (pops up when devices near each other are detected)
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _discoveryChannelId,
          'Nearby Devices',
          description: 'Pop-up alerts when new Klick devices enter radio range',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          enableLights: true,
          ledColor: const Color(0xFFFFB300),
        ),
      );

      // Request notification permission on Android 13+
      await androidPlugin?.requestNotificationsPermission();

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully with Heads-Up channels');
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  /// Show notification for incoming message — pops up as Heads-Up banner over other apps & lockscreen
  Future<void> showMessageNotification({
    required String senderName,
    required String messageBody,
    String? endpointId,
  }) async {
    if (!_isInitialized) await init();

    final vibrationPattern = Int64List.fromList([0, 250, 200, 250]);

    final androidDetails = AndroidNotificationDetails(
      _messageChannelId,
      'Klick Messages',
      channelDescription: 'High-priority heads-up popups for incoming Bluetooth messages',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'New Klick message from $senderName',
      showWhen: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
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
        payload: endpointId != null ? 'chat:$endpointId' : null,
      );
      debugPrint('[NotificationService] Message heads-up notification posted for $senderName');
    } catch (e) {
      debugPrint('[NotificationService] Error showing message notification: $e');
    }
  }

  /// Show notification for incoming Klick connection request — interrupts immediately with banner popup
  Future<void> showKlickRequestNotification({
    required String requesterName,
    String? endpointId,
  }) async {
    if (!_isInitialized) await init();

    final vibrationPattern = Int64List.fromList([0, 300, 200, 300]);

    final androidDetails = AndroidNotificationDetails(
      _klickRequestChannelId,
      'Klick Requests',
      channelDescription: 'High-priority alerts when someone wants to connect with you',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      channelShowBadge: true,
      ticker: 'Incoming Klick request from $requesterName',
      showWhen: true,
      autoCancel: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(
        '$requesterName wants to Klick! Tap to accept or reject.',
        contentTitle: '⚡ Incoming Klick Request!',
        summaryText: 'Klick Messenger',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        _stableId('request_${endpointId ?? requesterName}'),
        '⚡ Incoming Klick Request!',
        '$requesterName wants to Klick!',
        details,
        payload: endpointId != null ? 'request:$endpointId' : null,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing Klick request notification: $e');
    }
  }

  /// Show notification when a new device is detected nearby — pops up banner
  Future<void> showDeviceDiscoveredNotification({
    required String deviceName,
    required String endpointId,
  }) async {
    if (!_isInitialized) await init();

    final vibrationPattern = Int64List.fromList([0, 200, 150, 200]);

    final androidDetails = AndroidNotificationDetails(
      _discoveryChannelId,
      'Nearby Devices',
      channelDescription: 'Pop-up alerts when new Klick devices enter radio range',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      channelShowBadge: true,
      ticker: 'Nearby Klick device found: $deviceName',
      showWhen: true,
      autoCancel: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(
        '$deviceName is nearby! Tap to connect and start chatting offline.',
        contentTitle: '⚡ Nearby Device Detected',
        summaryText: 'Klick Radar',
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
        _stableId('discovery_$endpointId'),
        '⚡ Nearby Device Detected',
        '$deviceName is within radio range!',
        details,
        payload: 'discovery:$endpointId',
      );
      debugPrint('[NotificationService] Discovery notification posted for $deviceName');
    } catch (e) {
      debugPrint('[NotificationService] Error showing discovery notification: $e');
    }
  }

  /// Dismiss any existing Klick request notification once handled
  Future<void> dismissKlickRequestNotification(String endpointId) async {
    try {
      await _notificationsPlugin.cancel(
        _stableId('request_$endpointId'),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error dismissing notification: $e');
    }
  }

  /// Stable integer ID from a string key (avoids duplicates per-peer)
  int _stableId(String key) => key.hashCode.abs() % 100000;
}
