import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm_registry.dart';
import 'alarm_session_service.dart';

/// Fires alarms at user-chosen times (any hour 0–23), even if iOS notification is late.
/// Also re-fires while morning/evening prayer is still incomplete.
class AlarmFireWatchdog {
  AlarmFireWatchdog._();

  static final AlarmFireWatchdog instance = AlarmFireWatchdog._();

  /// How long after the scheduled minute we still treat the alarm as due.
  static const dueWindow = Duration(minutes: 5);

  /// Re-fire interval while prayer is incomplete after alarm time.
  static const persistenceInterval = Duration(minutes: 2);

  Timer? _timer;
  void Function(String payload, {bool persistent})? _onFire;
  final Set<String> _firedKeys = {};
  final Map<String, DateTime> _lastPersistentFire = {};
  String? _lastDayKey;

  void start(void Function(String payload, {bool persistent}) onFire) {
    if (kIsWeb) return;
    _onFire = onFire;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call at midnight or when prefs change so the same slot can fire again.
  void resetDaily() {
    _firedKeys.clear();
    _lastPersistentFire.clear();
  }

  Future<void> _tick() async {
    final callback = _onFire;
    if (callback == null) return;

    if (AlarmSessionService.instance.isSetupScreenActive) {
      debugPrint('[WATCHDOG] Suppressed watchdog check: setup screen is active');
      return;
    }

    final now = DateTime.now();
    final dayKey = _dayKey(now);
    if (_lastDayKey != null && _lastDayKey != dayKey) {
      _firedKeys.clear();
      _lastPersistentFire.clear();
    }
    _lastDayKey = dayKey;
    final slots = await AlarmRegistry.loadEnabledSlots();

    for (final slot in slots) {
      final fireKey = '${dayKey}_${slot.fireKey}';
      if (_firedKeys.contains(fireKey)) continue;

      if (_isDue(now, slot)) {
        _firedKeys.add(fireKey);
        debugPrint(
          'AlarmFireWatchdog: ${slot.label} ${slot.hour}:${slot.minute}',
        );
        callback(slot.payload);
      }
    }

    await _firePersistentMorning(callback, now);
    await _firePersistentEvening(callback, now);
  }

  Future<void> _firePersistentMorning(
    void Function(String payload, {bool persistent}) callback,
    DateTime now,
  ) async {
    if (!await AlarmSessionService.instance.isMorningAppLocked()) {
      return;
    }
    final key = 'persist_morning';
    if (!_shouldPersistFire(key, now)) return;
    _lastPersistentFire[key] = now;
    debugPrint('AlarmFireWatchdog: persistent morning re-fire');
    callback('morning_alarm', persistent: true);
  }

  Future<void> _firePersistentEvening(
    void Function(String payload, {bool persistent}) callback,
    DateTime now,
  ) async {
    if (!await AlarmSessionService.instance.isEveningAppLocked()) {
      return;
    }
    final key = 'persist_evening';
    if (!_shouldPersistFire(key, now)) return;
    _lastPersistentFire[key] = now;
    debugPrint('AlarmFireWatchdog: persistent evening re-fire');
    callback('evening_blessing_alarm', persistent: true);
  }

  bool _shouldPersistFire(String key, DateTime now) {
    final last = _lastPersistentFire[key];
    if (last == null) return true;
    return now.difference(last) >= persistenceInterval;
  }

  bool _isDue(DateTime now, AlarmSlot slot) {
    final scheduled = slot.scheduledToday(now);
    final elapsed = now.difference(scheduled);
    return !elapsed.isNegative && elapsed <= dueWindow;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
