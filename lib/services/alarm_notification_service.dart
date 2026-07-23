import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_preferences.dart';
import 'alarm_registry.dart';
import 'alarm_sound_preferences.dart';
import 'native_alarm_service.dart';

typedef NotificationTriggeredCallback = void Function(String payload);

class AlarmScheduleStatus {
  const AlarmScheduleStatus({
    required this.notificationsEnabled,
    required this.morningScheduled,
    required this.eveningScheduled,
    this.nextMorning,
    this.nextEvening,
  });

  final bool notificationsEnabled;
  final bool morningScheduled;
  final bool eveningScheduled;
  final DateTime? nextMorning;
  final DateTime? nextEvening;
}

/// flutter_local_notifications 로 아침·저녁 알람을 예약하는 클래스
class AlarmNotificationService {
  AlarmNotificationService._();

  static final AlarmNotificationService instance = AlarmNotificationService._();

  static const morningAlarmId = 1;
  static const eveningAlarmId = 2;
  static const morningRepeatBaseId = 1101;
  static const eveningRepeatBaseId = 1201;
  // Solo: only one alarm enabled — full 10-minute pressure.
  // Shared: both enabled — split to stay under iOS 64 pending limit.
  static const repeatBurstCountSolo = 60;
  static const repeatBurstCountShared = 30;
  static const repeatBurstIntervalSeconds = 10;
  static const testMorningAlarmId = 101;
  static const testEveningAlarmId = 102;
  static const morningAlarmPayload = 'morning_alarm';
  static const eveningAlarmPayload = 'evening_blessing_alarm';
  static const missionCategoryId = 'MISSION_CATEGORY';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationTriggeredCallback? _onNotificationTriggered;
  bool _initialized = false;

  Future<void> init({
    required NotificationTriggeredCallback onNotificationTriggered,
  }) async {
    if (_initialized) return;

    _onNotificationTriggered = onNotificationTriggered;

    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      notificationCategories: const [],
    );

