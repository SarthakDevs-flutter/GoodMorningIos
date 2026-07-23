import 'package:flutter/services.dart';

/// iOS: when a scheduled alarm notification arrives while the app is open.
class AlarmLaunchBridge {
  AlarmLaunchBridge._();

  static const _channel = MethodChannel('means_of_grace/alarm_launch');

  static void install(void Function(String payload) onAlarmPayload) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmNotification' && call.arguments is String) {
        onAlarmPayload(call.arguments as String);
      }
    });
  }
}
