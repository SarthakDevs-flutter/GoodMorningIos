import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_sound_preferences.dart';
import 'alarm_store.dart';
import 'alarm_session_service.dart';

enum NativeAlarmKind { morning, evening }

/// consume 결과: 어떤 종류의 알람이, 어떤 알람 id로 대기 중이었는지.
class PendingMission {
  const PendingMission(this.kind, this.alarmId);

  final NativeAlarmKind kind;
  final String? alarmId;
}

typedef NativeAlarmAlertHandler = void Function(NativeAlarmKind kind);

/// iOS AlarmKit / Android AlarmClock bridge for system lock-screen alarms.
class NativeAlarmService {
  NativeAlarmService._();

  static const _channel = MethodChannel('means_of_grace/native_alarm');
  static const _defaultWeekdays = <int>[1, 2, 3, 4, 5, 6, 7];
  static NativeAlarmAlertHandler? _alertHandler;
  static bool _methodCallHandlerInstalled = false;

  /// Fired when the user unlocks the device (Android ACTION_USER_PRESENT or a
  /// successful requestDismissKeyguard). The ringing screen uses this as the
  /// mission-start trigger.
  static void Function()? onDeviceUnlocked;

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void installAlertHandler(NativeAlarmAlertHandler handler) {
    _alertHandler = handler;
    _installMethodCallHandler();
  }

