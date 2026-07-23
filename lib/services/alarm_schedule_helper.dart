import 'dart:async';

import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:flutter/foundation.dart';

import 'alarm_fire_watchdog.dart';
import 'alarm_notification_service.dart';
import 'alarm_store.dart';
import 'alarm_preferences.dart';
import 'alarm_session_service.dart';
import 'alarm_sound_preferences.dart';
import 'alarm_sound_service.dart';
import 'native_alarm_service.dart';

/// Saves alarm preferences and keeps local notifications in sync.
class AlarmScheduleHelper {
  AlarmScheduleHelper._();

  // alarm package ids — kept distinct from flutter_local_notifications ids.
  static const _pkgMorningAlarmId = 100001;
  static const _pkgEveningAlarmId = 100002;

  static Future<void> ensureScheduled() async {
    await AlarmNotificationService.instance.scheduleFromPreferences();
    // Platform-native morning alarms own the audible path:
    // iOS 26+ uses AlarmKit, Android uses AlarmManager.setAlarmClock().
    // Clear legacy local notifications so only one engine can ring —
    // BEFORE the sync, so the AlarmKit backstop scheduled inside survives.
    if (await _shouldUseNativeMorningAlarm()) {
      await AlarmNotificationService.instance.clearLegacyEnginesOncePerLaunch(
        missionPending: await AlarmSessionService.instance
            .hasActiveMorningSessionToday(),
      );
    }
    await _syncAlarmPackage();
    if (!AlarmPreferences.eveningFeatureEnabled) {
      await _cancelEveningAlarms();
    }
    await _syncSilentLoop();
  }

  static Future<void> _cancelEveningAlarms() async {
    await AlarmNotificationService.instance.cancelEveningAlarm();
    await _cancelPackageAlarm(_pkgEveningAlarmId);
    await NativeAlarmService.cancelEvening();
  }

  /// Arm the silent background loop if any alarm is enabled (so it can
  /// override Silent / DnD / Airplane at fire time), disarm otherwise.
  static Future<void> _syncSilentLoop() async {
    final morningOn = await AlarmPreferences.isEnabled();
    final eveningOn = await AlarmPreferences.isEveningEnabled();
    if (morningOn || eveningOn) {
      await AlarmSoundService.instance.armSilentLoop();
    } else {
      await AlarmSoundService.instance.disarmSilentLoop();
    }
  }

