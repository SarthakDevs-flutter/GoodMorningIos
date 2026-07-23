import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_preferences.dart';
import 'alarm_schedule_helper.dart';
import 'native_alarm_service.dart';

/// Live alarm UI phase — used to avoid re-firing while user is praying.
enum LiveAlarmUiPhase { ringing, listening, success }

/// Tracks whether today's morning/evening alarm must be completed before the app unlocks.
class AlarmSessionService {
  AlarmSessionService._();

  static final AlarmSessionService instance = AlarmSessionService._();

  bool _blockingUiVisible = false;
  LiveAlarmUiPhase _liveAlarmUiPhase = LiveAlarmUiPhase.ringing;

  bool get isBlockingUiVisible => _blockingUiVisible;

  LiveAlarmUiPhase get liveAlarmUiPhase => _liveAlarmUiPhase;

  void setBlockingUiVisible(bool visible) {
    _blockingUiVisible = visible;
  }

  void setLiveAlarmUiPhase(LiveAlarmUiPhase phase) {
    _liveAlarmUiPhase = phase;
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

  Future<void> activateMorningAlarmSession({String? alarmId}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    await prefs.setString(_morningActiveDateKey, today);
    await prefs.setString(_morningFiredDateKey, today);
    if (alarmId != null && alarmId.isNotEmpty) {
      await prefs.setString(_morningActiveAlarmIdKey, alarmId);
    }
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

  Future<void> activateEveningAlarmSession() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    await prefs.setString(_eveningActiveDateKey, today);
    await prefs.setString(_eveningFiredDateKey, today);
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

  /// [onlyAlarmIds]가 주어지면 그 알람들의 오늘 도장만 지운다 — 재테스트
  /// 저장이 이미 완료한 다른 알람의 도장까지 지우던 결함의 수리.
  Future<void> clearMorningCompleted({Set<String>? onlyAlarmIds}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_morningCompletedDateKey);
    if (onlyAlarmIds != null) {
      for (final id in onlyAlarmIds) {
        await prefs.remove('$_perAlarmCompletedPrefix$id$_perAlarmCompletedSuffix');
      }
      return;
    }
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_perAlarmCompletedPrefix) &&
          key.endsWith(_perAlarmCompletedSuffix) &&
          key != _morningCompletedDateKey) {
        await prefs.remove(key);
      }
    }
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
    if (await hasCompletedMorningToday()) return false;

    final now = DateTime.now();
    final activeToday = await hasActiveMorningSessionToday();
    if (activeToday) return true;

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
      return firedToday;
    }

    // 요일별 시간: 오늘 요일의 시간이 없으면 오늘은 알람이 없는 날.
    final minutes = await AlarmPreferences.minutesForWeekday(now.weekday);
    if (minutes == null) return false;
    final alarmToday = DateTime(
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );

    return !now.isBefore(alarmToday);
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
      return firedToday;
    }

    final hour = await AlarmPreferences.getEveningHour();
    final minute = await AlarmPreferences.getEveningMinute();
    final alarmToday = DateTime(now.year, now.month, now.day, hour, minute);

    return !now.isBefore(alarmToday);
  }

  /// Locks the app after today's alarm time until prayer is completed.
  /// Time-based so iOS swipe-to-dismiss on the notification still locks the app.
  Future<bool> isMorningAppLocked() => isMorningCompletionRequired();

  /// Locks the app after today's evening alarm time until prayer is completed.
  /// Time-based so iOS swipe-to-dismiss on the notification still locks the app.
  Future<bool> isEveningAppLocked() => isEveningCompletionRequired();
}
