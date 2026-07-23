import 'alarm_notification_service.dart';
import 'alarm_preferences.dart';
import 'alarm_session_service.dart';
import 'alarm_store.dart';

/// One daily alarm the user configured (morning or evening prayer).
class AlarmSlot {
  const AlarmSlot({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.payload,
  });

  final String id;
  final String label;
  final int hour;
  final int minute;
  final bool enabled;
  final String payload;

  String get fireKey => '$id-${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DateTime scheduledToday(DateTime now) =>
      DateTime(now.year, now.month, now.day, hour, minute);

  DateTime nextOccurrence(DateTime now) {
    final today = scheduledToday(now);
    if (!today.isBefore(now)) return today;
    return today.add(const Duration(days: 1));
  }
}

/// All user-configured alarm times (any hour 0–23).
class AlarmRegistry {
  AlarmRegistry._();

  static Future<List<AlarmSlot>> loadEnabledSlots() async {
    final slots = <AlarmSlot>[];

    if (await AlarmPreferences.isEnabled()) {
      // 멀티 알람: 오늘 울릴 알람마다 슬롯 하나. 오늘 미션을 완료한 알람은
      // 워치독 대상에서 빠진다.
      final alarms = await AlarmStore.loadAlarms();
      final now = DateTime.now();
      for (final alarm in AlarmStore.dueToday(alarms, now)) {
        if (await AlarmSessionService.instance.isAlarmCompletedToday(
          alarm.id,
        )) {
          continue;
        }
        slots.add(
          AlarmSlot(
            id: 'morning_${alarm.id}',
            label: 'Morning prayer',
            hour: alarm.hour,
            minute: alarm.minute,
            enabled: true,
            payload: AlarmNotificationService.morningAlarmPayload,
          ),
        );
      }
    }

    if (await AlarmPreferences.isEveningEnabled()) {
      slots.add(
        AlarmSlot(
          id: 'evening',
          label: 'Evening blessing',
          hour: await AlarmPreferences.getEveningHour(),
          minute: await AlarmPreferences.getEveningMinute(),
          enabled: true,
          payload: AlarmNotificationService.eveningAlarmPayload,
        ),
      );
    }

    return slots;
  }

  static Future<List<AlarmSlot>> loadAllSlots() async {
    return [
      AlarmSlot(
        id: 'morning',
        label: 'Morning prayer',
        hour: await AlarmPreferences.getHour(),
        minute: await AlarmPreferences.getMinute(),
        enabled: await AlarmPreferences.isEnabled(),
        payload: AlarmNotificationService.morningAlarmPayload,
      ),
      AlarmSlot(
        id: 'evening',
        label: 'Evening blessing',
        hour: await AlarmPreferences.getEveningHour(),
        minute: await AlarmPreferences.getEveningMinute(),
        enabled: await AlarmPreferences.isEveningEnabled(),
        payload: AlarmNotificationService.eveningAlarmPayload,
      ),
    ];
  }
}