  /// alarm package schedules one-shot alarms; rebuild from prefs every sync so
  /// the next occurrence is always armed (matches scheduleFromPreferences behaviour).
  static Future<void> _syncAlarmPackage() async {
    await _cancelPackageAlarm(_pkgMorningAlarmId);
    await _cancelPackageAlarm(_pkgEveningAlarmId);

    final morningOn = await AlarmPreferences.isEnabled();
    // Platform-native morning alarm is the audible engine.
    // Keep legacy alarm-package schedules off for the morning path.
    final useNativeMorningAlarm = await _shouldUseNativeMorningAlarm();
    final useAlarmKitForEvening = await _shouldUseAlarmKitForMorning();

    if (morningOn) {
      // 알람 목록 전체에서 (오늘 완료된 알람은 빼고) 다음 발화를 계산한다.
      final alarms = await AlarmStore.loadAlarms();
      final completedIds = <String>{};
      for (final alarm in alarms) {
        if (await AlarmSessionService.instance.isAlarmCompletedToday(
          alarm.id,
        )) {
          completedIds.add(alarm.id);
        }
      }
      final nextInfo = AlarmStore.nextOccurrenceInfo(
        alarms,
        DateTime.now(),
        isCompletedToday: completedIds.contains,
      );
      final next = nextInfo?.when;
      final nextHour = next?.hour ?? await AlarmPreferences.getHour();
      final nextMinute = next?.minute ?? await AlarmPreferences.getMinute();
      if (useNativeMorningAlarm) {
        if (useAlarmKitForEvening) {
          // iOS AlarmKit: 알람별 독립 등록의 조정 동기화 — 바뀐 알람만
          // 재등록되고 나머지는 데몬을 건드리지 않는다(변이 폭풍 제거).
          final counts = await NativeAlarmService.syncMorningAlarmList(
            alarms: alarms,
            nextAlarmId: nextInfo?.alarm.id,
            nextFireAt: nextInfo?.when,
          );
          if ((counts?['ownerRemoved'] ?? 0) > 0) {
            // 진행 중이던 미션의 주인 알람이 삭제/비활성됨 — 네이티브가
            // 미션 상태·추격을 걷었으니 Dart 소유인 알림 부대(융단·백스톱·
            // 강제종료 시리즈)도 마저 걷는다. 안 걷으면 '미션 하세요' 탭이
            // 계속 온다(실측 2026-07-16).
            await AlarmNotificationService.instance.cancelMorningAlarm();
            debugPrint('[ALARM] mission owner removed — morning squads cleared');
          }
        } else {
          // Android는 알람 목록으로 정확 예약(재부팅 포함).
          // 네이티브 예약 실패가 나머지 동기화를 중단시키면 안 된다.
          try {
            await NativeAlarmService.scheduleMorningAlarmKit(
              hour: nextHour,
              minute: nextMinute,
              weekdays: alarms.expand((a) => a.weekdays).toSet(),
              alarms: alarms,
              nextAlarmId: nextInfo?.alarm.id,
              nextFireAt: nextInfo?.when,
            );
          } catch (error) {
            debugPrint('[ALARM] morning native schedule failed: $error');
          }
        }
        // 융단은 여기(저장/앱열기)서 등록하지 않는다 — 매 조작마다 알림
        // 수십 건을 등록하던 것이 앱 전체를 느리게 한 원인. 울리는 순간
        // 게이트가 깔고, 아멘·보이는 참여가 걷는다.
        // 단 백스톱 6발은 예외(저녁과 대칭): mobiletimerd가 잠들면 정확히
        // 등록된 알람도 몇 분 늦게 몰아 배달된다(실측 2026-07-10: 7:51
        // 등록 3건을 07:56:13에 일괄 배달). SpringBoard 배달 알림은 그
        // 데몬과 독립이라 +45초부터 소리로 깨운다.
        if (useAlarmKitForEvening && nextInfo != null) {
          await AlarmNotificationService.instance.scheduleMorningBackstop(
            fireAt: nextInfo.when,
            soundName: nextInfo.alarm.soundName,
          );
        }
      } else {
        await _schedulePackageAlarm(
          alarmId: _pkgMorningAlarmId,
          hour: nextHour,
          minute: nextMinute,
          weekdays: next != null
              ? [next.weekday]
              : alarms.expand((a) => a.weekdays).toSet(),
          payload: AlarmNotificationService.morningAlarmPayload,
          title: 'God Morning',
          body: 'It is time to meet with the Lord.',
        );
      }
    } else {
      // morning disabled → cancel the AlarmKit weekly schedule entirely.
      await NativeAlarmService.cancelMorningAlarmKitSchedule();
      unawaited(AlarmNotificationService.instance.cancelMorningBackstop());
      unawaited(AlarmNotificationService.instance.cancelMorningRingCarpet());
    }

    final eveningOn = await AlarmPreferences.isEveningEnabled();
    if (eveningOn) {
      if (useAlarmKitForEvening) {
        final eveningHour = await AlarmPreferences.getEveningHour();
        final eveningMinute = await AlarmPreferences.getEveningMinute();
        // 오늘 이미 완료했으면 다음 발화는 내일 — 오늘 시각이 아직 미래여도
        // 사다리·백스톱이 오늘 다시 서면 안 된다.
        var nextEvening = _nextEveningOccurrence(eveningHour, eveningMinute);
        if (await AlarmSessionService.instance.hasCompletedEveningToday() &&
            nextEvening.day == DateTime.now().day) {
          nextEvening = nextEvening.add(const Duration(days: 1));
        }
        await NativeAlarmService.scheduleEveningAlarmKit(
          hour: eveningHour,
          minute: eveningMinute,
          nextFireAt: nextEvening,
        );
        // 데몬 사망 대비 저녁 백스톱(iOS 전용, 내부 가드).
        await AlarmNotificationService.instance.scheduleEveningBackstop(
          fireAt: nextEvening,
        );
      } else {
        await _schedulePackageAlarm(
          alarmId: _pkgEveningAlarmId,
          hour: await AlarmPreferences.getEveningHour(),
          minute: await AlarmPreferences.getEveningMinute(),
          weekdays: AlarmPreferences.defaultWeekdays,
          payload: AlarmNotificationService.eveningAlarmPayload,
          title: 'God Morning',
          body: 'Bless before you rest.',
        );
      }
    } else if (useAlarmKitForEvening) {
      await NativeAlarmService.cancelEvening();
      await AlarmNotificationService.instance.cancelEveningBackstop();
    }
  }

