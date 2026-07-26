import 'dart:async';

import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:flutter/foundation.dart';

import 'alarm_notification_service.dart';
import 'alarm_preferences.dart';
import 'alarm_schedule_helper.dart';
import 'alarm_session_service.dart';
import 'alarm_sound_service.dart';
import 'alarm_store.dart';
import 'completion_history_service.dart';
import 'native_alarm_service.dart';

// Keep in sync with AlarmScheduleHelper._pkgMorningAlarmId / _pkgEveningAlarmId.
const _pkgMorningAlarmId = 100001;
const _pkgEveningAlarmId = 100002;

/// Keeps alarms ringing / re-firing until the user finishes prayer on a live alarm.
class AlarmPersistenceService {
  AlarmPersistenceService._();

  static const String slotMorning = 'morning';
  static const String slotEvening = 'evening';

  static Future<void> onAlarmFired(String payload, {String? alarmId}) async {
    if (await AlarmSessionService.instance.checkAndHandleConflict(payload, alarmId: alarmId)) {
      return;
    }

    if (payload == AlarmNotificationService.morningAlarmPayload) {
      await AlarmSessionService.instance.activateMorningAlarmSession(alarmId: alarmId);
      await AlarmSoundService.instance.start(alarmId: alarmId);
      debugPrint('AlarmPersistence: morning session started (in-app sound)');
      return;
    }
    if (payload == AlarmNotificationService.eveningAlarmPayload) {
      await AlarmSessionService.instance.activateEveningAlarmSession();
      await AlarmSoundService.instance.start();
      debugPrint('AlarmPersistence: evening session started (in-app sound)');
    }
  }

