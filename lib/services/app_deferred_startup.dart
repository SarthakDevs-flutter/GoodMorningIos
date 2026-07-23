import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm_fire_watchdog.dart';
import 'alarm_schedule_helper.dart';
import 'app_bootstrap.dart';

typedef AlarmNotificationHandler =
    void Function(String payload, {bool persistent});

/// Heavy startup work that must wait until splash / launch gate finishes.
class AppDeferredStartup {
  AppDeferredStartup._();

  static bool _started = false;
  static AlarmNotificationHandler? _alarmHandler;

  static void registerAlarmHandler(AlarmNotificationHandler handler) {
    _alarmHandler = handler;
  }

  static Future<void> runAfterLaunchGate() async {
    if (_started || kIsWeb) return;
    _started = true;

    if (!await AppBootstrap.hasCompletedOnboarding()) return;

    final handler = _alarmHandler;
    if (handler == null) return;

    try {
      await AlarmScheduleHelper.ensureScheduled();
      AlarmFireWatchdog.instance.start(
        (payload, {persistent = false}) =>
            handler(payload, persistent: persistent),
      );
    } catch (e, st) {
      debugPrint('Deferred startup failed: $e\n$st');
    }
  }
}