  /// Android(alarm 패키지) 저녁 재장전 — 1회성 예약이라 아멘 직후 다음
  /// 발생(내일)으로 직접 다시 걸어야 한다. 앱을 다시 열 때까지 다음 저녁이
  /// 통째로 침묵하던 구멍의 수리. iOS AlarmKit 경로에서는 호출하지 않는다.
  static Future<void> rearmEveningPackageAlarm() async {
    if (!await AlarmPreferences.isEveningEnabled()) return;
    await _schedulePackageAlarm(
      alarmId: _pkgEveningAlarmId,
      hour: await AlarmPreferences.getEveningHour(),
      minute: await AlarmPreferences.getEveningMinute(),
      weekdays: AlarmPreferences.defaultWeekdays,
      payload: AlarmNotificationService.eveningAlarmPayload,
      title: 'God Morning',
      body: 'Bless before you rest.',
    );
  }

  /// 다음 저녁 발생 시각(오늘 시간이 지났으면 내일).
  static DateTime _nextEveningOccurrence(int hour, int minute) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now)
        ? today
        : today.add(const Duration(days: 1));
  }

  /// True when AlarmKit should drive the morning alarm: iOS 26+ and authorized.
  /// requestAuthorization is idempotent — returns true immediately if already
  /// authorized, prompts once otherwise.
  static Future<bool> _shouldUseAlarmKitForMorning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    if (!await NativeAlarmService.isAvailable()) return false;
    return NativeAlarmService.requestAuthorization();
  }

  static Future<bool> _shouldUseNativeMorningAlarm() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    return _shouldUseAlarmKitForMorning();
  }

  // 잠금 체크(5초 감시 틱 포함)가 호출하므로 긍정 결과는 프로세스 수명 동안
  // 캐시한다 — requestAuthorization을 틱마다 반복 호출하지 않기 위함.
  static bool _nativeMorningConfirmed = false;

  static Future<bool> usesAlarmKitForMorning() async {
    if (_nativeMorningConfirmed) return true;
    final uses = await _shouldUseNativeMorningAlarm();
    if (uses) _nativeMorningConfirmed = true;
    return uses;
  }

  static Future<void> pauseScheduledAlarmsForPremiumLock() async {
    debugPrint('[PREMIUM] pausing scheduled alarms until premium unlock');
    await AlarmNotificationService.instance.cancelMorningAlarm();
    await AlarmNotificationService.instance.cancelEveningAlarm();
    await _cancelPackageAlarm(_pkgMorningAlarmId);
    await _cancelPackageAlarm(_pkgEveningAlarmId);
    await NativeAlarmService.cancelMorningAlarmKitSchedule();
    await NativeAlarmService.cancelEvening();
    await AlarmSoundService.instance.disarmSilentLoop();
  }

  /// Clear stale alarm-package schedules once iOS AlarmKit is the active engine.
  /// Old package alarms can briefly play the package's bundled default sound
  /// before the ringing callback has a chance to stop them.
  static Future<void> cancelLegacyPackageAlarmsIfAlarmKitAuthorized() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!await NativeAlarmService.isAvailable()) return;
    if (await NativeAlarmService.authorizationState() != 'authorized') return;

    await _cancelPackageAlarm(_pkgMorningAlarmId);
    await _cancelPackageAlarm(_pkgEveningAlarmId);
  }

  static Future<void> _schedulePackageAlarm({
    required int alarmId,
    required int hour,
    required int minute,
    Iterable<int>? weekdays,
    required String payload,
    required String title,
    required String body,
  }) async {
    final dt = _nextSelectedDateTime(hour, minute, weekdays);

    final soundFile = await AlarmSoundPreferences.alarmKitSoundFile();
    final assetAudioPath = 'assets/sounds/$soundFile';

    try {
      await alarm_pkg.Alarm.set(
        alarmSettings: alarm_pkg.AlarmSettings(
          id: alarmId,
          dateTime: dt,
          assetAudioPath: assetAudioPath,
          loopAudio: true,
          vibrate: true,
          warningNotificationOnKill: true,
          iOSBackgroundAudio: true,
          payload: payload,
          // volumeEnforced: true overrides low system volume at ring time.
          volumeSettings: const alarm_pkg.VolumeSettings.fixed(
            volume: 1.0,
            volumeEnforced: true,
          ),
          notificationSettings: alarm_pkg.NotificationSettings(
            title: title,
            body: body,
          ),
        ),
      );
      debugPrint(
        '[alarm-pkg] scheduled id=$alarmId for $dt (sound=$assetAudioPath)',
      );
      // Verify alarm package actually persisted the schedule.
      final scheduled = await alarm_pkg.Alarm.getAlarms();
      debugPrint(
        '[alarm-pkg] getAlarms() now: ${scheduled.length} alarm(s) — ${scheduled.map((a) => 'id=${a.id}@${a.dateTime}').join(', ')}',
      );
    } catch (error, st) {
      debugPrint('[alarm-pkg] schedule FAILED for id=$alarmId: $error\n$st');
    }
  }

  static Future<void> _cancelPackageAlarm(int alarmId) async {
    try {
      await alarm_pkg.Alarm.stop(alarmId);
    } catch (error) {
      debugPrint('[alarm-pkg] cancel id=$alarmId: $error');
    }
  }

  static int _clampHour(int hour) => hour.clamp(0, 23);

  static int _clampMinute(int minute) => minute.clamp(0, 59);

  static bool _hasEnabledFireLaterToday(
    List<MorningAlarm> alarms,
    DateTime now,
  ) {
    for (final alarm in alarms) {
      if (!alarm.enabled || !alarm.weekdays.contains(now.weekday)) continue;
      final todayFire = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.hour,
        alarm.minute,
      );
      if (todayFire.isAfter(now)) return true;
    }
    return false;
  }

  static bool _hasEveningFireLaterToday(int hour, int minute, DateTime now) {
    final todayFire = DateTime(now.year, now.month, now.day, hour, minute);
    return todayFire.isAfter(now);
  }

  static DateTime _nextSelectedDateTime(
    int hour,
    int minute,
    Iterable<int>? weekdays,
  ) {
    final now = DateTime.now();
    final selected = AlarmPreferences.normalizeWeekdays(weekdays).toSet();
    for (var offset = 0; offset < 8; offset++) {
      final day = now.add(Duration(days: offset));
      final dt = DateTime(day.year, day.month, day.day, hour, minute);
      if (selected.contains(dt.weekday) && dt.isAfter(now)) {
        return dt;
      }
    }
    final fallback = now.add(const Duration(days: 1));
    return DateTime(fallback.year, fallback.month, fallback.day, hour, minute);
  }

  /// 알람 목록 저장 + 전체 재예약 — 멀티 알람 UI의 저장 경로.
  static Future<void> saveAlarms(List<MorningAlarm> alarms) async {
    final anyEnabled = AlarmStore.anyEnabled(alarms);
    if (!anyEnabled &&
        await AlarmSessionService.instance.isMorningCompletionRequired()) {
      debugPrint('[ALARM] ignore disable until morning mission is completed');
      return;
    }
    await AlarmStore.saveAlarms(alarms);
    await AlarmPreferences.setEnabled(anyEnabled);
    AlarmFireWatchdog.instance.resetDaily();
    await AlarmNotificationService.instance.requestPermissions();
    final useNativeMorningAlarm = await _shouldUseNativeMorningAlarm();
    final allowSameDayRetest = _hasEnabledFireLaterToday(
      alarms,
      DateTime.now(),
    );
    if (anyEnabled && useNativeMorningAlarm && allowSameDayRetest) {
      // Explicit edits may happen after today's alarms were completed. Clear
      // the old native next-fire stamp before removing completion stamps, so
      // AlarmKit does not promote a stale, already-passed fire into a mission
      // when the app is opened again.
      await NativeAlarmService.cancelMorningAlarmKitSchedule();
    }
    if (anyEnabled && allowSameDayRetest) {
      // 명시적 저장이 오늘 아직 남은 알람/테스트 시간을 향할 때만 같은 날
      // 재테스트를 허용한다. 이미 완료하고 지난 알람을 삭제/토글하는 저장에서
      // 완료 스탬프를 지우면 앱 재실행 시 미션이 되살아난다.
      // 도장 클리어는 '오늘 아직 안 울린' 알람으로 한정 — 전부 지우면
      // 늦은 알람 B를 추가하는 저장이 이미 완료한 A의 도장까지 지워
      // A가 유령으로 되살아난다.
      final nowT = DateTime.now();
      final retestIds = alarms
          .where(
            (a) =>
                a.enabled &&
                a.weekdays.contains(nowT.weekday) &&
                DateTime(
                  nowT.year,
                  nowT.month,
                  nowT.day,
                  a.hour,
                  a.minute,
                ).isAfter(nowT),
          )
          .map((a) => a.id)
          .toSet();
      await AlarmSessionService.instance.clearMorningCompleted(
        onlyAlarmIds: retestIds,
      );
      await NativeAlarmService.clearMorningMissionCompleted(
        alarmIds: retestIds.toList(),
      );
    }
    if (anyEnabled && !useNativeMorningAlarm) {
      final next = AlarmStore.nextOccurrence(alarms, DateTime.now());
      if (next != null) {
        await AlarmNotificationService.instance.scheduleMorningAlarm(
          hour: next.hour,
          minute: next.minute,
          weekdays: [next.weekday],
        );
      }
    } else {
      await AlarmNotificationService.instance.cancelMorningAlarm();
    }
    await _syncAlarmPackage();
    await _syncSilentLoop();
  }

  /// 전체 알람 켜기/끄기 토글 — 각 알람의 시간·요일은 그대로 보존한다.
  static Future<void> setMorningEnabled(bool enabled) async {
    final alarms = await AlarmStore.loadAlarms();
    if (alarms.isEmpty) return;
    await saveAlarms([
      for (final alarm in alarms) alarm.copyWith(enabled: enabled),
    ]);
  }

  static Future<void> saveMorning({
    required int hour,
    required int minute,
    required bool enabled,
    Iterable<int>? weekdays,
    Map<int, int>? dayTimes,
    // 토글류 저장(켜기/끄기 등)에서 기존 요일별 시간을 지우지 않도록.
    bool preserveDayTimes = false,
  }) async {
    if (!enabled &&
        await AlarmSessionService.instance.isMorningCompletionRequired()) {
      debugPrint('[ALARM] ignore disable until morning mission is completed');
      return;
    }
    final h = _clampHour(hour);
    final m = _clampMinute(minute);
    final selectedWeekdays = weekdays == null
        ? await AlarmPreferences.getWeekdays()
        : AlarmPreferences.normalizeWeekdays(weekdays);
    // 요일별 시간이 오면 그것이 진실. preserveDayTimes면 저장된 요일별 시간을
    // 유지하고, 아니면(사용자가 시간을 직접 고른 경우) 단일 시간을 전 요일에 적용.
    final Map<int, int> effectiveDayTimes;
    if (dayTimes != null && dayTimes.isNotEmpty) {
      effectiveDayTimes = AlarmPreferences.sanitizeDayTimes(dayTimes);
    } else if (preserveDayTimes) {
      final existing = await AlarmPreferences.getDayTimes();
      effectiveDayTimes = {
        for (final day in selectedWeekdays) day: existing[day] ?? h * 60 + m,
      };
    } else {
      effectiveDayTimes = {for (final day in selectedWeekdays) day: h * 60 + m};
    }
    // 알람 목록도 같은 내용으로 재구성한다(레거시 단일-알람 저장 경로).
    final savedAlarms = AlarmStore.fromDayTimes(
      effectiveDayTimes,
      enabled: enabled,
    );
    await AlarmStore.saveAlarms(savedAlarms);
    await AlarmPreferences.saveDayTimes(effectiveDayTimes);
    await AlarmPreferences.setEnabled(enabled);
    AlarmFireWatchdog.instance.resetDaily();
    await AlarmNotificationService.instance.requestPermissions();
    final useNativeMorningAlarm = await _shouldUseNativeMorningAlarm();
    final allowSameDayRetest = _hasEnabledFireLaterToday(
      savedAlarms,
      DateTime.now(),
    );
    if (enabled && useNativeMorningAlarm && allowSameDayRetest) {
      // Clear stale native next-fire before wiping today's completion stamps.
      // Otherwise a passed AlarmKit fire can be converted back into a pending
      // mission during an explicit edit/re-save.
      await NativeAlarmService.cancelMorningAlarmKitSchedule();
    }
    if (enabled && allowSameDayRetest) {
      // Explicit user save/re-enable means a same-day alarm should be allowed
      // to ring again, even if Amen was completed earlier during testing.
      await AlarmSessionService.instance.clearMorningCompleted();
      await NativeAlarmService.clearMorningMissionCompleted();
    }
    // Platform-native morning alarms drive the live alarm path → don't create
    // the legacy notification/burst (would duplicate-fire). Only fallback uses it.
    if (enabled && !useNativeMorningAlarm) {
      // 시간이 요일마다 같으면 기존처럼 반복 예약, 다르면 다음 발화 1건 예약
      // (앱 실행/완료 시마다 다시 굴려 준다).
      final uniqueTimes = effectiveDayTimes.values.toSet();
      if (uniqueTimes.length == 1) {
        final t = uniqueTimes.first;
        await AlarmNotificationService.instance.scheduleMorningAlarm(
          hour: t ~/ 60,
          minute: t % 60,
          weekdays: effectiveDayTimes.keys,
        );
      } else {
        final next = AlarmPreferences.nextOccurrenceFor(
          effectiveDayTimes,
          DateTime.now(),
        );
        if (next != null) {
          await AlarmNotificationService.instance.scheduleMorningAlarm(
            hour: next.hour,
            minute: next.minute,
            weekdays: [next.weekday],
          );
        }
      }
    } else {
      await AlarmNotificationService.instance.cancelMorningAlarm();
    }
    await _syncAlarmPackage();
    await _syncSilentLoop();
  }

  /// 반환값: 저장 성공 여부 — 미션 완료 전 끄기는 false(호출부가 UI 복원).
  static Future<bool> saveEvening({
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    // 아침(saveAlarms)과 동일 원칙: 미션 완료 전에는 알람을 끌 수 없다 —
    // 이 가드가 없으면 저녁 미션이 토글 OFF로 우회된다(아멘-온리 위반).
    if (!enabled &&
        await AlarmSessionService.instance.isEveningCompletionRequired()) {
      debugPrint('[ALARM] evening disable blocked — mission pending');
      return false;
    }
    final h = _clampHour(hour);
    final m = _clampMinute(minute);
    await AlarmPreferences.saveEvening(hour: h, minute: m, enabled: enabled);
    if (!AlarmPreferences.eveningFeatureEnabled) {
      AlarmFireWatchdog.instance.resetDaily();
      await _cancelEveningAlarms();
      await _syncSilentLoop();
      return true;
    }
    AlarmFireWatchdog.instance.resetDaily();
    await AlarmNotificationService.instance.requestPermissions();
    final allowSameDayRetest = _hasEveningFireLaterToday(h, m, DateTime.now());
    if (enabled && allowSameDayRetest) {
      await AlarmSessionService.instance.clearEveningCompleted();
      await NativeAlarmService.clearEveningMissionCompleted();
    }
    final useAlarmKit = await _shouldUseAlarmKitForMorning();
    if (enabled && useAlarmKit) {
      await AlarmNotificationService.instance.cancelEveningAlarm();
      // nextFireAt 필수 — 시:분만 보내면 Swift가 '오늘 지난 시각'을 base로
      // 추측해 저장 직후 유령 사다리가 선다(아침에서 실측·수리된 클래스).
      var nextEvening = _nextEveningOccurrence(h, m);
      if (await AlarmSessionService.instance.hasCompletedEveningToday() &&
          nextEvening.day == DateTime.now().day) {
        nextEvening = nextEvening.add(const Duration(days: 1));
      }
      await NativeAlarmService.scheduleEveningAlarmKit(
        hour: h,
        minute: m,
        nextFireAt: nextEvening,
      );
    } else if (enabled) {
      await AlarmNotificationService.instance.scheduleEveningAlarm(
        hour: h,
        minute: m,
      );
    } else {
      await AlarmNotificationService.instance.cancelEveningAlarm();
      if (useAlarmKit) {
        await NativeAlarmService.cancelEvening();
      }
    }
    await _syncAlarmPackage();
    await _syncSilentLoop();
    return true;
  }

  static Future<void> saveAll({
    required int morningHour,
    required int morningMinute,
    required bool morningEnabled,
    Iterable<int>? morningWeekdays,
    required int eveningHour,
    required int eveningMinute,
    required bool eveningEnabled,
  }) async {
    final mh = _clampHour(morningHour);
    final mm = _clampMinute(morningMinute);
    final eh = _clampHour(eveningHour);
    final em = _clampMinute(eveningMinute);
    final selectedMorningWeekdays = morningWeekdays == null
        ? await AlarmPreferences.getWeekdays()
        : AlarmPreferences.normalizeWeekdays(morningWeekdays);
    await AlarmPreferences.save(
      hour: mh,
      minute: mm,
      enabled: morningEnabled,
      weekdays: selectedMorningWeekdays,
    );
    await AlarmPreferences.saveEvening(
      hour: eh,
      minute: em,
      enabled: eveningEnabled,
    );
    AlarmFireWatchdog.instance.resetDaily();
    await ensureScheduled();
  }

  /// Silence the morning live alarm (no evening, no full cancel/cleanup).
  /// Called when user starts the mission action — the alarm sound stops but
  /// rearmMorningLiveAlarmFromNow() must be called first to guarantee the
  /// alarm comes back if the mission doesn't finish.
  static Future<void> silenceMorningLiveAlarm() async {
    if (await _shouldUseAlarmKitForMorning()) {
      debugPrint('[alarm-pkg] skip silence; AlarmKit owns morning alarm');
      return;
    }
    try {
      await alarm_pkg.Alarm.stop(_pkgMorningAlarmId);
      debugPrint('[alarm-pkg] silenced morning live alarm');
    } catch (error) {
      debugPrint('[alarm-pkg] silence morning: $error');
    }
  }

  /// Re-arm the morning live alarm to ring [delay] from now. Used as a
  /// watchdog: user opens mission → arm a comeback alarm BEFORE silencing
  /// the current one, so even if the mission is abandoned the alarm returns.
  /// Same id as the original morning alarm — Amen's Alarm.stop will cancel it.
  static Future<void> rearmMorningLiveAlarmFromNow({
    required Duration delay,
  }) async {
    if (await _shouldUseAlarmKitForMorning()) {
      debugPrint(
        '[alarm-pkg] skip rearm; AlarmKit retry ladder owns morning alarm',
      );
      return;
    }
    final fireAt = DateTime.now().add(delay);
    final soundFile = await AlarmSoundPreferences.alarmKitSoundFile();
    final assetAudioPath = 'assets/sounds/$soundFile';

    try {
      await alarm_pkg.Alarm.set(
        alarmSettings: alarm_pkg.AlarmSettings(
          id: _pkgMorningAlarmId,
          dateTime: fireAt,
          assetAudioPath: assetAudioPath,
          loopAudio: true,
          vibrate: true,
          warningNotificationOnKill: true,
          iOSBackgroundAudio: true,
          payload: AlarmNotificationService.morningAlarmPayload,
          volumeSettings: const alarm_pkg.VolumeSettings.fixed(
            volume: 1.0,
            volumeEnforced: true,
          ),
          notificationSettings: const alarm_pkg.NotificationSettings(
            title: 'God Morning',
            body: 'It is time to meet with the Lord.',
          ),
        ),
      );
      debugPrint(
        '[alarm-pkg] rearmed morning live alarm for $fireAt (sound=$assetAudioPath)',
      );
    } catch (error) {
      debugPrint('[alarm-pkg] rearm morning: $error');
    }
  }
}
