import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter bridge to the Android KlickBackgroundService foreground service.
/// On iOS (no foreground service concept), all calls are no-ops.
class BackgroundService {
  static const _channel = MethodChannel('klick/background_service');

  /// Start the foreground service — call when app is backgrounded.
  /// This keeps the process alive so Bluetooth callbacks and notifications
  /// continue firing even when the user presses Home.
  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('startForegroundService');
      debugPrint('[BackgroundService] Foreground service started');
    } catch (e) {
      debugPrint('[BackgroundService] start error: $e');
    }
  }

  /// Stop the foreground service — call when app returns to foreground.
  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
      debugPrint('[BackgroundService] Foreground service stopped');
    } catch (e) {
      debugPrint('[BackgroundService] stop error: $e');
    }
  }

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;
}