  static void _installMethodCallHandler() {
    if (!_ios && !_android) return;
    if (_methodCallHandlerInstalled) return;
    _methodCallHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeviceUnlocked') {
        onDeviceUnlocked?.call();
        return;
      }
      final kindName = call.arguments as String?;
      final kind = kindName == 'evening'
          ? NativeAlarmKind.evening
          : NativeAlarmKind.morning;
      if (call.method == 'onNativeAlarmAlerting') {
        _alertHandler?.call(kind);
      }
    });
  }

  /// True when AlarmKit is available (iOS 26+).
  static Future<bool> isAvailable() async {
    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> androidCanScheduleExactAlarms() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'androidCanScheduleExactAlarms',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('androidCanScheduleExactAlarms failed: $e');
      return false;
    }
  }

  /// Whether the keyguard is still up (screen not yet unlocked by the user).
  static Future<bool> isDeviceLocked() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('androidIsDeviceLocked') ??
          false;
    } on PlatformException catch (e) {
      debugPrint('androidIsDeviceLocked failed: $e');
      return false;
    }
  }

  /// Ask the system to show its unlock UI; [onDeviceUnlocked] fires on success.
  static Future<void> requestDismissKeyguard() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<bool>('androidRequestDismissKeyguard');
    } on PlatformException catch (e) {
      debugPrint('androidRequestDismissKeyguard failed: $e');
    }
  }

  static Future<void> androidRequestExactAlarmPermission() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<bool>('androidRequestExactAlarmPermission');
    } on PlatformException catch (e) {
      debugPrint('androidRequestExactAlarmPermission failed: $e');
    }
  }

  static Future<bool> requestAuthorization() async {
    if (!_ios) return false;
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm auth failed: $e');
      return false;
    }
  }

  static Future<String> authorizationState() async {
    if (!_ios) return 'unavailable';
    try {
      return await _channel.invokeMethod<String>('authorizationState') ??
          'unknown';
    } on PlatformException {
      return 'unknown';
    }
  }

  static Future<bool> openSubscriptionManagement() async {
    if (!_ios && !_android) return false;
    try {
      return await _channel.invokeMethod<bool>('openSubscriptionManagement') ??
          false;
    } on PlatformException catch (e) {
      debugPrint('openSubscriptionManagement failed: $e');
      return false;
    }
  }

  static Future<bool> openExternalUrl(String url) async {
    if (!_ios && !_android) return false;
    try {
      return await _channel.invokeMethod<bool>('openExternalUrl', {
            'url': url,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('openExternalUrl failed: $e');
      return false;
    }
  }

  static Future<Map<String, Object?>> morningAlarmKitDiagnostics() async {
    if (!_ios) {
      return <String, Object?>{
        'available': false,
        'authorizationState': 'unavailable',
      };
    }
    try {
      final raw = await _channel.invokeMethod<Object?>(
        'morningAlarmKitDiagnostics',
      );
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
    } on PlatformException catch (e) {
      debugPrint('morningAlarmKitDiagnostics failed: $e');
      return <String, Object?>{'available': true, 'error': e.message ?? e.code};
    }
    return <String, Object?>{
      'available': true,
      'error': 'No diagnostics returned',
    };
  }

  static Future<bool> isMorningMissionInProgress() async {
    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('isMorningMissionInProgress') ??
          false;
    } on PlatformException catch (e) {
      debugPrint('isMorningMissionInProgress failed: $e');
      return false;
    }
  }

  /// weekday(1=월..7=일) → 자정 기준 분 맵을 채널 payload 형태로 변환.
  static Map<String, int>? _dayTimesPayload(Map<int, int>? dayTimes) {
    if (dayTimes == null || dayTimes.isEmpty) return null;
    return dayTimes.map((day, minutes) => MapEntry(day.toString(), minutes));
  }

  /// iOS는 예약 시점에 소리가 고정되므로 '다음에 울릴 알람'의 알람별 소리를
  /// 우선 사용한다(null이면 전역 소리). Android는 fire 시점에 미러에서
  /// 알람별 소리를 찾으므로 전역 soundName을 그대로 쓴다.
  static String? _nextAlarmSoundName(
    List<MorningAlarm>? alarms,
    String? nextAlarmId,
  ) {
    if (alarms == null || nextAlarmId == null) return null;
    for (final alarm in alarms) {
      if (alarm.id == nextAlarmId) return alarm.soundName;
    }
    return null;
  }

  /// 알람 목록을 채널 payload 형태로 변환.
  static List<Map<String, dynamic>>? _alarmsPayload(
    List<MorningAlarm>? alarms,
  ) {
    if (alarms == null || alarms.isEmpty) return null;
    return alarms
        .where((a) => a.enabled)
        .map((a) => a.toChannelPayload())
        .toList();
  }

  /// Production: schedule the morning alarm. [hour]:[minute] is the NEXT
  /// occurrence's time (iOS AlarmKit uses it weekly); [dayTimes] carries the
  /// full per-weekday times for Android, which schedules each day exactly.
  static Future<bool> scheduleMorningAlarmKit({
    required int hour,
    required int minute,
    Iterable<int>? weekdays,
    Map<int, int>? dayTimes,
    List<MorningAlarm>? alarms,
    String? nextAlarmId,
    // 다음 발화의 '실제 날짜+시각'. 시:분만 보내면 iOS가 오늘/내일을 추측하다
    // 이미 지난 오늘 시각 기준으로 재시도 사다리를 되살린다(삭제한 알람이
    // 7:03에 울리던 유령 알람의 원인). 날짜를 통째로 보내 추측을 없앤다.
    DateTime? nextFireAt,
  }) async {
    if (!_ios && !_android) return false;
    final soundName = await AlarmSoundPreferences.alarmKitSoundFile();
    final selectedWeekdays = _normalizeWeekdays(weekdays);
    try {
      return await _channel.invokeMethod<bool>('scheduleMorningMission', {
            'hour': hour,
            'minute': minute,
            'soundName': soundName,
            if (_nextAlarmSoundName(alarms, nextAlarmId) != null)
              'nextSoundName': _nextAlarmSoundName(alarms, nextAlarmId),
            'weekdays': selectedWeekdays,
            if (_dayTimesPayload(dayTimes) != null)
              'dayTimes': _dayTimesPayload(dayTimes),
            if (_alarmsPayload(alarms) != null)
              'alarms': _alarmsPayload(alarms),
            // iOS: 다음 발화가 어느 알람인지 — 알람별 완료 판정에 사용.
            if (nextAlarmId != null) 'nextAlarmId': nextAlarmId,
            if (nextFireAt != null)
              'nextFireEpochMillis': nextFireAt.millisecondsSinceEpoch,
            'isSetupActive': AlarmSessionService.instance.isSetupScreenActive,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('scheduleMorningAlarmKit failed: $e');
      return false;
    }
  }

  /// iOS 알람별 독립 등록의 단일 동기화 진입점(조정 방식). 앱 알람 목록을
  /// 그대로 보내면 네이티브가 바뀐 알람만 재등록하고, 사라진 알람만 취소한다.
  /// 아멘 후에도 이 하나만 부른다 — 주간 반복은 OS가 이어간다.
  /// 반환: 네이티브 조정 결과(counts). 'ownerRemoved'==1이면 진행 중이던
  /// 미션의 주인 알람이 삭제/비활성된 것 — 호출부가 알림 부대(융단·백스톱·
  /// 강제종료 시리즈)까지 마저 걷어야 한다(알림은 Dart 소유).
  static Future<Map<String, int>?> syncMorningAlarmList({
    required List<MorningAlarm> alarms,
    String? nextAlarmId,
    DateTime? nextFireAt,
    String? fireImmediatelyAlarmId,
  }) async {
    if (!_ios) return null;
    final globalSound = await AlarmSoundPreferences.alarmKitSoundFile();
    try {
      final counts = await _channel
          .invokeMapMethod<String, int>('syncMorningAlarmList', {
        'alarms': [
          for (final alarm in alarms.where((a) => a.enabled))
            {
              'id': alarm.id,
              'hour': alarm.hour,
              'minute': alarm.minute,
              'weekdays': alarm.weekdays.toList(),
              'sound': alarm.soundName ?? globalSound,
            },
        ],
        if (nextAlarmId != null) 'nextAlarmId': nextAlarmId,
        if (nextFireAt != null)
          'nextFireEpochMillis': nextFireAt.millisecondsSinceEpoch,
        if (fireImmediatelyAlarmId != null)
          'fireImmediatelyAlarmId': fireImmediatelyAlarmId,
        'isSetupActive': AlarmSessionService.instance.isSetupScreenActive,
      });
      debugPrint('[ALARM] peralarm sync: $counts');
      return counts;
    } on PlatformException catch (e) {
      debugPrint('syncMorningAlarmList failed: $e');
      return null;
    }
  }

  /// Production: schedule the evening blessing via AlarmKit (iOS 26+), weekly
  /// at [hour]:[minute]. stop/slide routes into the evening blessing mission.
  static Future<bool> scheduleEveningAlarmKit({
    required int hour,
    required int minute,
    // 실제 다음 발화 날짜 — 시:분만 보내면 iOS가 오늘/내일을 추측하다
    // 지난 시각 기준 사다리를 부활시킨다(설정 저장 직후 유령 울림의 원인).
    DateTime? nextFireAt,
  }) async {
    if (!_ios) return false;
    final soundName = await AlarmSoundPreferences.alarmKitSoundFile();
    try {
      return await _channel.invokeMethod<bool>('scheduleEveningMission', {
            'hour': hour,
            'minute': minute,
            'soundName': soundName,
            if (nextFireAt != null)
              'nextFireEpochMillis': nextFireAt.millisecondsSinceEpoch,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('scheduleEveningAlarmKit failed: $e');
      return false;
    }
  }

  /// Amen post-completion: re-arm the next morning occurrence.
  /// The main alarm stays weekly, and retry alarms are fixed one-shots for the
  /// next occurrence only. Today's remaining retries must stay cancelled.
  static Future<void> scheduleNextMorningAfterCompletion({
    required int hour,
    required int minute,
    Iterable<int>? weekdays,
    Map<int, int>? dayTimes,
    List<MorningAlarm>? alarms,
    String? nextAlarmId,
    bool fireImmediately = false,
    DateTime? nextFireAt,
  }) async {
    if (!_ios && !_android) return;
    final soundName = await AlarmSoundPreferences.alarmKitSoundFile();
    final selectedWeekdays = _normalizeWeekdays(weekdays);
    try {
      await _channel.invokeMethod<bool>('scheduleNextMorningAfterCompletion', {
        'hour': hour,
        'minute': minute,
        'soundName': soundName,
        if (_nextAlarmSoundName(alarms, nextAlarmId) != null)
          'nextSoundName': _nextAlarmSoundName(alarms, nextAlarmId),
        'weekdays': selectedWeekdays,
        if (_dayTimesPayload(dayTimes) != null)
          'dayTimes': _dayTimesPayload(dayTimes),
        if (_alarmsPayload(alarms) != null) 'alarms': _alarmsPayload(alarms),
        // iOS: 다음 발화가 어느 알람인지 — 알람별 완료 판정에 사용.
        if (nextAlarmId != null) 'nextAlarmId': nextAlarmId,
        'fireImmediately': fireImmediately,
        if (nextFireAt != null)
          'nextFireEpochMillis': nextFireAt.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('scheduleNextMorningAfterCompletion failed: $e');
    }
  }

  /// 이미 배달된 배너만 지운다 — 예약된 알람·알림은 무접촉.
  static Future<void> clearDeliveredNotifications() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<void>('clearDeliveredNotifications');
    } on PlatformException catch (_) {}
  }

  /// '사용자가 실제로 화면을 본다'(잠금 해제 + 화면 켜짐) 하드웨어 신호.
  /// Flutter lifecycle의 resumed는 잠금 뒤 포그라운드에서도 참이라 못 믿는다.
  static Future<bool> isDeviceInteractive() async {
    if (!_ios) return true;
    try {
      return await _channel.invokeMethod<bool>('isDeviceInteractive') ?? true;
    } on PlatformException {
      return true;
    }
  }

  /// stop intent(사이드 버튼/알람 정지)를 통해 앱이 갓 기동된 상태인지 확인한다.
  /// Face ID로 인한 isDeviceInteractive() 거짓 양성을 방지하기 위한 안전장치.
  static Future<bool> wasOpenedFromStopIntent() async {
    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('isRecentStopIntent') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Amen: stamp today as completed so stray retry-ladder alarms are ignored.
  /// [alarmId]가 있으면 그 알람만 오늘 완료 처리된다(같은 날 다른 알람은
  /// 그대로 울린다).
  static Future<void> markMorningMissionCompleted({String? alarmId}) async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>('markMorningMissionCompleted', {
        if (alarmId != null) 'alarmId': alarmId,
      });
    } on PlatformException catch (e) {
      debugPrint('markMorningMissionCompleted failed: $e');
    }
  }

  /// Evening Amen: stamp today as completed so stray retry-ladder alarms are
  /// ignored by native intents. Auto-clears tomorrow by date mismatch.
  static Future<void> markEveningMissionCompleted() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<bool>('markEveningMissionCompleted');
    } on PlatformException catch (e) {
      debugPrint('markEveningMissionCompleted failed: $e');
    }
  }

  /// Clear today's Amen stamp when the user explicitly re-saves/re-enables the
  /// morning alarm. This allows same-day testing after a completed mission.
  static Future<void> clearMorningMissionCompleted({
    List<String>? alarmIds,
  }) async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>('clearMorningMissionCompleted', {
        if (alarmIds != null) 'alarmIds': alarmIds,
      });
    } on PlatformException catch (e) {
      debugPrint('clearMorningMissionCompleted failed: $e');
    }
  }

  /// Clear today's evening Amen stamp when the user explicitly re-saves/re-enables
  /// the evening alarm. This allows same-day testing after a completed blessing.
  static Future<void> clearEveningMissionCompleted() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<bool>('clearEveningMissionCompleted');
    } on PlatformException catch (e) {
      debugPrint('clearEveningMissionCompleted failed: $e');
    }
  }

  /// Amen post-completion UX: ask iOS to close the current scene/window.
  /// This is best-effort and App Store-safe compared with killing the process.
  static Future<bool> closeCurrentSceneAfterAmen() async {
    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('closeCurrentScene') ?? false;
    } on PlatformException catch (e) {
      debugPrint('closeCurrentSceneAfterAmen failed: $e');
      return false;
    }
  }

  /// Stop ONLY the currently-ringing morning alert + cancel the retry ladder.
  /// Does NOT remove the weekly schedule — tomorrow's alarm survives. Use on Amen.
  static Future<void> stopMorningAlarmKitAlert() async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>('stopMorningAlert');
    } on PlatformException catch (e) {
      debugPrint('stopMorningAlarmKitAlert failed: $e');
    }
  }

  /// User started the actual mission action (record/type). Stop current
  /// AlarmKit retry sounds and backup watchdogs so STT is quiet. If the app
  /// leaves before Amen, native lifecycle hooks re-arm the exit watchdog.
  /// [alarmId]는 이 미션의 주인 알람 — 이후 재무장되는 추격 슬롯이 이 id를
  /// 실어야 한다(다음 알람 id가 실리면 그 알람이 오완료되는 실측 사고).
  static Future<void> pauseMorningRetriesForMission({String? alarmId}) async {
    if (!_ios && !_android) return;
    try {
      var targetId = alarmId;
      if (targetId == null || targetId.isEmpty) {
        targetId = await AlarmSessionService.instance.activeAlarmId();
      }
      await _channel.invokeMethod<bool>('pauseMorningRetriesForMission', {
        if (targetId != null && targetId.isNotEmpty) 'alarmId': targetId,
      });
    } on PlatformException catch (e) {
      debugPrint('pauseMorningRetriesForMission failed: $e');
    }
  }

  /// The mission screen is still foreground and its 15s inactivity alarm is
  /// ringing in-app. Cancel AlarmKit exit watchdogs so iOS cannot
  /// show a second system alarm over the live mission.
  static Future<void> cancelMorningMissionExitWatchdogs() async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>('cancelMorningMissionExitWatchdogs');
    } on PlatformException catch (e) {
      debugPrint('cancelMorningMissionExitWatchdogs failed: $e');
    }
  }

  /// User started evening mission action (speech/type). Stop current AlarmKit
  /// retry sounds so STT is quiet; native SceneDelegate will re-arm if the app
  /// leaves foreground before Amen.
  static Future<void> pauseEveningRetriesForMission() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<bool>('pauseEveningRetriesForMission');
    } on PlatformException catch (e) {
      debugPrint('pauseEveningRetriesForMission failed: $e');
    }
  }

  /// Mission screen closed without Amen. Native schedules mission-exit
  /// watchdogs so AlarmKit can re-ring after the app leaves foreground.
  static Future<void> resumeMorningRetryAfterMissionAbandoned() async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>(
        'resumeMorningRetryAfterMissionAbandoned',
      );
    } on PlatformException catch (e) {
      debugPrint('resumeMorningRetryAfterMissionAbandoned failed: $e');
    }
  }

  /// Evening mission screen closed or app left before Amen. Re-ring quickly.
  static Future<void> resumeEveningRetryAfterMissionAbandoned() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<bool>(
        'resumeEveningRetryAfterMissionAbandoned',
      );
    } on PlatformException catch (e) {
      debugPrint('resumeEveningRetryAfterMissionAbandoned failed: $e');
    }
  }

  /// Cancel the AlarmKit morning alarm ENTIRELY — removes the weekly schedule.
  /// Only call when the user disables the morning alarm or changes its time.
  /// NEVER call this on Amen (would kill tomorrow's alarm).
  /// AlarmKit이 저장해 둔 '다음 아침 울림 시각'. 예약이 없으면 null.
  static Future<DateTime?> eveningNextFireTime() async {
    if (!_ios) return null;
    try {
      final millis = await _channel.invokeMethod<num>(
        'getEveningNextFireEpochMillis',
      );
      if (millis == null || millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
    } catch (e) {
      debugPrint('eveningNextFireTime failed: $e');
      return null;
    }
  }

  static Future<DateTime?> morningNextFireTime() async {
    if (!_ios) return null;
    try {
      final millis = await _channel.invokeMethod<num>(
        'getMorningNextFireEpochMillis',
      );
      if (millis == null || millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
    } catch (e) {
      debugPrint('morningNextFireTime failed: $e');
      return null;
    }
  }

  static Future<void> cancelMorningAlarmKitSchedule() async {
    if (!_ios && !_android) return;
    try {
      await _channel.invokeMethod<bool>('cancelMorning');
    } on PlatformException catch (e) {
      debugPrint('cancelMorningAlarmKitSchedule failed: $e');
    }
  }

  /// Read + clear the flag set by OpenMissionFromAlarmIntent (stop/slide).
  /// True means the user stopped the AlarmKit alarm → route into the mission.
  static Future<bool> consumeOpenMissionFlag() async {
    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('consumeOpenMissionFlag') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Read + clear the pending mission set by the alarm fire / stop-slide
  /// intent. Android returns "morning:<alarmId>" so the mission knows WHICH
  /// alarm fired; iOS/legacy return plain "morning"/"evening".
  static Future<PendingMission?> consumePendingMission() async {
    if (!_ios && !_android) return null;
    try {
      final raw = await _channel.invokeMethod<String>(
        'consumePendingMissionKind',
      );
      if (raw == null) return null;
      if (raw == 'evening') {
        // 오늘 축복을 이미 마쳤으면 잔여 대기표는 버린다(두 번째 미션 방지).
        // 키는 AlarmSessionService._eveningCompletedDateKey와 동일.
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final today =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        if (prefs.getString('evening_alarm_completed_date') == today) {
          debugPrint('[ALARM] evening already completed — ignore pending');
          return null;
        }
        return const PendingMission(NativeAlarmKind.evening, null);
      }
      if (raw == 'morning') {
        return const PendingMission(NativeAlarmKind.morning, null);
      }
      if (raw.startsWith('morning:')) {
        final id = raw.substring('morning:'.length);
        if (id.isNotEmpty) {
          // 삭제/비활성 알람의 잔여 슬롯이 울려도 미션은 절대 열지 않는다
          // (유령 알람 2차 방어선).
          final alarms = await AlarmStore.loadAlarms();
          final exists = alarms.any((a) => a.id == id && a.enabled);
          if (!exists) {
            debugPrint('[ALARM] pending mission for missing alarm $id — ignore');
            return null;
          }
        }
        return PendingMission(NativeAlarmKind.morning, id.isEmpty ? null : id);
      }
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<NativeAlarmKind?> consumePendingMissionKind() async {
    return (await consumePendingMission())?.kind;
  }

  static Future<bool> scheduleMorning({
    required int hour,
    required int minute,
    Iterable<int>? weekdays,
    String title = 'Morning prayer',
  }) async {
    if (!_ios || !await isAvailable()) return false;
    final selectedWeekdays = _normalizeWeekdays(weekdays);
    try {
      return await _channel.invokeMethod<bool>('scheduleMorning', {
            'hour': hour,
            'minute': minute,
            'weekdays': selectedWeekdays,
            'title': title,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm scheduleMorning failed: $e');
      return false;
    }
  }

  static Future<bool> scheduleEvening({
    required int hour,
    required int minute,
    String title = 'Evening blessing',
  }) async {
    if (!_ios || !await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('scheduleEvening', {
            'hour': hour,
            'minute': minute,
            'title': title,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm scheduleEvening failed: $e');
      return false;
    }
  }

  static Future<void> beginPersistence(NativeAlarmKind kind) async {
    if (!_ios || !await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('beginPersistence', {
        'kind': kind.name,
      });
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm beginPersistence failed: $e');
    }
  }

  static Future<void> endPersistence(NativeAlarmKind kind) async {
    if (!_ios || !await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('endPersistence', {'kind': kind.name});
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm endPersistence failed: $e');
    }
  }

  static Future<void> cancelMorning() async {
    if (!_ios || !await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('cancelMorning');
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm cancelMorning failed: $e');
    }
  }

  static Future<void> cancelEvening() async {
    if (!_ios || !await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('cancelEvening');
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm cancelEvening failed: $e');
    }
  }

  static Future<void> stopEveningAlarmKitAlert() async {
    if (!_ios || !await isAvailable()) return;
    try {
      await _channel.invokeMethod<void>('stopEveningAlert');
    } on PlatformException catch (e) {
      debugPrint('NativeAlarm stopEveningAlarmKitAlert failed: $e');
    }
  }

  static List<int> _normalizeWeekdays(Iterable<int>? weekdays) {
    final normalized =
        (weekdays ?? _defaultWeekdays)
            .where((weekday) => weekday >= 1 && weekday <= 7)
            .toSet()
            .toList()
          ..sort();
    return normalized.isEmpty ? List<int>.from(_defaultWeekdays) : normalized;
  }
}