  static Future<void> onMorningCompleted({String? alarmId}) async {
    await AlarmSoundService.instance.stop();
    // Cancel today's remaining burst + alarm-package one-shot so neither rings again.
    await AlarmNotificationService.instance.cancelMorningAlarm();
    try {
      await alarm_pkg.Alarm.stop(_pkgMorningAlarmId);
    } catch (e) {
      debugPrint('AlarmPersistence: alarm-pkg morning stop: $e');
    }
    // AlarmKit Amen flow — Amen is the ONLY final stop, so today must go silent:
    // 1) Stamp today completed (stray retries get ignored by native perform).
    // 2) Stop current alert + cancel the whole retry ladder + block legacy snooze.
    // 3) Re-arm the next occurrence only. Retry alarms are fixed one-shots, so
    //    this creates tomorrow's ladder without recreating today's retries.
    // No-op on iOS < 26.
    // 어떤 알람의 미션이었는지 확정하고, 그 알람만 오늘 완료 처리한다 —
    // 같은 날의 다른 알람은 자기 시간에 그대로 울린다.
    var completedAlarmId =
        alarmId ?? await AlarmSessionService.instance.activeAlarmId();
    if (completedAlarmId == null || completedAlarmId.isEmpty) {
      // 알림 경로 진입·미션 중 앱 재시작이면 '누가 울렸는지'가 유실된다.
      // 이때 도장 없이 넘어가면(전역만) 같은 날 다음 알람이 오판되므로,
      // '오늘 시각이 방금 지나간 미완료 알람'으로 추론한다
      // (실측 2026-07-10: 9:10 아멘 id 유실 → 9:15 미션 무반응).
      completedAlarmId = await _inferJustFiredAlarmId();
      debugPrint('[AMEN] fired-alarm id missing — inferred: $completedAlarmId');
    }
    await AlarmSessionService.instance.markMorningCompleted(
      alarmId: completedAlarmId,
    );
    await NativeAlarmService.markMorningMissionCompleted(
      alarmId: completedAlarmId,
    );
    // 기록 달력용: 오늘 완료 수를 1 올린다.
    await CompletionHistoryService.recordCompletion();
    await NativeAlarmService.stopMorningAlarmKitAlert();
    if (await AlarmPreferences.isEnabled()) {
      final alarms = await AlarmStore.loadAlarms();
      final completedIds = <String>{};
      for (final alarm in alarms) {
        if (await AlarmSessionService.instance.isAlarmCompletedToday(
          alarm.id,
        )) {
          completedIds.add(alarm.id);
        }
      }
      final now = DateTime.now();
      // 미션 중 시간이 지나간 다른 알람은 그날 스킵한다(안드로이드와 동일
      // 정책). 아멘 직후 fireImmediately로 즉시 울리던 동작은 '완료했는데
      // 또 알람이 뜨는' 혼란만 낳았다(실측: 06:19:02 홀수 초 발화).
      final nextInfo = AlarmStore.nextOccurrenceInfo(
        alarms,
        now,
        isCompletedToday: completedIds.contains,
      );
      debugPrint(
        '[AMEN-NEXT] completed=$completedIds alarms=${alarms.map((a) => '${a.id}@${a.hour}:${a.minute}(${a.enabled})').join(',')} '
        'completedAlarmId=$completedAlarmId next=${nextInfo?.alarm.id}@${nextInfo?.when}',
      );
      if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
        // iOS: 알람별 독립 등록이라 아멘 후 '재예약'이 없다 — 조정 동기화만.
        final counts = await NativeAlarmService.syncMorningAlarmList(
          alarms: alarms,
          nextAlarmId: nextInfo?.alarm.id,
          nextFireAt: nextInfo?.when,
        );
        if ((counts?['ownerRemoved'] ?? 0) > 0) {
          // 아멘-후 동기화에서도 대칭: 주인 알람이 사라졌으면 알림 부대까지.
          await AlarmNotificationService.instance.cancelMorningAlarm();
          debugPrint('[ALARM] mission owner removed — morning squads cleared');
        }
      } else {
        await NativeAlarmService.scheduleNextMorningAfterCompletion(
          hour: nextInfo?.when.hour ?? await AlarmPreferences.getHour(),
          minute: nextInfo?.when.minute ?? await AlarmPreferences.getMinute(),
          weekdays: alarms.expand((a) => a.weekdays).toSet(),
          alarms: alarms,
          nextAlarmId: nextInfo?.alarm.id,
          fireImmediately: false,
          nextFireAt: nextInfo?.when,
        );
      }
      // 아멘 = 오늘 융단·잔재 정리(비대기). 다음 융단은 다음 울림 때
      // 게이트가 깐다 — 미리 깔지 않아 평상시 앱이 가볍다.
      // 백스톱은 다음 발화로 재장전(내부에서 기존 6발 취소 후 등록) —
      // mobiletimerd 잠들기 대비 독립 배달망은 항상 다음 알람을 겨눈다.
      final backstopAt = nextInfo?.when;
      final backstopSound = nextInfo?.alarm.soundName;
      unawaited(() async {
        await AlarmNotificationService.instance.cancelMorningRingCarpet();
        if (await AlarmScheduleHelper.usesAlarmKitForMorning() &&
            backstopAt != null) {
          await AlarmNotificationService.instance.scheduleMorningBackstop(
            fireAt: backstopAt,
            soundName: backstopSound,
          );
        } else {
          await AlarmNotificationService.instance.cancelMorningBackstop();
        }
      }());
    }
    // 완료 순간 화면에 남은 배너 청소(예약 무접촉).
    unawaited(NativeAlarmService.clearDeliveredNotifications());
    await _rearmSilentLoopForNextAlarm();
    await AlarmSessionService.instance.skipPassedAlarmsDuringActiveSession();
    // The morning session started earlier may have deferred today's evening
    // blessing to tomorrow. Now that the session has ended, restore it for today
    // if its time hasn't passed — so a blessing scheduled *after* this Amen still
    // fires normally (Single Active Alarm policy, Scenario 2).
    await AlarmSessionService.instance.rearmEveningForTodayIfUpcoming();
    debugPrint('AlarmPersistence: morning completed — all alarms cancelled');
  }

  static Future<void> onEveningCompleted() async {
    await AlarmSoundService.instance.stop();
    await AlarmNotificationService.instance.cancelEveningAlarm();
    try {
      await alarm_pkg.Alarm.stop(_pkgEveningAlarmId);
    } catch (e) {
      debugPrint('AlarmPersistence: alarm-pkg evening stop: $e');
    }
    await NativeAlarmService.markEveningMissionCompleted();
    // 달력 자녀 표시·연속 기록용 — 이 호출이 빠져 있어 🧒가 안 뜨던 버그 수리.
    await CompletionHistoryService.recordEveningCompletion();
    await NativeAlarmService.stopEveningAlarmKitAlert();
    if (await AlarmPreferences.isEveningEnabled()) {
      final eveningHour = await AlarmPreferences.getEveningHour();
      final eveningMinute = await AlarmPreferences.getEveningMinute();
      // 완료 직후이므로 다음 발화는 내일 저녁 — 사다리·백스톱 모두.
      final now = DateTime.now();
      final tomorrowEvening = DateTime(
        now.year,
        now.month,
        now.day,
        eveningHour,
        eveningMinute,
      ).add(const Duration(days: 1));
      await NativeAlarmService.scheduleEveningAlarmKit(
        hour: eveningHour,
        minute: eveningMinute,
        nextFireAt: tomorrowEvening,
      );
      await AlarmNotificationService.instance.scheduleEveningBackstop(
        fireAt: tomorrowEvening,
      );
      // Android: alarm 패키지 1회성 예약은 아멘이 직접 내일로 재장전해야
      // 한다(위 두 호출은 iOS 전용 no-op — 앱을 다시 안 열면 다음 저녁이
      // 침묵하던 구멍의 수리).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await AlarmScheduleHelper.rearmEveningPackageAlarm(forceNextFireAt: tomorrowEvening);
      }
    }
    await AlarmSessionService.instance.markEveningCompleted();
    unawaited(NativeAlarmService.clearDeliveredNotifications());
    await _rearmSilentLoopForNextAlarm();
    await AlarmSessionService.instance.skipPassedAlarmsDuringActiveSession();
    debugPrint('AlarmPersistence: evening completed — all alarms cancelled');
  }

  /// 아멘 시점에 울린 알람 id가 유실됐을 때의 추론: 오늘 요일에 켜져 있고
  /// 시각이 이미 지났으며 아직 오늘 완료되지 않은 알람 중 가장 최근 것.
  /// (9:10·9:15 두 알람이면 9:11 아멘 → 9:10, 9:16 아멘 → 9:15.)
  static Future<String?> _inferJustFiredAlarmId() async {
    final alarms = await AlarmStore.loadAlarms();
    final now = DateTime.now();
    String? bestId;
    DateTime? bestAt;
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      if (!alarm.weekdays.contains(now.weekday)) continue;
      final at = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.hour,
        alarm.minute,
      );
      if (at.isAfter(now)) continue;
      // 3시간 상한 — 몇 시간 전에 무시된 알람이 '방금 울린 알람'으로
      // 추론되어 오도장을 만드는 것 방지.
      if (now.difference(at) > const Duration(hours: 3)) continue;
      if (await AlarmSessionService.instance.isAlarmCompletedToday(alarm.id)) {
        continue;
      }
      if (bestAt == null || at.isAfter(bestAt)) {
        bestId = alarm.id;
        bestAt = at;
      }
    }
    return bestId;
  }

  /// Speech recognition switches the AVAudioSession to .playAndRecord, which
  /// re-introduces Silent-switch sensitivity. Re-arm so the next alarm still
  /// overrides Silent mode.
  static Future<void> _rearmSilentLoopForNextAlarm() async {
    final morningOn = await AlarmPreferences.isEnabled();
    final eveningOn = await AlarmPreferences.isEveningEnabled();
    if (morningOn || eveningOn) {
      await AlarmSoundService.instance.armSilentLoop();
    }
  }

  /// User started prayer on a live alarm — pause in-app alarm loop (STT uses mic).
  static Future<void> onPrayerScreenOpened(String slot) async {
    await AlarmSoundService.instance.stop();
    debugPrint(
      'AlarmPersistence: $slot prayer screen opened — alarm sound paused',
    );
  }
}
