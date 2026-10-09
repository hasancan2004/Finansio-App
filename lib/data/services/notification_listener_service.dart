import 'dart:async';

import 'package:flutter/services.dart';

/// Android bildirim dinleyicisi ile iletişim kuran köprü.
///
/// `SmsNotificationListenerService` (native) tarafından yakalanan bildirim
/// metinleri buradan akış olarak alınır.
class NotificationListenerService {
  NotificationListenerService._();

  static const MethodChannel _channel =
      MethodChannel('com.hasancankula.finansio/sms_listener');

  static final StreamController<String> _messages =
      StreamController<String>.broadcast();
  static final StreamController<bool> _connected =
      StreamController<bool>.broadcast();

  /// Yakalanan bildirim metinleri.
  static Stream<String> get messages => _messages.stream;

  /// Dinleyicinin bağlı olup olmadığı (izin durumu).
  static Stream<bool> get connected => _connected.stream;

  static bool _handlerSet = false;

  static void init() {
    if (_handlerSet) return;
    _handlerSet = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotification':
          final text = call.arguments;
          if (text is String && text.trim().isNotEmpty) {
            _messages.add(text.trim());
          }
          break;
        case 'onListenerConnected':
          _connected.add(call.arguments == true);
          break;
        default:
          break;
      }
    });
  }

  /// Bildirim dinleyicisinin kullanıcı tarafından etkinleştirilip
  /// etkinleştirilmediğini döner.
  static Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sistem "Bildirim erişimi" ayarlarını açar.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (_) {
      // yut
    }
  }
}
