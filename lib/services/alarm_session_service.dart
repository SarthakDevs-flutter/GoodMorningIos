import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:alarm/alarm.dart' as alarm_pkg;

import 'alarm_notification_service.dart';
import 'alarm_preferences.dart';
import 'alarm_schedule_helper.dart';
import 'native_alarm_service.dart';
import 'alarm_store.dart';

/// Live alarm UI phase — used to avoid re-firing while user is praying.
enum LiveAlarmUiPhase { ringing, listening, success }

/// Tracks whether today's morning/evening alarm must be completed before the app unlocks.
class AlarmSessionService {
  AlarmSessionService._();

  static final AlarmSessionService instance = AlarmSessionService._();

  bool _blockingUiVisible = false;
  LiveAlarmUiPhase _liveAlarmUiPhase = LiveAlarmUiPhase.ringing;
  bool _isSetupScreenActive = false;

  bool get isBlockingUiVisible => _blockingUiVisible;

  LiveAlarmUiPhase get liveAlarmUiPhase => _liveAlarmUiPhase;

  bool get isSetupScreenActive => _isSetupScreenActive;

  void setBlockingUiVisible(bool visible) {
    _blockingUiVisible = visible;
  }

  void setLiveAlarmUiPhase(LiveAlarmUiPhase phase) {
    _liveAlarmUiPhase = phase;
  }

  void setSetupScreenActive(bool active) {
    _isSetupScreenActive = active;
    debugPrint('[ALARM] setSetupScreenActive: $active');
  }

  static const _morningCompletedDateKey = 'morning_alarm_completed_date';
  static const _morningActiveDateKey = 'morning_alarm_active_date';
  static const _morningFiredDateKey = 'morning_alarm_fired_date';
  // 지금 울리고 있는(또는 미션 중인) 알람의 id — 완료 처리 때 사용.
  static const _morningActiveAlarmIdKey = 'morning_alarm_active_alarm_id';
  // 알람별 완료: morning_alarm_completed_<id>_date = yyyy-MM-dd
  static const _perAlarmCompletedPrefix = 'morning_alarm_completed_';
  static const _perAlarmCompletedSuffix = '_date';
  static const _eveningCompletedDateKey = 'evening_alarm_completed_date';
  static const _eveningActiveDateKey = 'evening_alarm_active_date';
  static const _eveningFiredDateKey = 'evening_alarm_fired_date';

  static String _todayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Writes the "morning session is active" stamps only — no side effects
  /// (no proactive cancellation). Kept separate so the fire-time conflict gate
  /// can *claim* the session atomically inside [_conflictLock] before releasing
  /// the lock, closing the window where two alarms firing in the same instant
  /// both pass the conflict check and start overlapping sessions.
  Future<void> _writeMorningActiveStamp({String? alarmId}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    await prefs.setString(_morningActiveDateKey, today);
    await prefs.setString(_morningFiredDateKey, today);
    if (alarmId != null && alarmId.isNotEmpty) {
      await prefs.setString(_morningActiveAlarmIdKey, alarmId);
    }
  }

  Future<void> activateMorningAlarmSession({String? alarmId}) async {
    await _writeMorningActiveStamp(alarmId: alarmId);
    await proactivelyCancelUpcomingAlarms();
  }