    await _plugin.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (_isHandledPayload(payload)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onNotificationTriggered?.call(payload!);
        });
      }
    }
  }

  Future<bool> hasPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final settings = await iosPlugin?.checkPermissions();
      if (settings == null) return false;
      return settings.isEnabled &&
          settings.isAlertEnabled &&
          settings.isSoundEnabled;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsEnabled =
          await androidPlugin?.areNotificationsEnabled() ?? false;
      final exactAlarmsEnabled =
          await NativeAlarmService.androidCanScheduleExactAlarms();
      return notificationsEnabled && exactAlarmsEnabled;
    }

    return true;
  }

  /// Request alert + sound permissions. Returns true when alarms can ring.
  Future<bool> ensurePermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return requestPermissions();
    } else {
      return true;
    }
    return hasPermissions();
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      final exactAlarmGranted =
          await androidPlugin?.requestExactAlarmsPermission() ?? false;
      return granted && exactAlarmGranted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ensurePermissions();
    }

    return true;
  }

  /// 저장된 설정으로 아침·저녁 알람 모두 예약
  Future<AlarmScheduleStatus> scheduleFromPreferences() async {
    final permitted = await ensurePermissions();
    var morningScheduled = false;
    var eveningScheduled = false;
    DateTime? nextMorning;
    DateTime? nextEvening;

    if (permitted) {
      await _scheduleMorningFromPreferences();
      await _scheduleEveningFromPreferences();
      morningScheduled = await AlarmPreferences.isEnabled();
      eveningScheduled = await AlarmPreferences.isEveningEnabled();
      final slots = await AlarmRegistry.loadEnabledSlots();
      for (final slot in slots) {
        final next = slot.nextOccurrence(DateTime.now());
        debugPrint(
          '알람 등록: ${slot.label} ${AlarmPreferences.formatTime(slot.hour, slot.minute)} '
          '→ 다음 ${next.toString()}',
        );
        if (slot.id == 'morning') nextMorning = next;
        if (slot.id == 'evening') nextEvening = next;
      }
    } else {
      debugPrint('알람 예약 실패: 알림 권한 없음');
    }

    await _logPendingAlarms();
    return AlarmScheduleStatus(
      notificationsEnabled: permitted,
      morningScheduled: morningScheduled,
      eveningScheduled: eveningScheduled,
      nextMorning: nextMorning,
      nextEvening: nextEvening,
    );
  }

  DateTime nextInstanceOfTime(int hour, int minute, {Iterable<int>? weekdays}) {
    final scheduled = _nextInstanceOfTime(hour, minute, weekdays: weekdays);
    return DateTime(
      scheduled.year,
      scheduled.month,
      scheduled.day,
      scheduled.hour,
      scheduled.minute,
    );
  }

  Future<void> _logPendingAlarms() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint(
      '예약된 알림 ${pending.length}개: '
      '${pending.map((n) => '${n.id}@${n.title}').join(', ')}',
    );
  }

  Future<void> _scheduleMorningFromPreferences() async {
    if (await _shouldUseNativeMorningNotifications()) {
      // 전체 취소(~90발)는 실행당 1회(clearLegacyEnginesOncePerLaunch)로
      // 충분 — 저장마다 반복하면 채널이 폭주해 앱이 굼떠진다.
      debugPrint('[native-alarm] skip legacy morning notifications');
      return;
    }

    final enabled = await AlarmPreferences.isEnabled();
    if (!enabled) {
      await cancelMorningAlarm();
      return;
    }

    // 요일별 시간: 전 요일 동일하면 기존 반복 예약, 다르면 다음 발화 1건만
    // (앱 실행/완료 시마다 다시 예약된다).
    final dayTimes = await AlarmPreferences.getDayTimes();
    final uniqueTimes = dayTimes.values.toSet();
    if (uniqueTimes.length == 1) {
      final t = uniqueTimes.first;
      await scheduleMorningAlarm(
        hour: t ~/ 60,
        minute: t % 60,
        weekdays: dayTimes.keys,
      );
      return;
    }
    final next = AlarmPreferences.nextOccurrenceFor(dayTimes, DateTime.now());
    if (next == null) {
      await cancelMorningAlarm();
      return;
    }
    await scheduleMorningAlarm(
      hour: next.hour,
      minute: next.minute,
      weekdays: [next.weekday],
    );
  }

  Future<void> _scheduleEveningFromPreferences() async {
    if (await _shouldUseNativeMorningNotifications()) {
      // 위와 동일 — 1회 정리 원칙.
      debugPrint('[native-alarm] skip legacy evening notifications');
      return;
    }

    final enabled = await AlarmPreferences.isEveningEnabled();
    if (!enabled) {
      await cancelEveningAlarm();
      return;
    }

    final hour = await AlarmPreferences.getEveningHour();
    final minute = await AlarmPreferences.getEveningMinute();
    await scheduleEveningAlarm(hour: hour, minute: minute);
  }

  Future<void> scheduleMorningAlarm({
    required int hour,
    required int minute,
    Iterable<int>? weekdays,
  }) async {
    if (await _shouldUseNativeMorningNotifications()) {
      await cancelMorningAlarm();
      debugPrint(
        '[native-alarm] skip scheduleMorningAlarm legacy notification',
      );
      return;
    }

    if (!await ensurePermissions()) {
      debugPrint('아침 알람 예약 취소: 알림 권한 없음');
      return;
    }
    await cancelMorningAlarm();

    final scheduledTime = _nextInstanceOfTime(hour, minute, weekdays: weekdays);

    await _plugin.zonedSchedule(
      morningAlarmId,
      'God Morning',
      'It is time to meet with the Lord.',
      scheduledTime,
      await _morningNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          AlarmPreferences.normalizeWeekdays(weekdays).length == 7
          ? DateTimeComponents.time
          : null,
      payload: morningAlarmPayload,
    );

    final eveningOn = await AlarmPreferences.isEveningEnabled();
    await _scheduleRepeatBurst(
      baseId: morningRepeatBaseId,
      count: eveningOn ? repeatBurstCountShared : repeatBurstCountSolo,
      anchor: scheduledTime,
      title: 'God Morning',
      body: 'It is time to meet with the Lord.',
      details: await _morningNotificationDetails(),
      payload: morningAlarmPayload,
    );

    debugPrint(
      '아침 알람 예약: ${AlarmPreferences.formatTime(hour, minute)} → ${scheduledTime.toString()}',
    );
  }

  Future<void> _scheduleRepeatBurst({
    required int baseId,
    required int count,
    required tz.TZDateTime anchor,
    required String title,
    required String body,
    required NotificationDetails details,
    required String payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < count; i++) {
      final id = baseId + i;
      await _plugin.cancel(id);
      final fireTime = anchor.add(
        Duration(seconds: repeatBurstIntervalSeconds * (i + 1)),
      );
      if (!fireTime.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  /// Cancel up to the maximum possible burst size so historical schedules clear cleanly.
  /// 순차 await 60번은 미션 진입(STT 시작)을 수백 ms 지연시킨다 — 병렬로.
  Future<void> _cancelRepeatBurst(int baseId) async {
    await Future.wait([
      for (var i = 0; i < repeatBurstCountSolo; i++) _plugin.cancel(baseId + i),
    ]);
  }

  // 저장·앱열기마다 레거시 전체 취소(~150발)를 반복하던 것이 남은 굼뜸의
  // 원인 — 실행당 1회면 충분하다.
  // ⚠️ 범위는 '진짜 레거시 엔진'(메인 1·2, 테스트 101·102, 반복 버스트
  // 1101~/1201~)만. 3xxx 보호 계열(백스톱·융단·강제종료 시리즈)은 각자
  // 무장/해제 수명주기가 있으므로 여기서 절대 지우지 않는다 — 예전처럼
  // cancelMorning/EveningAlarm 전체를 부르면 미션 중 강제종료 후 재실행이
  // 강제종료 대비 40발을 통째로 삭제한다(실측 2026-07-10 10:26/10:42:
  // 재실행마다 'Removing pending' 수백 회 → 예약된 알림 0개).
  bool _legacyClearedThisLaunch = false;

  Future<void> clearLegacyEnginesOncePerLaunch({
    required bool missionPending,
  }) async {
    if (_legacyClearedThisLaunch) return;
    _legacyClearedThisLaunch = true;
    if (missionPending) return;
    await Future.wait([
      _plugin.cancel(morningAlarmId),
      _plugin.cancel(testMorningAlarmId),
      _plugin.cancel(eveningAlarmId),
      _plugin.cancel(testEveningAlarmId),
      _cancelRepeatBurst(morningRepeatBaseId),
      _cancelRepeatBurst(eveningRepeatBaseId),
    ]);
  }

  /// 미션 진입용 초경량 취소 — 예약된 적 없는 레거시 슬롯들에 취소를
  /// 난사하지 않는다(채널 폭주가 STT 시작·화면 반응을 늦추던 원인).
  /// 철저한 정리는 아멘의 cancelMorningAlarm이 담당한다.
  /// 백스톱 6발은 여기서 걷는다(저녁과 대칭) — 안 걷으면 발화 +45초부터
  /// 미션 위로 배너+소리가 떨어진다.
  Future<void> cancelMorningMainNotification() async {
    await Future.wait([
      _plugin.cancel(morningAlarmId),
      _plugin.cancel(testMorningAlarmId),
      cancelMorningBackstop(),
    ]);
  }

  Future<void> cancelMorningAlarm() async {
    await Future.wait([
      _plugin.cancel(morningAlarmId),
      _plugin.cancel(testMorningAlarmId),
      _cancelRepeatBurst(morningRepeatBaseId),
      cancelMorningBackstop(),
      cancelMorningAbandonBackstop(),
      // 저녁(cancelEveningAlarm)과 대칭 — 빠져 있으면 아멘 후 융단 잔여
      // 발이 유령으로 남는다.
      cancelMorningRingCarpet(),
    ]);
  }

  // ── iOS AlarmKit 백스톱 ──
  // 실측(2026-07-08): mobiletimerd 프로세스가 죽은 채(15:19~15:24, PID 교체)
  // 15:22 알람 3건이 저장소에 정확히 등록돼 있었는데도 무음으로 지나갔다.
  // 배달 엔진 자체가 죽으면 AlarmKit 안에서는 방어가 불가능하므로,
  // SpringBoard가 배달하는 로컬 알림(독립 프로세스)을 예비 경로로 심는다.
  // 슬롯 사이 시각(+45/+105/+165초)이라 정상 경로와 겹침을 최소화하고,
  // 미션 진입·아멘·재예약이 전부 cancelMorningAlarm()을 지나므로 정상
  // 흐름에서는 울리기 전에 조용히 사라진다.
  static const morningBackstopBaseId = 3001;
  // 6발 × 60초 = 발화 후 약 6분간 촘촘히 커버(AlarmKit 사다리는 +4분부터).
  static const morningBackstopCount = 6;
  static const morningBackstopFirstDelaySeconds = 45;
  static const morningBackstopIntervalSeconds = 60;

  Future<void> scheduleMorningBackstop({
    required DateTime fireAt,
    String? soundName,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelMorningBackstop();
    if (!await ensurePermissions()) {
      debugPrint('[BACKSTOP] skipped: no notification permission');
      return;
    }
    final details = await _morningBackstopDetails(soundName);
    final anchor = tz.TZDateTime.from(fireAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;
    for (var i = 0; i < morningBackstopCount; i++) {
      final fireTime = anchor.add(
        Duration(
          seconds:
              morningBackstopFirstDelaySeconds +
              morningBackstopIntervalSeconds * i,
        ),
      );
      if (!fireTime.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        morningBackstopBaseId + i,
        'God Morning',
        'It is time to meet with the Lord.',
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: morningAlarmPayload,
      );
      scheduled++;
    }
    debugPrint('[BACKSTOP] $scheduled shots from $fireAt (+45s/60s apart)');
  }

  Future<void> cancelMorningBackstop() async {
    await Future.wait([
      for (var i = 0; i < morningBackstopCount; i++) _plugin.cancel(morningBackstopBaseId + i),
    ]);
  }

  // ── 융단 재울림(예전 엔진의 부활) ──
  // 옛 빌드가 '끊기지 않던' 실체: 알람 시각부터 10초 간격 알림을 미리 깔아
  // 시스템(SpringBoard)이 배달했다 — 전원 버튼도 앱 사망도 못 막는다.
  // AlarmKit 이사 때 사라진 이 융단을 부활시킨다. 취소는 '화면을 실제로
  // 보는 참여'와 아멘에서만 — 미션이 잠금 뒤에서 열려도 융단은 계속된다.
  // iOS 대기 알림 한도(64) 안에서 45발×10초 = 7.5분; 그 뒤는 AlarmKit
  // 사다리(2분 간격)·추격(1분 간격)이 20분까지 잇는다.
  static const morningCarpetBaseId = 3401;
  static const morningCarpetCount = 24;
  static const morningCarpetIntervalSeconds = 10;

  Future<void> scheduleMorningRingCarpet({
    required DateTime anchor,
    String? soundName,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelMorningRingCarpet();
    if (!await ensurePermissions()) return;
    // 알림 소리는 30초 한도 — 알람별 소리도 발췌본으로 매핑(백스톱과 동일).
    final iosSound =
        (soundName != null && soundName.isNotEmpty)
        ? AlarmSoundPreferences.notificationSoundFileFor(soundName)
        : await AlarmSoundPreferences.iosNotificationSoundFile();
    // 포그라운드 무표시: 미션이 떠 있는 동안 도착한 발이 배너로 덮치지
    // 않게 한다(포그라운드 소리는 인앱 연속 루프 담당). 앱이 죽었거나
    // 백그라운드일 때의 배너+소리 배달은 이 플래그와 무관하게 정상.
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        // iOS 14+ 포그라운드 표시는 banner/list 키가 기준 — alert만 꺼서는
        // 초기화 기본값(true)이 살아 배너가 뜬다. 명시적으로 차단.
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
    final anchorTz = tz.TZDateTime.from(anchor, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    // 순차 등록 45회는 앱 열기·저장을 1~2초 얼린다 — 병렬로.
    final jobs = <Future<void>>[];
    for (var i = 0; i < morningCarpetCount; i++) {
      final fireTime = anchorTz.add(
        Duration(seconds: morningCarpetIntervalSeconds * (i + 1)),
      );
      if (!fireTime.isAfter(now)) continue;
      jobs.add(
        _plugin.zonedSchedule(
          morningCarpetBaseId + i,
          'God Morning',
          'It is time to meet with the Lord.',
          fireTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: morningAlarmPayload,
        ),
      );
    }
    await Future.wait(jobs);
    debugPrint('[CARPET] ${jobs.length} shots x10s from $anchor');
  }

  Future<void> cancelMorningRingCarpet() async {
    // 취소 상한은 과거 최대치(45발 시절)로 — 24로만 걷으면 3425~3445
    // 잔재가 영구히 대기 예산(64)을 갉아먹는다.
    await Future.wait([
      for (var i = 0; i < 45; i++) _plugin.cancel(morningCarpetBaseId + i),
    ]);
  }

  // ── 저녁 융단·이탈 시리즈 (아침과 동일 화력, 사용자 결정: 통일) ──
  static const eveningCarpetBaseId = 3601;
  static const eveningCarpetCount = 24;

  Future<void> scheduleEveningRingCarpet({required DateTime anchor}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelEveningRingCarpet();
    if (!await ensurePermissions()) return;
    final iosSound = await AlarmSoundPreferences.iosNotificationSoundFile();
    // 아침 융단과 동일: 포그라운드 무표시(미션 중 배너 차단).
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        // iOS 14+ 포그라운드 표시는 banner/list 키가 기준 — alert만 꺼서는
        // 초기화 기본값(true)이 살아 배너가 뜬다. 명시적으로 차단.
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
    final anchorTz = tz.TZDateTime.from(anchor, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    final jobs = <Future<void>>[];
    for (var i = 0; i < eveningCarpetCount; i++) {
      final fireTime = anchorTz.add(
        Duration(seconds: morningCarpetIntervalSeconds * (i + 1)),
      );
      if (!fireTime.isAfter(now)) continue;
      jobs.add(
        _plugin.zonedSchedule(
          eveningCarpetBaseId + i,
          'God Morning',
          'Bless before you rest.',
          fireTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: eveningAlarmPayload,
        ),
      );
    }
    await Future.wait(jobs);
    debugPrint('[CARPET] evening ${jobs.length} shots x10s');
  }

  Future<void> cancelEveningRingCarpet() async {
    await Future.wait([
      for (var i = 0; i < eveningCarpetCount; i++)
        _plugin.cancel(eveningCarpetBaseId + i),
    ]);
  }

  static const eveningAbandonBackstopBaseId = 3501;

  Future<void> scheduleEveningAbandonBackstop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelEveningAbandonBackstop();
    if (!await ensurePermissions()) return;
    const iosSound = _abandonShortSound;
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        // iOS 14+ 포그라운드 표시는 banner/list 키가 기준 — alert만 꺼서는
        // 초기화 기본값(true)이 살아 배너가 뜬다. 명시적으로 차단.
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    await Future.wait([
      for (var i = 0; i < morningAbandonBackstopCount; i++)
        _plugin.zonedSchedule(
          eveningAbandonBackstopBaseId + i,
          'God Morning',
          'Bless before you rest.',
          now.add(
            Duration(
              seconds: morningAbandonBackstopIntervalSeconds * (i + 1),
            ),
          ),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: eveningAlarmPayload,
        ),
    ]);
    debugPrint('[BACKSTOP] evening abandon series armed: 40x15s');
  }

  Future<void> cancelEveningAbandonBackstop() async {
    await Future.wait([
      for (var i = 0; i < morningAbandonBackstopCount; i++)
        _plugin.cancel(eveningAbandonBackstopBaseId + i),
    ]);
  }

  // 미션 이탈(강제종료 포함) 추격의 제2 경로. AlarmKit 추격은 이탈 '순간'
  // 등록을 시작하므로 강제종료가 프로세스를 죽이면 몇 발만 남는다(실측:
  // 딱 한 번 울리고 침묵). 이 시리즈는 미션 '시작' 때 미리 전부 등록하고
  // 포그라운드 표시를 꺼서(미션 중 무음) 앱이 죽거나 백그라운드일 때만
  // 들린다. 아멘·미션 재진입의 cancelMorningAlarm()이 자동 정리한다.
  static const morningAbandonBackstopBaseId = 3301;
  // 15초 간격 40발(10분). 30초 간격일 때 소리(최대 29.8초 파일)가 다음
  // 알림과 겹쳐 iOS가 한 번 걸러 소리를 건너뛰었다(체감 1분) — 간격을
  // 좁히는 대신 겹치지 않는 짧은 소리를 고정 사용한다.
  static const morningAbandonBackstopCount = 40;
  static const morningAbandonBackstopIntervalSeconds = 15;
  static const _abandonShortSound = 'god_morning_1.wav';

  Future<void> scheduleMorningAbandonBackstop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelMorningAbandonBackstop();
    if (!await ensurePermissions()) return;
    // 14초 파일 고정 — 15초 간격과 절대 겹치지 않아 매발 소리가 난다.
    const iosSound = _abandonShortSound;
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        // iOS 14+ 포그라운드 표시는 banner/list 키가 기준 — alert만 꺼서는
        // 초기화 기본값(true)이 살아 배너가 뜬다. 명시적으로 차단.
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    await Future.wait([
      for (var i = 0; i < morningAbandonBackstopCount; i++)
        _plugin.zonedSchedule(
          morningAbandonBackstopBaseId + i,
          'God Morning',
          'It is time to meet with the Lord.',
          now.add(
            Duration(
              seconds: morningAbandonBackstopIntervalSeconds * (i + 1),
            ),
          ),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: morningAlarmPayload,
        ),
    ]);
    debugPrint('[BACKSTOP] abandon series armed: 20x30s');
  }

  Future<void> cancelMorningAbandonBackstop() async {
    await Future.wait([
      for (var i = 0; i < morningAbandonBackstopCount; i++) _plugin.cancel(morningAbandonBackstopBaseId + i),
    ]);
  }

  // 저녁(자녀 축복)도 동일한 데몬 사망 대비 — 10분 커버에 맞춰 5발.
  static const eveningBackstopBaseId = 3101;
  static const eveningBackstopCount = 5;

  Future<void> scheduleEveningBackstop({required DateTime fireAt}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await cancelEveningBackstop();
    if (!await ensurePermissions()) return;
    // 아침 백스톱과 동일: 포그라운드 무표시·무음(백그라운드 배달 무영향).
    final iosSound = await AlarmSoundPreferences.iosNotificationSoundFile();
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
    final anchor = tz.TZDateTime.from(fireAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;
    for (var i = 0; i < eveningBackstopCount; i++) {
      final fireTime = anchor.add(
        Duration(
          seconds:
              morningBackstopFirstDelaySeconds +
              morningBackstopIntervalSeconds * i,
        ),
      );
      if (!fireTime.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        eveningBackstopBaseId + i,
        'God Morning',
        'Bless before you rest.',
        fireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: eveningAlarmPayload,
      );
      scheduled++;
    }
    debugPrint('[BACKSTOP] evening $scheduled shots from $fireAt');
  }

  Future<void> cancelEveningBackstop() async {
    await Future.wait([
      for (var i = 0; i < eveningBackstopCount; i++) _plugin.cancel(eveningBackstopBaseId + i),
    ]);
  }

  Future<NotificationDetails> _morningBackstopDetails(
    String? soundName,
  ) async {
    // 알람별 소리: MorningAlarm.soundName은 번들 리소스 파일명 그대로.
    // 알림 소리는 30초 한도 — 43초짜리 9번 원음이 들어가면 iOS가 기본음을
    // 튼다('소리 바뀜'의 숨은 원인). 알람별 소리도 발췌본으로 매핑.
    final iosSound = (soundName != null && soundName.isNotEmpty)
        ? AlarmSoundPreferences.notificationSoundFileFor(soundName)
        : await AlarmSoundPreferences.iosNotificationSoundFile();
    // 포그라운드 무표시·무음(융단·방치 시리즈와 동일 원칙) — 미션이 떠
    // 있는 동안 +45초발이 배너+소리로 덮치는 창을 없앤다. 백그라운드·킬
    // 상태 배달(데몬 잠들기 대비 본 목적)은 무영향.
    return NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        presentBanner: false,
        presentList: false,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
  }

  /// 미션 진입용 초경량 취소(저녁) — 백스톱 5발까지만.
  Future<void> cancelEveningMainNotification() async {
    await Future.wait([
      _plugin.cancel(eveningAlarmId),
      _plugin.cancel(testEveningAlarmId),
      cancelEveningBackstop(),
    ]);
  }

  Future<void> cancelEveningAlarm() async {
    await Future.wait([
      _plugin.cancel(eveningAlarmId),
      _plugin.cancel(testEveningAlarmId),
      _cancelRepeatBurst(eveningRepeatBaseId),
      cancelEveningBackstop(),
      cancelEveningRingCarpet(),
      cancelEveningAbandonBackstop(),
    ]);
  }

  Future<void> scheduleEveningAlarm({
    required int hour,
    required int minute,
  }) async {
    if (await _shouldUseNativeMorningNotifications()) {
      await cancelEveningAlarm();
      debugPrint(
        '[native-alarm] skip scheduleEveningAlarm legacy notification',
      );
      return;
    }

    if (!await ensurePermissions()) {
      debugPrint('저녁 알람 예약 취소: 알림 권한 없음');
      return;
    }
    await cancelEveningAlarm();

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    await _plugin.zonedSchedule(
      eveningAlarmId,
      'God Morning',
      'Bless before you rest.',
      scheduledTime,
      await _eveningNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: eveningAlarmPayload,
    );

    final morningOn = await AlarmPreferences.isEnabled();
    await _scheduleRepeatBurst(
      baseId: eveningRepeatBaseId,
      count: morningOn ? repeatBurstCountShared : repeatBurstCountSolo,
      anchor: scheduledTime,
      title: 'God Morning',
      body: 'Bless before you rest.',
      details: await _eveningNotificationDetails(),
      payload: eveningAlarmPayload,
    );

    debugPrint(
      '저녁 알람 예약: ${AlarmPreferences.formatTime(hour, minute)} → ${scheduledTime.toString()}',
    );
  }

  Future<void> scheduleTestMorningAlarm() async {
    if (await _shouldUseNativeMorningNotifications()) {
      await cancelMorningAlarm();
      debugPrint('[native-alarm] skip legacy test morning notification');
      return;
    }

    await requestPermissions();
    await _scheduleTestAlarm(
      id: testMorningAlarmId,
      body: 'Test alarm — it is time to meet with the Lord.',
      payload: morningAlarmPayload,
      details: await _morningNotificationDetails(),
    );
  }

  Future<void> scheduleTestEveningAlarm() async {
    if (await _shouldUseNativeMorningNotifications()) {
      await cancelEveningAlarm();
      debugPrint('[native-alarm] skip legacy test evening notification');
      return;
    }

    await requestPermissions();
    await _scheduleTestAlarm(
      id: testEveningAlarmId,
      body: 'Test alarm — bless before you rest.',
      payload: eveningAlarmPayload,
      details: await _eveningNotificationDetails(),
    );
  }

  Future<void> _scheduleTestAlarm({
    required int id,
    required String body,
    required String payload,
    required NotificationDetails details,
  }) async {
    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 5));

    await _plugin.zonedSchedule(
      id,
      'God Morning',
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<NotificationDetails> _morningNotificationDetails() async {
    final iosSound = await AlarmSoundPreferences.iosNotificationSoundFile();
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        'morning_alarm_channel',
        'Morning Alarm',
        channelDescription: 'Daily morning prayer alarm',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
  }

  Future<bool> _shouldUseAlarmKitForMorningNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    if (!await NativeAlarmService.isAvailable()) return false;
    return NativeAlarmService.requestAuthorization();
  }

  Future<bool> _shouldUseNativeMorningNotifications() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    return _shouldUseAlarmKitForMorningNotifications();
  }

  Future<NotificationDetails> _eveningNotificationDetails() async {
    final iosSound = await AlarmSoundPreferences.iosNotificationSoundFile();
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        'evening_blessing_channel',
        'Evening Blessing',
        channelDescription: 'Daily evening child blessing alarm',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: missionCategoryId,
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(
    int hour,
    int minute, {
    Iterable<int>? weekdays,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    final selected = AlarmPreferences.normalizeWeekdays(weekdays).toSet();
    for (var offset = 0; offset < 8; offset++) {
      final day = now.add(Duration(days: offset));
      final scheduled = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      );
      if (selected.contains(scheduled.weekday) && scheduled.isAfter(now)) {
        return scheduled;
      }
    }

    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }

  bool _isHandledPayload(String? payload) {
    return payload == morningAlarmPayload || payload == eveningAlarmPayload;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    debugPrint(
      '[NOTI] tapped payload=$payload actionId=${response.actionId} '
      'type=${response.notificationResponseType}',
    );
    if (!_isHandledPayload(payload)) return;

    // Banner tap funnels through the alarm handler.
    if (payload == morningAlarmPayload || payload == eveningAlarmPayload) {
      _onNotificationTriggered?.call(payload!);
      return;
    }

    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      _onNotificationTriggered?.call(payload!);
    }
  }
}

@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {}