  /// 지금 세션의 알람 id (없으면 null).
  Future<String?> activeAlarmId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_morningActiveAlarmIdKey);
  }

  /// [alarmId] 알람이 오늘 미션을 완료했는지.
  Future<bool> isAlarmCompletedToday(String? alarmId) async {
    if (alarmId == null || alarmId.isEmpty) {
      return hasCompletedMorningToday();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
          '$_perAlarmCompletedPrefix$alarmId$_perAlarmCompletedSuffix',
        ) ==
        _todayKey(DateTime.now());
  }

  /// Evening analog of [_writeMorningActiveStamp] — stamps only, no side effects.
  Future<void> _writeEveningActiveStamp() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    await prefs.setString(_eveningActiveDateKey, today);
    await prefs.setString(_eveningFiredDateKey, today);
  }

  Future<void> activateEveningAlarmSession() async {
    await _writeEveningActiveStamp();
    await proactivelyCancelUpcomingAlarms();
  }

  Future<void> markMorningCompleted({String? alarmId}) async {
    final prefs = await SharedPreferences.getInstance();
    // 도장 날짜는 '아멘 시각'이 아니라 '울린 날'(fired date) — 23:55 알람을
    // 자정 넘겨 아멘하면 다음날 것으로 찍혀 그날 알람이 선완료되던 결함.
    final firedDate = prefs.getString(_morningFiredDateKey);
    final stampDate = (firedDate != null && firedDate.isNotEmpty)
        ? firedDate
        : _todayKey(DateTime.now());
    // 하루 단위 완료(연속 기록·표시용) + 알람별 완료를 함께 찍는다.
    await prefs.setString(_morningCompletedDateKey, stampDate);
    final id = alarmId ?? prefs.getString(_morningActiveAlarmIdKey);
    if (id != null && id.isNotEmpty) {
      await prefs.setString(
        '$_perAlarmCompletedPrefix$id$_perAlarmCompletedSuffix',
        stampDate,
      );
    }
    await prefs.remove(_morningActiveDateKey);
    await prefs.remove(_morningFiredDateKey);
    await prefs.remove(_morningActiveAlarmIdKey);
  }

  /// 명시적 재예약(설정 화면 저장) 시 이전에 '방치된'(아멘 없이 이탈한)
  /// 세션의 잔재만 지운다. 완료 도장(_morningCompletedDateKey·알람별 도장)은
  /// 절대 건드리지 않아 유령 부활을 막으면서, 미래로 예약된 알람이 방치된
  /// 과거 세션의 active/fired 날짜 때문에 즉시 재잠금되는 것을 막는다.
  Future<void> clearAbandonedMorningSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_morningActiveDateKey);
    await prefs.remove(_morningFiredDateKey);
    await prefs.remove(_morningActiveAlarmIdKey);
  }

  Future<void> markAlarmCompletedToday(String alarmId) async {
    if (alarmId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final firedDate = prefs.getString(_morningFiredDateKey);
    final stampDate = (firedDate != null && firedDate.isNotEmpty)
        ? firedDate
        : _todayKey(DateTime.now());
    await prefs.setString(
      '$_perAlarmCompletedPrefix$alarmId$_perAlarmCompletedSuffix',
      stampDate,
    );
  }

  /// [onlyAlarmIds]가 주어지면 그 알람들의 오늘 도장만 지운다 — 재테스트
  /// 저장이 이미 완료한 다른 알람의 도장까지 지우던 결함의 수리.
  Future<void> clearMorningCompleted({Set<String>? onlyAlarmIds}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_morningCompletedDateKey);
    if (onlyAlarmIds != null) {
      for (final id in onlyAlarmIds) {
        await prefs.remove('$_perAlarmCompletedPrefix$id$_perAlarmCompletedSuffix');
      }
    } else {
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_perAlarmCompletedPrefix) &&
            key.endsWith(_perAlarmCompletedSuffix) &&
            key != _morningCompletedDateKey) {
          await prefs.remove(key);
        }
      }
    }
    // 동일 날짜에 재테스트 시, 이전 세션의 잔재(active/fired date)를 함께
    // 지워야 리스크(워치독/잠금)가 미래(rescheduled) 시각 전에 오발화/오잠금하지 않는다.
    await prefs.remove(_morningActiveDateKey);
    await prefs.remove(_morningFiredDateKey);
    await prefs.remove(_morningActiveAlarmIdKey);
  }

  Future<void> markEveningCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    // 도장 날짜는 '울린 날' — 자정 넘긴 아멘이 새 날짜로 찍히면 그날 저녁
    // 잠금·재예약이 하루 밀린다(아침과 동일 원칙).
    final firedDate = prefs.getString(_eveningFiredDateKey);
    final stampDate = (firedDate != null && firedDate.isNotEmpty)
        ? firedDate
        : _todayKey(DateTime.now());
    await prefs.setString(_eveningCompletedDateKey, stampDate);
    await prefs.remove(_eveningActiveDateKey);
    await prefs.remove(_eveningFiredDateKey);
  }

  Future<void> clearEveningCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eveningCompletedDateKey);
    await prefs.remove(_eveningActiveDateKey);
    await prefs.remove(_eveningFiredDateKey);
  }

  Future<bool> hasCompletedMorningToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_morningCompletedDateKey) ==
        _todayKey(DateTime.now());
  }

  Future<bool> hasActiveMorningSessionToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    return prefs.getString(_morningActiveDateKey) == today ||
        prefs.getString(_morningFiredDateKey) == today;
  }

  Future<bool> hasCompletedEveningToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_eveningCompletedDateKey) ==
        _todayKey(DateTime.now());
  }

  /// After today's alarm time, morning prayer must be finished to dismiss the alarm.
  Future<bool> isMorningCompletionRequired() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_morningActiveAlarmIdKey);
    if (activeId != null && activeId.isNotEmpty) {
      if (!await isAlarmCompletedToday(activeId)) {
        return true;
      }
    }

    if (!await AlarmPreferences.isEnabled()) return false;

    if (!kIsWeb && Platform.isAndroid) {
      return false;
    }

    // AlarmKit(iOS 26+): 네이티브가 예약 때 저장한 '다음 울림 시각'으로 판정.
    // 그 시각이 오늘이고 이미 지났는데 미완료면 = 실제 울림을 무시한 것 → 잠금.
    // 미래라면(오늘 시간이 지난 뒤 설정/토글만 한 알람은 다음 울림이 내일로
    // 저장된다) 울린 적이 없으므로 잠그지 않는다 — 설정 직후 미션이 뜨던 버그의
    // 원인이던 '설정된 시각만 보고 추측' 로직을 대체한다.
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      final nextFire = await NativeAlarmService.morningNextFireTime();
      if (nextFire == null) return false;
      final firedToday =
          nextFire.year == now.year &&
          nextFire.month == now.month &&
          nextFire.day == now.day &&
          !now.isBefore(nextFire);
      if (!firedToday) return false;
    }

    // Only lock if some enabled morning alarm's occurrence today has genuinely
    // passed and isn't completed. A future-scheduled alarm (e.g. 12:05 saved at
    // 12:00) must never lock, even if a stale past epoch lingers.
    return await _hasPassedUnfinishedMorningAlarmToday(now);
  }

  /// After today's evening alarm time, blessing prayer must be finished.
  Future<bool> isEveningCompletionRequired() async {
    if (!await AlarmPreferences.isEveningEnabled()) return false;
    if (await hasCompletedEveningToday()) return false;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _todayKey(now);
    // 오늘 이미 시작/발화한 저녁 세션은 플랫폼 불문 잠금 유지 — 리싱크가
    // epoch를 내일로 롤려도 미션이 증발하지 않는다(아침 activeToday와 대칭).
    if (prefs.getString(_eveningActiveDateKey) == today ||
        prefs.getString(_eveningFiredDateKey) == today) {
      return true;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return false;
    }

    // AlarmKit(iOS 26+): 아침과 대칭 — 네이티브에 저장된 '다음 저녁 발화'가
    // 오늘이고 이미 지났을 때만 잠근다. 시각 추측 방식은 '시각 지난 뒤
    // 켜면 울린 적 없는 미션이 강제로 뜨는' 유령을 만들었다(아침에서
    // 고친 버그의 저녁판).
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      final nextFire = await NativeAlarmService.eveningNextFireTime();
      if (nextFire == null) return false;
      final firedToday =
          nextFire.year == now.year &&
          nextFire.month == now.month &&
          nextFire.day == now.day &&
          !now.isBefore(nextFire);
      if (!firedToday) return false;
      // Same stale-epoch guard as the morning path: only lock if today's
      // evening time has actually passed (future blessing must never lock).
      final hour = await AlarmPreferences.getEveningHour();
      final minute = await AlarmPreferences.getEveningMinute();
      final occ = DateTime(now.year, now.month, now.day, hour, minute);
      return !occ.isAfter(now);
    }

    final hour = await AlarmPreferences.getEveningHour();
    final minute = await AlarmPreferences.getEveningMinute();
    final alarmToday = DateTime(now.year, now.month, now.day, hour, minute);

    return !now.isBefore(alarmToday);
  }

  /// True if some enabled morning alarm's scheduled time *today* has already
  /// passed and its mission isn't completed — i.e. a real, missed live alarm
  /// that should lock the app. Used to reject a stale native next-fire epoch.
  Future<bool> _hasPassedUnfinishedMorningAlarmToday(DateTime now) async {
    final alarms = await AlarmStore.loadAlarms();
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      if (!alarm.weekdays.contains(now.weekday)) continue;
      final occ = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.hour,
        alarm.minute,
      );
      if (occ.isAfter(now)) continue; // still upcoming today — no reason to lock
      if (await isAlarmCompletedToday(alarm.id)) continue;
      return true;
    }
    return false;
  }

  /// True when a morning trigger for [alarmId] arrives *before* the alarm's own
  /// scheduled time today (with a small grace) — a premature/phantom fire, e.g.
  /// a stale native "missed-fire" promotion for an alarm that hasn't rung yet.
  /// Such a trigger must be ignored so a future alarm never opens its mission
  /// early. Returns false for unknown/disabled alarms and for occurrences that
  /// are not scheduled today (so genuine and late fires are never blocked).
  Future<bool> isMorningTriggerPremature(String? alarmId) async {
    if (alarmId == null || alarmId.isEmpty) return false;
    final alarms = await AlarmStore.loadAlarms();
    MorningAlarm? alarm;
    for (final a in alarms) {
      if (a.id == alarmId) {
        alarm = a;
        break;
      }
    }
    if (alarm == null || !alarm.enabled) return false;
    final now = DateTime.now();
    if (!alarm.weekdays.contains(now.weekday)) return false;
    final occ = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );
    // 90s grace: a genuine alarm may be delivered a moment early; only a clearly
    // future scheduled time (minutes away) counts as premature.
    return occ.isAfter(now.add(const Duration(seconds: 30)));
  }

  /// The authoritative "may a morning mission open right now?" check, validated
  /// against the real alarm schedule — robust to stale/phantom triggers whose
  /// [alarmId] no longer exists (e.g. a leftover native pending mission for a
  /// since-deleted alarm) or whose time hasn't arrived.
  ///
  /// - Known alarm: due once its scheduled minute has (nearly) arrived today.
  /// - Null / unknown / deleted id: due only if *some* enabled alarm's
  ///   occurrence today has genuinely passed and isn't completed.
  ///
  /// A future-scheduled alarm (e.g. 12:05 saved at 12:00) is never "due", so
  /// saving it can never pop the mission open early.
  Future<bool> isMorningMissionDueNow(String? alarmId) async {
    final now = DateTime.now();
    final alarms = await AlarmStore.loadAlarms();
    if (alarmId != null && alarmId.isNotEmpty) {
      for (final a in alarms) {
        if (a.id != alarmId) continue;
        if (!a.enabled || !a.weekdays.contains(now.weekday)) return false;
        final occ = DateTime(now.year, now.month, now.day, a.hour, a.minute);
        // Small grace so a slightly-early native delivery still counts as due.
        return !occ.isAfter(now.add(const Duration(seconds: 30)));
      }
      // id not found → stale/deleted; fall through to the schedule-wide check.
    }
    for (final a in alarms) {
      if (!a.enabled || !a.weekdays.contains(now.weekday)) continue;
      final occ = DateTime(now.year, now.month, now.day, a.hour, a.minute);
      if (occ.isAfter(now)) continue;
      if (await isAlarmCompletedToday(a.id)) continue;
      return true;
    }
    return false;
  }

  /// Locks the app after today's alarm time until prayer is completed.
  /// Time-based so iOS swipe-to-dismiss on the notification still locks the app.
  Future<bool> isMorningAppLocked() => isMorningCompletionRequired();

  /// Locks the app after today's evening alarm time until prayer is completed.
  /// Time-based so iOS swipe-to-dismiss on the notification still locks the app.
  Future<bool> isEveningAppLocked() => isEveningCompletionRequired();

  Future<bool> hasActiveEveningSessionToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    return prefs.getString(_eveningActiveDateKey) == today ||
        prefs.getString(_eveningFiredDateKey) == today;
  }

  Future<bool> isAnyAlarmSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_morningActiveAlarmIdKey);
    bool morningActive = false;
    if (activeId != null && activeId.isNotEmpty) {
      if (await hasActiveMorningSessionToday() && !await isAlarmCompletedToday(activeId)) {
        morningActive = true;
      }
    }
    if (morningActive) return true;
    final eveningActive = await hasActiveEveningSessionToday() && !await hasCompletedEveningToday();
    return eveningActive;
  }

  final _conflictLock = Lock();

  /// Fire-time gate enforcing the Single Active Alarm policy. Runs under
  /// [_conflictLock] so the whole decision — *and* the claiming of a new session
  /// — is atomic: two alarms firing in the same instant can never both proceed.
  ///
  /// Returns `true` when the incoming trigger must be **skipped** (another
  /// mission is already in progress, or this occurrence is already finished);
  /// in that case it performs every skip action (stamp the occurrence completed,
  /// stop the native alert + retry ladder, reschedule the evening to tomorrow).
  ///
  /// Returns `false` when the trigger may proceed. Before returning `false` for
  /// a brand-new session it **claims** that session by stamping the active
  /// date/id, so a racing second alarm sees the claim on its own pass and skips.
  Future<bool> checkAndHandleConflict(String payload, {String? alarmId}) async {
    return _conflictLock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final isMorning = payload == AlarmNotificationService.morningAlarmPayload;
      final isEvening = payload == AlarmNotificationService.eveningAlarmPayload;

      final activeId = prefs.getString(_morningActiveAlarmIdKey);
      final isMorningActive = activeId != null &&
          activeId.isNotEmpty &&
          (prefs.getString(_morningActiveDateKey) == _todayKey(DateTime.now()) ||
           prefs.getString(_morningFiredDateKey) == _todayKey(DateTime.now())) &&
          !await isAlarmCompletedToday(activeId);
      final isEveningActive = await hasActiveEveningSessionToday() &&
          !await hasCompletedEveningToday();

      if (isMorning) {
        // Reject a premature/phantom trigger for an alarm whose scheduled time
        // today hasn't arrived yet (e.g. a stale native missed-fire promotion).
        // Ignore it WITHOUT stamping completed or stopping the alert, so the
        // alarm still rings normally at its real time.
        if (await isMorningTriggerPremature(alarmId)) {
          debugPrint('[CONFLICT] Ignoring premature morning trigger ($alarmId) — its scheduled time today has not arrived.');
          return true;
        }
        bool shouldSkip = false;
        if (isEveningActive) {
          // An evening session is live → only one alarm at a time.
          shouldSkip = true;
        } else if (isMorningActive) {
          // A morning session is live. Skip unless this *is* the active alarm
          // re-firing (a retry / persistent re-fire keeps the same session).
          if (alarmId != null && alarmId.isNotEmpty && alarmId != activeId) {
            shouldSkip = true;
          }
        } else if (alarmId != null &&
            alarmId.isNotEmpty &&
            await isAlarmCompletedToday(alarmId)) {
          // No session is active, but this specific alarm already finished/was
          // skipped today. Its occurrence is done — a stray native retry must
          // not start a fresh session for it (it fires again on its next day).
          shouldSkip = true;
        }

        if (shouldSkip) {
          debugPrint('[CONFLICT] Skipping morning alarm trigger ($alarmId) because another mission is in progress or it is already done today.');
          if (alarmId != null && alarmId.isNotEmpty) {
            await markAlarmCompletedToday(alarmId);
            await NativeAlarmService.markMorningMissionCompleted(alarmId: alarmId);
          }
          await NativeAlarmService.stopMorningAlarmKitAlert();
          try {
            await alarm_pkg.Alarm.stop(100001);
          } catch (e) {
            debugPrint('[CONFLICT] Failed to stop morning package alarm: $e');
          }
          await AlarmNotificationService.instance.cancelMorningAlarm();
          return true;
        }

        // No conflict → atomically claim this morning alarm as the one active
        // session (unless it already is) so a racing second alarm skips.
        if (!isMorningActive) {
          await _writeMorningActiveStamp(alarmId: alarmId);
        }
        return false;
      } else if (isEvening) {
        if (isMorningActive) {
          debugPrint('[CONFLICT] Skipping evening alarm trigger because morning mission is in progress.');
          await markEveningCompleted();
          await NativeAlarmService.markEveningMissionCompleted();
          await NativeAlarmService.stopEveningAlarmKitAlert();
          try {
            await alarm_pkg.Alarm.stop(100002);
          } catch (e) {
            debugPrint('[CONFLICT] Failed to stop evening package alarm: $e');
          }
          await AlarmNotificationService.instance.cancelEveningAlarm();

          // Reschedule the evening alarm to tomorrow immediately so next recurrence works.
          if (await AlarmPreferences.isEveningEnabled()) {
            final eveningHour = await AlarmPreferences.getEveningHour();
            final eveningMinute = await AlarmPreferences.getEveningMinute();
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
            if (!kIsWeb && Platform.isAndroid) {
              await AlarmScheduleHelper.rearmEveningPackageAlarm(forceNextFireAt: tomorrowEvening);
            }
          }
          return true;
        }

        if (await hasCompletedEveningToday()) {
          // Evening blessing already finished today — a stray retry must not
          // reopen it. It fires again on its next daily recurrence.
          debugPrint('[CONFLICT] Skipping evening alarm trigger because it is already completed today.');
          await NativeAlarmService.markEveningMissionCompleted();
          await NativeAlarmService.stopEveningAlarmKitAlert();
          try {
            await alarm_pkg.Alarm.stop(100002);
          } catch (e) {
            debugPrint('[CONFLICT] Failed to stop evening package alarm: $e');
          }
          await AlarmNotificationService.instance.cancelEveningAlarm();
          return true;
        }

        // No conflict → claim the evening session atomically (idempotent if a
        // re-fire of the same blessing already claimed it).
        if (!isEveningActive) {
          await _writeEveningActiveStamp();
        }
        return false;
      }
      return false;
    });
  }

  /// After a session ends (Amen), the evening blessing may have been pushed to
  /// *tomorrow* by [proactivelyCancelUpcomingAlarms] when the session started.
  /// If the blessing's time today has not yet passed and it is not completed,
  /// restore it for **today** so it still fires normally — the case where the
  /// session ended before the blessing's scheduled time (spec Scenario 2:
  /// "execute normally because there is no active alarm anymore").
  Future<void> rearmEveningForTodayIfUpcoming() async {
    if (!await AlarmPreferences.isEveningEnabled()) return;
    if (await hasCompletedEveningToday()) return;
    // If an evening session is somehow still live, leave its schedule alone.
    if (await hasActiveEveningSessionToday()) return;

    final now = DateTime.now();
    final eveningHour = await AlarmPreferences.getEveningHour();
    final eveningMinute = await AlarmPreferences.getEveningMinute();
    final todayEvening =
        DateTime(now.year, now.month, now.day, eveningHour, eveningMinute);
    // Only restore when the blessing is still upcoming today. If its time
    // already passed during the (now-ended) session, it stays skipped and the
    // proactively-armed tomorrow occurrence is correct.
    if (!todayEvening.isAfter(now)) return;

    debugPrint(
      '[CONFLICT] Session ended before the evening blessing — re-arming it for '
      'today at $eveningHour:$eveningMinute.',
    );
    // Primary schedule: the native AlarmKit occurrence for today.
    await NativeAlarmService.scheduleEveningAlarmKit(
      hour: eveningHour,
      minute: eveningMinute,
      nextFireAt: todayEvening,
    );
    // Secondary delivery net — restore the full local notification set
    // (main notification + repeat burst + backstop) that was cancelled when
    // proactivelyCancelUpcomingAlarms() ran at session start.
    try {
      // Restores the main eveningAlarmId notification and its repeat burst.
      await AlarmNotificationService.instance.scheduleEveningAlarm(
        hour: eveningHour,
        minute: eveningMinute,
      );
      await AlarmNotificationService.instance.scheduleEveningBackstop(
        fireAt: todayEvening,
      );
      if (!kIsWeb && Platform.isAndroid) {
        await AlarmScheduleHelper.rearmEveningPackageAlarm(forceNextFireAt: todayEvening);
      }
    } catch (e) {
      debugPrint('[CONFLICT] Failed to arm evening backstop for today: $e');
    }
  }

  /// Proactively cancels/unschedules any upcoming alarms for today natively
  /// when a session starts, so they don't fire or show notifications.
  Future<void> proactivelyCancelUpcomingAlarms() async {
    final now = DateTime.now();
    
    // 1. Proactively reschedule evening alarm to tomorrow if it is in the future today
    try {
      if (await AlarmPreferences.isEveningEnabled()) {
        final eveningHour = await AlarmPreferences.getEveningHour();
        final eveningMinute = await AlarmPreferences.getEveningMinute();
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          eveningHour,
          eveningMinute,
        );
        if (scheduledTime.isAfter(now)) {
          debugPrint('[CONFLICT] Proactively cancelling and rescheduling upcoming evening alarm to tomorrow.');
          final tomorrowEvening = scheduledTime.add(const Duration(days: 1));

          // Cancel ALL existing evening local notifications first (the daily-repeat
          // notification and its repeat burst would otherwise still fire today even
          // after the AlarmKit schedule is moved to tomorrow).
          await AlarmNotificationService.instance.cancelEveningAlarm();

          await NativeAlarmService.scheduleEveningAlarmKit(
            hour: eveningHour,
            minute: eveningMinute,
            nextFireAt: tomorrowEvening,
          );
          // Re-schedule the backstop for tomorrow only.
          await AlarmNotificationService.instance.scheduleEveningBackstop(
            fireAt: tomorrowEvening,
          );
          if (!kIsWeb && Platform.isAndroid) {
            await AlarmScheduleHelper.rearmEveningPackageAlarm(forceNextFireAt: tomorrowEvening);
          }
        }
      }
    } catch (e) {
      debugPrint('[CONFLICT] Failed to proactively reschedule evening alarm: $e');
    }

    // 2. Proactively cancel upcoming morning alarms natively
    // 다중 알람의 독립적인 동작을 위해 미래의 아침 알람들을 선제 취소하지 않습니다.
    // 각 알람의 충돌 및 중첩 회피 처리는 실제 울리는 시점(checkAndHandleConflict)에서 동적으로 판단합니다.
  }

  /// Sweeps all enabled alarms whose scheduled times for today are in the past,
  /// marking them completed/skipped so they won't trigger later as missed alarms.
  Future<void> skipPassedAlarmsDuringActiveSession() async {
    final now = DateTime.now();
    
    // 1. Check all morning alarms
    try {
      final alarms = await AlarmStore.loadAlarms();
      for (final alarm in alarms) {
        if (!alarm.enabled || !alarm.weekdays.contains(now.weekday)) continue;
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          alarm.hour,
          alarm.minute,
        );
        if (scheduledTime.isBefore(now)) {
          if (!await isAlarmCompletedToday(alarm.id)) {
            debugPrint('[CONFLICT] Sweeping/skipping passed morning alarm (${alarm.id}) scheduled at ${alarm.hour}:${alarm.minute}.');
            await markAlarmCompletedToday(alarm.id);
            await NativeAlarmService.markMorningMissionCompleted(alarmId: alarm.id);
            await NativeAlarmService.stopMorningAlarmKitAlert();
          }
        }
      }
    } catch (e) {
      debugPrint('[CONFLICT] Failed to sweep morning alarms: $e');
    }

    // 2. Check evening alarm
    try {
      if (await AlarmPreferences.isEveningEnabled()) {
        final eveningHour = await AlarmPreferences.getEveningHour();
        final eveningMinute = await AlarmPreferences.getEveningMinute();
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          eveningHour,
          eveningMinute,
        );
        if (scheduledTime.isBefore(now)) {
          if (!await hasCompletedEveningToday()) {
            debugPrint('[CONFLICT] Sweeping/skipping passed evening alarm scheduled at $eveningHour:$eveningMinute.');
            await markEveningCompleted();
            await NativeAlarmService.markEveningMissionCompleted();
            await NativeAlarmService.stopEveningAlarmKitAlert();
          }
        }
      }
    } catch (e) {
      debugPrint('[CONFLICT] Failed to sweep evening alarm: $e');
    }
  }
}
