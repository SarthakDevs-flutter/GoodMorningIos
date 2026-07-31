import ActivityKit
import Flutter
import UserNotifications
import SwiftUI
import UIKit

#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct GraceAlarmMetadata: AlarmMetadata {}
#else
// Fictional AlarmKit mock types for backwards compatibility with iOS < 26 SDKs

protocol AlarmMetadata {}

private struct GraceAlarmMetadata: AlarmMetadata {}

@available(iOS 16.0, *)
struct AlarmButton {
    init(text: LocalizedStringResource, textColor: UIColor, systemImageName: String) {}
}

@available(iOS 16.0, *)
struct AlarmPresentation {
    struct Alert {
        init(title: LocalizedStringResource) {}
        init(title: LocalizedStringResource, stopButton: AlarmButton) {}
    }
    init(alert: Alert) {}
}

@available(iOS 16.0, *)
struct AlarmAttributes<MetadataType: AlarmMetadata> {
    init(presentation: AlarmPresentation, metadata: MetadataType, tintColor: UIColor) {}
}

struct AlarmSound {
    static func named(_ name: String) -> AlarmSound { AlarmSound() }
}

@available(iOS 16.0, *)
struct Alarm {
    var id: UUID
    var fireDate: Date?
    var soundName: String?
    var state: State
    var schedule: Schedule?
    
    enum State {
        case ringing, snoozed, scheduled, inactive
        case countdown, paused, alerting
    }
    
    enum Schedule {
        case fixed(Date)
        case relative(Relative)
        
        struct Relative {
            var time: Time
            var repeats: Recurrence
            
            struct Time {
                var hour: Int
                var minute: Int
                init(hour: Int, minute: Int) {
                    self.hour = hour
                    self.minute = minute
                }
            }
            
            enum Recurrence {
                case never
                case weekly([Locale.Weekday])
            }
        }
    }
}

@available(iOS 16.0, *)
class AlarmManager {
    static let shared = AlarmManager()
    
    enum AuthorizationState {
        case authorized, denied, notDetermined
    }
    
    var authorizationState: AuthorizationState { .notDetermined }
    var alarms: [Alarm] { [] }
    var alarmUpdates: AsyncStream<[Alarm]> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    func requestAuthorization() async throws -> AuthorizationState {
        return .notDetermined
    }
    
    func stop(id: UUID) throws {}
    func cancel(id: UUID) throws {}
    func snooze(id: UUID) throws {}
    
    struct AlarmConfiguration<MetadataType: AlarmMetadata> {
        init(schedule: Alarm.Schedule, attributes: AlarmAttributes<MetadataType>, sound: AlarmSound) {}
        
        static func alarm(
            schedule: Alarm.Schedule,
            attributes: AlarmAttributes<MetadataType>,
            stopIntent: Any,
            sound: AlarmSound
        ) -> AlarmConfiguration<MetadataType> {
            AlarmConfiguration(schedule: schedule, attributes: attributes, sound: sound)
        }
    }
    
    func schedule<T: AlarmMetadata>(id: UUID, configuration: AlarmConfiguration<T>) async throws {}
}
#endif

/// Bridges Flutter alarm scheduling to iOS AlarmKit (26+) for lock-screen alarms.
final class NativeAlarmPlugin: NSObject, FlutterPlugin {
  private static let morningId = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!
  private static let eveningId = UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!
  private static let morningSnoozeId = UUID(uuidString: "A1000011-0000-4000-8000-000000000011")!
  private static let eveningSnoozeId = UUID(uuidString: "A1000012-0000-4000-8000-000000000012")!
  private static let morningMissionWatchdogId = UUID(uuidString: "A1000050-0000-4000-8000-000000000050")!
  private static let eveningMissionWatchdogId = UUID(uuidString: "A1000051-0000-4000-8000-000000000051")!
  // 저녁 추격 20발×30초 — 아침과 동일 화력(사용자 결정: 통일).
  private static let eveningMissionWatchdogIds: [UUID] = (1...20).compactMap {
    UUID(uuidString: String(format: "A1000052-0000-4000-8000-%012X", $0))
  }
  // 정지 메아리(Alare 기법) — stop 인텐트 perform() 초입에서 가장 먼저
  // 예약하는 일회성 1발. 뒤쪽의 무거운 pause·추격 무장이 도중에 죽어도
  // 22초 뒤 이 발이 돌아와 다시 전체 무장을 시도한다(자가 치유 고리).
  private static let morningStopEchoId = UUID(uuidString: "A1000070-0000-4000-8000-000000000070")!
  private static let eveningStopEchoId = UUID(uuidString: "A1000071-0000-4000-8000-000000000071")!

  private static let morningPendingKey = "grace_pending_morning_alarm"
  private static let eveningPendingKey = "grace_pending_evening_alarm"
  private static let morningPrayerActiveKey = "grace_prayer_active_morning"
  private static let eveningPrayerActiveKey = "grace_prayer_active_evening"
  private static let morningMissionInProgressKey = "grace_morning_mission_in_progress"
  // 지금 진행 중인 아침 미션의 '주인 알람' id — 추격/사다리 재무장이 이
  // 값을 stop 인텐트에 싣는다. scheduledMorningAlarmId(다음 알람으로 덮이는
  // 값)를 실으면 엉뚱한 알람이 완료 처리된다(실측 2026-07-10 9:50).
  static let morningMissionActiveAlarmIdKey = "grace_morning_mission_active_alarm_id"
  // 미션이 '오늘' 시작됐는지 — 부활 게이트가 자정을 넘지 않게 하는 날짜 도장.
  static let morningMissionStartedDateKey = "grace_morning_mission_started_date"
  static let eveningMissionStartedDateKey = "grace_evening_mission_started_date"
  // 저녁의 '다음 발화' 스탬프 — 시각 추측 잠금(유령 미션)을 대체하는 근거.
  static let eveningNextFireEpochKey = "eveningNextFireEpochMillis"
  // 저녁 등록에 실제 쓰인 소리 — 추격이 아침 소리를 빌려 쓰던 것 교체.
  static let eveningAlarmKitSoundNameKey = "grace_evening_alarmkit_chase_sound"
  // 사다리 스킵 서명에 소리 포함 — 소리만 바꾼 저장 후 옛 소리로 울리던 것.
  private static let morningLadderSoundKey = "grace_morning_ladder_sound"
  private static let eveningMissionInProgressKey = "grace_evening_mission_in_progress"
  private static let morningMissionCompletedDateKey = "missionCompletedDate"
  // 멀티 알람: 현재 예약된 아침 알람의 id와 알람별 완료 스탬프.
  private static let scheduledMorningAlarmIdKey = "scheduledMorningAlarmId"
  // 예약된 다음 아침 울림 시각(epoch ms). 이 시각이 "오늘"이고 이미 지났는데
  // 완료되지 않았다면 = 실제 울림을 무시한 것 → 미션 잠금의 근거가 된다.
  private static let morningNextFireEpochKey = "morningNextFireEpochMillis"
  private static let morningCompletedPerAlarmPrefix = "morningCompleted_"
  private static let eveningMissionCompletedDateKey = "eveningMissionCompletedDate"
  private static let morningRearmReasonKey = "grace_morning_rearm_reason"
  private static let morningRearmStartedAtKey = "grace_morning_rearm_started_at"
  private static let morningRearmFinishedAtKey = "grace_morning_rearm_finished_at"
  private static let morningRearmFirstScheduledKey = "grace_morning_rearm_first_scheduled"
  private static let morningRearmFirstFireDateKey = "grace_morning_rearm_first_fire_date"
  private static let morningRearmFirstErrorKey = "grace_morning_rearm_first_error"
  private static let morningRearmTrailingScheduledKey = "grace_morning_rearm_trailing_scheduled"
  private static let morningRearmImmediateCountKey = "grace_morning_rearm_immediate_count"
  private static let morningRearmImmediateFirstFireKey = "grace_morning_rearm_immediate_first_fire"
  private static let morningMissionExitGenerationKey = "grace_morning_mission_exit_generation"
  // 메아리 전용 세대 — 추격 세대(mission_exit)와 반드시 분리한다. 추격
  // 세대는 사다리 재건축 때마다 움직여서, 같이 쓰면 '지은 지 1초 만에
  // 메아리 자진 철수'가 된다(실기기 3번-후-무음 실측의 한 뿌리).
  private static let morningEchoGenerationKey = "grace_morning_echo_generation"
  private static let eveningEchoGenerationKey = "grace_evening_echo_generation"
  // 메인 알람(morningId) 재예약이 duplicate-ID 레이스로 끝내 실패했을 때,
  // 충돌 불가능한 새 UUID로 정시 1회 알람을 대신 심는다. 그 id를 여기 보관해
  // 정지/완료/재예약 때 함께 취소한다. (켜둔 알람이 무음으로 지나가던 원인.)
  private static let morningMainFallbackIdKey = "grace_morning_main_fallback_id"
  // 마지막 성공 배치의 서명(시:분|요일|사운드|base초). 동일하면 재등록을
  // 통째로 건너뛴다. 실측(13:26 알람→13:28:17 배달): 대량 취소+재등록 직후
  // 기기가 잠들면 mobiletimerd가 하드웨어 웨이크를 못 걸어 알람이 늦게 몰아
  // 배달된다 — 데몬에 보내는 변이 폭풍 자체를 줄이는 것이 방어다.
  private static let morningBatchSignatureKey = "grace_morning_batch_signature"
  // 저녁(자녀 축복)도 동일한 조정 원칙: 내용이 같고 등록이 살아 있으면
  // 재등록하지 않는다(남은 변이 폭풍 제거).
  private static let eveningBatchSignatureKey = "grace_evening_batch_signature"
  private static let legacyPurgeLock = NSLock()
  private static var purgedLegacyPrefixes: Set<String> = []
  // ── 알람별 독립 등록(2026-07-08 재설계) ──
  // 롤링 단일 알람 + 20슬롯 사다리 전체 재등록이 유령 알람·지연 배달·데몬
  // 사망의 공통 뿌리였다. AlarmKit의 의도대로 앱 알람 하나 = 주간 반복 등록
  // 하나로 바꾸고, 동기화는 조정(reconcile)만 한다: 바뀐 알람만 취소·재등록,
  // 안 바뀐 알람은 데몬을 아예 건드리지 않는다. 아멘 때 재예약도 없다
  // (주간 반복은 OS가 이어간다).
  private static let morningPerAlarmUuidMapKey = "grace_morning_peralarm_uuid_map"
  private static let morningPerAlarmSigMapKey = "grace_morning_peralarm_sig_map"
  // 마지막 동기화의 알람 스펙 원본 — 미션 방치(아멘 없이 이탈) 시 네이티브가
  // Dart 없이도 내일 이후 알람을 되살리는 데 쓴다.
  private static let morningSpecsKey = "grace_morning_specs_v1"
  private static let morningLadderBaseEpochKey = "grace_morning_ladder_base_epoch"
  private static let migratedPerAlarmV1Key = "grace_migrated_peralarm_v1"
  // 재시도 사다리 축소: 메인 알림 자체가 수 분간 울리고, 로컬 알림 백스톱이
  // +45초부터 60초 간격으로 사이를 메우므로, AlarmKit 슬롯은 4개면 충분하다.
  // 알라미 원칙: 첫 알람 후 20분간 2분 간격으로 돌아온다(사용자 결정).
  // 조정 방식이라 base가 같으면 재등록이 없어 10발도 데몬 부담이 없다.
  private static let morningLadderSlotOffsets: [TimeInterval] = [
    120, 240, 360, 480, 600, 720, 840, 960, 1080, 1200,
  ]
  private static let snoozeDelaySeconds = 90
  // Mission-exit watchdogs are armed only when the app leaves the mission
  // before Amen. While the mission stays foreground, all backup alarms remain
  // cancelled so they cannot overlap the 15s in-app inactivity alarm.
  private static let missionAbandonFirstRetryDelaySeconds = 22
  private static let missionAbandonRetryCount = 20
  private static let watchdogCount = 6
  // 추격 간격 30초(사용자 결정: 더 촘촘하게) = 22초 + 19×30초 ≈ 10분 볼리.
  // 소진 후 다음 깨어남이 새 20발을 무장하고, 2분 사다리가 20분까지 잇는다.
  private static let missionAbandonIntervalSeconds = 30
  @MainActor private static var morningMissionExitRearmInFlight = false

  // In-memory cache variables to survive locked UserDefaults encryption on iOS 18+
  private static var cachedMorningInProgress: Bool?
  private static var cachedMorningStartedDate: String?
  private static var cachedMorningCompletedDate: String?
  private static var cachedMorningActiveAlarmId: String?
  private static var cachedEveningInProgress: Bool?
  private static var cachedEveningStartedDate: String?
  private static var cachedEveningCompletedDate: String?

  static func setMorningInProgress(_ value: Bool) {
    cachedMorningInProgress = value
    UserDefaults.standard.set(value, forKey: morningMissionInProgressKey)
  }

  static func getMorningInProgress() -> Bool {
    if let cached = cachedMorningInProgress {
      return cached
    }
    let value = UserDefaults.standard.bool(forKey: morningMissionInProgressKey)
    if value || UIApplication.shared.isProtectedDataAvailable {
      cachedMorningInProgress = value
    }
    return value
  }

  static func setMorningStartedDate(_ value: String?) {
    cachedMorningStartedDate = value
    if let val = value {
      UserDefaults.standard.set(val, forKey: morningMissionStartedDateKey)
    } else {
      UserDefaults.standard.removeObject(forKey: morningMissionStartedDateKey)
    }
  }

  static func getMorningStartedDate() -> String? {
    if let cached = cachedMorningStartedDate {
      return cached
    }
    if let value = UserDefaults.standard.string(forKey: morningMissionStartedDateKey) {
      cachedMorningStartedDate = value
      return value
    }
    return nil
  }

  static func setMorningCompletedDate(_ value: String?) {
    cachedMorningCompletedDate = value
    if let val = value {
      UserDefaults.standard.set(val, forKey: morningMissionCompletedDateKey)
    } else {
      UserDefaults.standard.removeObject(forKey: morningMissionCompletedDateKey)
    }
  }

  static func getMorningCompletedDate() -> String? {
    if let cached = cachedMorningCompletedDate {
      return cached
    }
    if let value = UserDefaults.standard.string(forKey: morningMissionCompletedDateKey) {
      cachedMorningCompletedDate = value
      return value
    }
    return nil
  }

  static func setMorningActiveAlarmId(_ value: String?) {
    cachedMorningActiveAlarmId = value
    if let val = value {
      UserDefaults.standard.set(val, forKey: morningMissionActiveAlarmIdKey)
    } else {
      UserDefaults.standard.removeObject(forKey: morningMissionActiveAlarmIdKey)
    }
  }

  static func getMorningActiveAlarmId() -> String? {
    if let cached = cachedMorningActiveAlarmId {
      return cached
    }
    if let value = UserDefaults.standard.string(forKey: morningMissionActiveAlarmIdKey) {
      cachedMorningActiveAlarmId = value
      return value
    }
    return nil
  }

  static func setEveningInProgress(_ value: Bool) {
    cachedEveningInProgress = value
    UserDefaults.standard.set(value, forKey: eveningMissionInProgressKey)
  }

  static func getEveningInProgress() -> Bool {
    if let cached = cachedEveningInProgress {
      return cached
    }
    let value = UserDefaults.standard.bool(forKey: eveningMissionInProgressKey)
    if value || UIApplication.shared.isProtectedDataAvailable {
      cachedEveningInProgress = value
    }
    return value
  }

  static func setEveningStartedDate(_ value: String?) {
    cachedEveningStartedDate = value
    if let val = value {
      UserDefaults.standard.set(val, forKey: eveningMissionStartedDateKey)
    } else {
      UserDefaults.standard.removeObject(forKey: eveningMissionStartedDateKey)
    }
  }

  static func getEveningStartedDate() -> String? {
    if let cached = cachedEveningStartedDate {
      return cached
    }
    if let value = UserDefaults.standard.string(forKey: eveningMissionStartedDateKey) {
      cachedEveningStartedDate = value
      return value
    }
    return nil
  }

  static func setEveningCompletedDate(_ value: String?) {
    cachedEveningCompletedDate = value
    if let val = value {
      UserDefaults.standard.set(val, forKey: eveningMissionCompletedDateKey)
    } else {
      UserDefaults.standard.removeObject(forKey: eveningMissionCompletedDateKey)
    }
  }

  static func getEveningCompletedDate() -> String? {
    if let cached = cachedEveningCompletedDate {
      return cached
    }
    if let value = UserDefaults.standard.string(forKey: eveningMissionCompletedDateKey) {
      cachedEveningCompletedDate = value
      return value
    }
    return nil
  }

  static func runWithBackgroundTask(name: String, block: @escaping () async -> Void) {
    var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    bgTaskId = UIApplication.shared.beginBackgroundTask(withName: name) {
      if bgTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskId)
        bgTaskId = .invalid
      }
    }
    Task {
      await block()
      if bgTaskId != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskId)
        bgTaskId = .invalid
      }
    }
  }

  private var channel: FlutterMethodChannel?
  private var monitoringTask: Task<Void, Never>?
  static var sharedInstance: NativeAlarmPlugin?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "means_of_grace/native_alarm",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeAlarmPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    // 정지 인텐트가 남긴 pendingMission을 앱이 포그라운드일 때도 즉시 소비할
    // 수 있도록 Darwin 알림을 구독한다(기존 onNativeAlarmAlerting 경로 재사용).
    sharedInstance = instance
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      nil,
      { _, _, _, _, _ in
        DispatchQueue.main.async {
          let kind = UserDefaults.standard.string(forKey: "pendingMissionKind") ?? "morning"
          NativeAlarmPlugin.sharedInstance?.channel?.invokeMethod(
            "onNativeAlarmAlerting",
            arguments: kind
          )
        }
      },
      "com.bagseonghwa.meansofgrace.pendingMission" as CFString,
      nil,
      .deliverImmediately
    )
    // AlarmKit morning now owns its own retry ladder. The old alarmUpdates
    // monitor created extra 90s snooze alarms after stop/slide, which mixed
    // sounds with the 30s retry ladder. Keep it disabled unless a future
    // evening AlarmKit path explicitly needs it.
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }

    case "requestAuthorization":
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      Task {
        do {
          let state = try await AlarmManager.shared.requestAuthorization()
          await MainActor.run {
            result(state == .authorized)
          }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "alarm_auth_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "authorizationState":
      guard #available(iOS 26.0, *) else {
        result("unavailable")
        return
      }
      Task {
        let state = await AlarmManager.shared.authorizationState
        await MainActor.run {
          switch state {
          case .authorized:
            result("authorized")
          case .denied:
            result("denied")
          case .notDetermined:
            result("notDetermined")
          @unknown default:
            result("unknown")
          }
        }
      }

    case "morningAlarmKitDiagnostics":
      guard #available(iOS 26.0, *) else {
        result([
          "available": false,
          "authorizationState": "unavailable",
        ])
        return
      }
      result(Self.morningAlarmKitDiagnostics())

    case "clearDeliveredNotifications":
      // 이미 화면에 배달된 배너만 지운다 — 예약(융단·추격·시리즈)은 무접촉.
      UNUserNotificationCenter.current().removeAllDeliveredNotifications()
      result(true)

    case "isDeviceInteractive":
      // '사용자가 실제로 화면을 보고 있다'의 하드웨어 신호 — Flutter의
      // lifecycle(resumed)은 잠금 뒤 포그라운드에서도 참이라 믿을 수 없다.
      result(
        UIApplication.shared.isProtectedDataAvailable
          && UIScreen.main.brightness > 0.01
      )

    case "isRecentStopIntent":
      // stop intent(사이드 버튼/알람 정지)에서 온 미션인지 판단한다.
      // 10초 이내면 '사이드 버튼에서 온 미션' — engaged 판정을 무시하고
      // locked 분기로 진입해야 한다(Face ID 거짓 양성 방지).
      let ts = UserDefaults.standard.double(forKey: "grace_stop_intent_ts")
      let elapsed = Date().timeIntervalSince1970 - ts
      result(ts > 0 && elapsed < 10)

    case "isMorningMissionInProgress":
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      result(Self.isMorningMissionInProgress())

    case "beginPersistence":
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let kind = args["kind"] as? String else {
        result(FlutterError(code: "bad_args", message: "kind required", details: nil))
        return
      }
      Self.setPending(kind: kind, pending: true)
      Self.setPrayerActive(kind: kind, active: false)
      result(true)

    case "endPersistence":
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let kind = args["kind"] as? String else {
        result(FlutterError(code: "bad_args", message: "kind required", details: nil))
        return
      }
      Task {
        await Self.clearPersistence(kind: kind)
        await MainActor.run { result(true) }
      }

    case "pauseAlertSound":
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let kind = args["kind"] as? String else {
        result(FlutterError(code: "bad_args", message: "kind required", details: nil))
        return
      }
      Task {
        await Self.pauseAlertSound(kind: kind)
        await MainActor.run { result(true) }
      }

    case "scheduleMorning", "scheduleEvening":
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hour = args["hour"] as? Int,
            let minute = args["minute"] as? Int else {
        result(FlutterError(code: "bad_args", message: "hour/minute required", details: nil))
        return
      }
      let title = args["title"] as? String ?? "God Morning"
      let id = call.method == "scheduleMorning" ? Self.morningId : Self.eveningId
      let weekdays = Self.normalizedDartWeekdays(args["weekdays"])
      Task {
        do {
          try await Self.scheduleNativeAlarm(
            id: id,
            hour: hour,
            minute: minute,
            title: title,
            weekly: true,
            dartWeekdays: weekdays
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "schedule_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "cancelMorning":
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        Self.setMorningInProgress(false)
        Self.clearMorningNextFireEpoch()
        Self.cancelMorningLadder()
        Self.cancelStopEcho(kind: "morning")
        await Self.clearPersistence(kind: "morning")
        await MainActor.run { result(true) }
      }

    case "stopMorningAlert":
      // Amen path: stop the currently-ringing main alert, and cancel the whole
      // retry ladder so it stops re-ringing today. The weekly schedule is
      // re-armed afterwards by Dart for the next occurrence.
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        // 아멘 최종 정지 — 알람별 등록은 '정지'만(주간 반복은 계속).
        Self.stopAllPerAlarmRegistrations(cancelToo: false)
        try? AlarmManager.shared.stop(id: Self.morningId)
        Self.cancelMorningMainFallback()
        for rid in Self.morningRetryIds {
          try? AlarmManager.shared.stop(id: rid)
          try? AlarmManager.shared.cancel(id: rid)
        }
        Self.purgeStaleRetrySlots(["A1000040", "A1000050"])
        // Block the legacy monitoring snooze: clear pending so the alarmUpdates
        // observer won't arm a 90s snooze when morningId leaves .alerting, and
        // cancel any snooze already armed. Amen must be the final stop.
        Self.setPending(kind: "morning", pending: false)
        try? AlarmManager.shared.cancel(id: Self.morningSnoozeId)
        Self.cancelMorningMissionExitLadder()
        Self.cancelStopEcho(kind: "morning")
        await MainActor.run { result(true) }
      }

    case "pauseMorningRetriesForMission":
      // User has started the actual mission action (record/type). Cancel every
      // morning retry/watchdog while foreground so STT and the 15s in-app alarm
      // are the only active sound paths.
      // 미션 주인 알람 id를 보관 — 이후 추격 재무장이 이 id를 싣는다.
      if let missionAlarmId = (call.arguments as? [String: Any])?["alarmId"] as? String,
         !missionAlarmId.isEmpty {
        Self.setMorningActiveAlarmId(missionAlarmId)
      }
      // 미션 시작 날짜 도장 — 앱이 죽어도 '오늘의 미션'만 부활시키기 위함.
      Self.setMorningStartedDate(Self.todayKey())
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        do {
          try await Self.pauseMorningRetriesForMission()
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "pause_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "cancelMorningMissionExitWatchdogs":
      // Foreground inactivity is handled by the in-app alarm loop. Cancel the
      // AlarmKit mission-exit watchdogs defensively so a system alert cannot
      // interrupt or overlap the mission while the app is still open.
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      // 참여 = 전멸이 아니라 '앞 120초만 조용히'. 꼬리를 남겨야 참여 오판
      // (전원버튼 순간 Face ID 통과) 한 번에 재울림이 전멸하지 않는다 —
      // 미션 화면이 45초마다 이 창을 굴려 연장하고, 아멘만 전체를 걷는다.
      Task {
        await Self.cancelForegroundMissionExitWatchdogs(reason: "channel")
      }
      result(true)

    case "pauseEveningRetriesForMission":
      // User has actually started the evening mission (speech/type). Stop the
      // retry ladder so it does not interrupt STT; SceneDelegate will arm a
      // watchdog if the app leaves before Amen.
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        do {
          try await Self.pauseEveningRetriesForMission()
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "pause_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "resumeMorningRetryAfterMissionAbandoned":
      // 인텐트/pause를 안 거친 미션(승격·게이트 강제)도 오늘 시작 도장을
      // 받아야 날짜 스코프 추격 무장이 작동한다.
      Self.setMorningInProgress(true)
      Self.setMorningStartedDate(Self.todayKey())
      // Mission screen went away without Amen. Schedule mission-exit watchdogs
      // so AlarmKit owns the re-ring outside the foreground mission.
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Self.runWithBackgroundTask(name: "resumeMorningRetry") {
        do {
          Self.setMorningInProgress(true)
          try await Self.rearmMorningNormalRetriesForMissionAbandon(
            reason: "flutter_abandon"
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "resume_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "resumeEveningRetryAfterMissionAbandoned":
      // Evening mission screen went away without Amen. Re-ring quickly.
      // 아침과 대칭: 진행 플래그를 세워 배경 전환 재무장·정리 가드가 작동.
      Self.setEveningInProgress(true)
      Self.setEveningStartedDate(Self.todayKey())
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Self.runWithBackgroundTask(name: "resumeEveningRetry") {
        do {
          await Self.rearmEveningChaseIfEmpty(reason: "flutter_abandon")
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "resume_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "scheduleNextMorningAfterCompletion":
      // Amen post-completion: re-arm ONLY the next main weekly occurrence.
      // Never recreates today's retry ladder (that re-rings after Amen).
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hour = args["hour"] as? Int,
            let minute = args["minute"] as? Int else {
        result(FlutterError(code: "bad_args", message: "hour/minute required", details: nil))
        return
      }
      // 알람별 소리: 다음에 울릴 알람의 소리가 오면 그것을 우선 사용한다.
      let soundName = Self.validatedMorningAlarmKitSoundName(
        (args["nextSoundName"] as? String) ?? (args["soundName"] as? String)
      )
      let weekdays = Self.normalizedDartWeekdays(args["weekdays"])
      let fireImmediately = args["fireImmediately"] as? Bool ?? false
      // Dart가 계산한 '실제 다음 발화 날짜' — 오늘/내일 추측을 없앤다.
      let nextFireDate: Date? = ((args["nextFireEpochMillis"] as? NSNumber)?.doubleValue)
        .map { Date(timeIntervalSince1970: $0 / 1000.0) }
      let nextFireIsToday = nextFireDate.map { Calendar.current.isDateInToday($0) }
      Self.promoteMissedMorningFireIfNeeded()
      Self.storeScheduledMorningAlarmId(
        args["nextAlarmId"] as? String,
        nextFireIsToday: nextFireIsToday
      )
      Task {
        do {
          try await Self.scheduleNextMorningAfterCompletion(
            hour: hour,
            minute: minute,
            soundName: soundName,
            dartWeekdays: weekdays,
            fireImmediately: fireImmediately,
            nextFireDate: nextFireDate,
            nextAlarmId: args["nextAlarmId"] as? String
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "schedule_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "cancelEvening":
      // 꺼진 알람의 발화 스탬프가 남으면 잠금 오판을 만든다 — 함께 제거.
      UserDefaults.standard.removeObject(forKey: Self.eveningNextFireEpochKey)
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        Self.setEveningInProgress(false)
        Self.cancelEveningLadder()
        Self.cancelStopEcho(kind: "evening")
        await Self.clearPersistence(kind: "evening")
        await MainActor.run { result(true) }
      }

    case "scheduleMorningMission":
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hour = args["hour"] as? Int,
            let minute = args["minute"] as? Int else {
        result(FlutterError(code: "bad_args", message: "hour/minute required", details: nil))
        return
      }
      // 알람별 소리: 다음에 울릴 알람의 소리가 오면 그것을 우선 사용한다.
      let soundName = Self.validatedMorningAlarmKitSoundName(
        (args["nextSoundName"] as? String) ?? (args["soundName"] as? String)
      )
      let weekdays = Self.normalizedDartWeekdays(args["weekdays"])
      let nextFireDate: Date? = ((args["nextFireEpochMillis"] as? NSNumber)?.doubleValue)
        .map { Date(timeIntervalSince1970: $0 / 1000.0) }
      let nextFireIsToday = nextFireDate.map { Calendar.current.isDateInToday($0) }
      let isSetupActive = (args["isSetupActive"] as? Bool) ?? false
      if !isSetupActive {
        Self.promoteMissedMorningFireIfNeeded()
      }
      Self.storeScheduledMorningAlarmId(
        args["nextAlarmId"] as? String,
        nextFireIsToday: nextFireIsToday
      )
      Task {
        do {
          try await Self.scheduleMorningAlarmKit(
            hour: hour,
            minute: minute,
            soundName: soundName,
            dartWeekdays: weekdays,
            nextFireDate: nextFireDate,
            nextAlarmId: args["nextAlarmId"] as? String
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "schedule_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "syncMorningAlarmList":
      // 알람별 독립 등록의 단일 동기화 진입점(조정 방식).
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let rawAlarms = args["alarms"] as? [[String: Any]] else {
        result(FlutterError(code: "bad_args", message: "alarms required", details: nil))
        return
      }
      let specs: [PerAlarmSpec] = rawAlarms.compactMap { raw in
        guard let id = raw["id"] as? String,
              let hour = raw["hour"] as? Int,
              let minute = raw["minute"] as? Int else { return nil }
        return PerAlarmSpec(
          id: id,
          hour: hour,
          minute: minute,
          weekdays: Self.normalizedDartWeekdays(raw["weekdays"]),
          soundName: (raw["sound"] as? String) ?? ""
        )
      }
      let listNextFireDate: Date? =
        ((args["nextFireEpochMillis"] as? NSNumber)?.doubleValue)
          .map { Date(timeIntervalSince1970: $0 / 1000.0) }
      let listNextIsToday = listNextFireDate.map {
        Calendar.current.isDateInToday($0)
      }
      let listNextAlarmId = args["nextAlarmId"] as? String
      let fireImmediatelyAlarmId = args["fireImmediatelyAlarmId"] as? String
      _ = listNextIsToday
      let isSetupActive = (args["isSetupActive"] as? Bool) ?? false
      if !isSetupActive {
        Self.promoteMissedMorningFireIfNeeded()
      }
      // 스탬프 쌍(epoch+알람 id)은 sync 내부에서 함께 저장한다 — 여기서
      // id만 동기 저장하면 미션-중 스킵 때 epoch만 옛값으로 남아, 놓친
      // 발화 승격이 '다음 알람'으로 오귀속된다(같은 날 뒤 알람 오완료).
      Task {
        let counts = await Self.syncMorningAlarmList(
          specs: specs,
          nextAlarmId: listNextAlarmId,
          nextFireDate: listNextFireDate,
          fireImmediatelyAlarmId: fireImmediatelyAlarmId
        )
        await MainActor.run { result(counts) }
      }

    case "scheduleEveningMission":
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hour = args["hour"] as? Int,
            let minute = args["minute"] as? Int else {
        result(FlutterError(code: "bad_args", message: "hour/minute required", details: nil))
        return
      }
      let soundName = Self.validatedMorningAlarmKitSoundName(args["soundName"] as? String)
      // Dart가 계산한 실제 다음 발화 날짜 — 오늘/내일 추측을 없앤다.
      let eveningNextFireDate: Date? = ((args["nextFireEpochMillis"] as? NSNumber)?.doubleValue)
        .map { Date(timeIntervalSince1970: $0 / 1000.0) }
      Task {
        do {
          try await Self.scheduleEveningAlarmKit(
            hour: hour,
            minute: minute,
            soundName: soundName,
            nextFireDate: eveningNextFireDate
          )
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(
              FlutterError(
                code: "schedule_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }

    case "getMorningNextFireEpochMillis":
      result(UserDefaults.standard.double(forKey: Self.morningNextFireEpochKey))

    case "getEveningNextFireEpochMillis":
      result(UserDefaults.standard.double(forKey: Self.eveningNextFireEpochKey))

    case "consumeOpenMissionFlag":
      let flag = UserDefaults.standard.bool(forKey: "pendingMission")
      if flag {
        UserDefaults.standard.set(false, forKey: "pendingMission")
      }
      result(flag)

    case "consumePendingMissionKind":
      let flag = UserDefaults.standard.bool(forKey: "pendingMission")
      guard flag else {
        // 미션 부활: 미션 진행 중 앱이 죽어도(강제종료 포함) 플래그와 주인
        // id는 남는다. 오늘 시작한 미션의 주인이 아직 미완료면 앱을 연
        // 것만으로 미션을 되살린다 — 아멘 또는 자정만이 출구(실측
        // 2026-07-10 10:42: 미션 중 강제종료 후 재진입 때 미션 실종).
        if Self.isMorningMissionInProgress() {
          let owner = Self.getMorningActiveAlarmId() ?? ""
          let ownerCompleted = !owner.isEmpty
            && UserDefaults.standard.string(
              forKey: Self.morningCompletedPerAlarmPrefix + owner
            ) == Self.todayKey()
          if !ownerCompleted {
            NSLog("[ALARMKIT] in-progress mission resurrected on consume (owner=\(owner))")
            result(owner.isEmpty ? "morning" : "morning:\(owner)")
            return
          }
        }
        result(nil)
        return
      }
      let kind = UserDefaults.standard.string(forKey: "pendingMissionKind") ?? "morning"
      // 울린 알람의 id는 정지 인텐트가 실어 보낸 값이 진실이다.
      // ⚠️ scheduledMorningAlarmId 폴백 금지 — 재예약 때 '다음 알람'으로
      // 덮여, 알림 탭 재진입 미션의 아멘이 다음 알람에 완료 도장을 찍는
      // 오프바이원이 된다(실측 2026-07-10: 10:25 울림→10:30 도장,
      // 10:30 울림→10:40 도장 → 10:40 미션 실종의 뿌리). 대기표에 id가
      // 없으면 '진행 중 미션의 주인' 키만 믿고, 그마저 없으면 id 없이
      // 넘긴다(아멘의 방금-지나간-알람 추론이 처리).
      let firedAlarmId = UserDefaults.standard.string(forKey: "pendingMissionAlarmId")
        ?? Self.getMorningActiveAlarmId()
      UserDefaults.standard.set(false, forKey: "pendingMission")
      UserDefaults.standard.removeObject(forKey: "pendingMissionKind")
      UserDefaults.standard.removeObject(forKey: "pendingMissionSource")
      UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmId")
      if kind == "morning",
         let alarmId = firedAlarmId,
         !alarmId.isEmpty {
        result("morning:\(alarmId)")
      } else {
        result(kind)
      }

    case "markMorningMissionCompleted":
      // Amen: stamp today's date so stray retry alarms are ignored (perform()
      // checks this). Cleared implicitly tomorrow (date no longer matches).
      // 도장 날짜는 '울린 날'(미션 시작일) — 자정 직전 알람을 자정 넘겨
      // 아멘하면 다음날 것으로 찍혀 그날 알람이 선완료되던 결함.
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      let stampDate =
        Self.getMorningStartedDate()
        ?? f.string(from: Date())
      Self.setMorningInProgress(false)
      UserDefaults.standard.set(false, forKey: "pendingMission")
      UserDefaults.standard.removeObject(forKey: "pendingMissionKind")
      UserDefaults.standard.removeObject(forKey: "pendingMissionSource")
      UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmId")
      Self.setMorningCompletedDate(stampDate)
      Self.setMorningActiveAlarmId(nil)
      Self.setMorningStartedDate(nil)
      // 사다리를 지우므로 배치 서명도 무효 — 다음 재예약이 생략되면 안 된다.
      UserDefaults.standard.removeObject(forKey: Self.morningBatchSignatureKey)
      // 멀티 알람: 완료를 알람별로도 기록한다(같은 날 다른 알람은 계속 유효).
      // 폴백 금지: scheduledMorningAlarmId는 재예약 때 '다음 알람'으로 덮여
      // 방금 완료한 알람이 아니라 다음 알람에 도장이 찍힌다 — 그러면 같은 날
      // 다음 알람의 stop이 '오늘 완료'로 오판돼 미션이 안 열린다(실측
      // 2026-07-10 9:10 아멘 → 9:15 미션 무반응). id를 모르면 Dart가
      // '방금 지나간 알람'을 추론해 보낸다.
      let completedAlarmId = (call.arguments as? [String: Any])?["alarmId"] as? String
      if let completedAlarmId, !completedAlarmId.isEmpty {
        UserDefaults.standard.set(
          stampDate,
          forKey: Self.morningCompletedPerAlarmPrefix + completedAlarmId
        )
      }
      if #available(iOS 26.0, *) {
        // 완료된 알람의 등록만 정지 — 전체 stop은 같은 날 뒤 알람의 오늘
        // 발생을 건너뛰게 한다(pause 없이 열린 미션의 아멘 케이스).
        // 울리던 알람 자체는 stopMorningAlarmKitAlert가 별도로 멈춘다.
        if let completedAlarmId, !completedAlarmId.isEmpty {
          Self.stopPerAlarmRegistration(appAlarmId: completedAlarmId)
        }
        try? AlarmManager.shared.stop(id: Self.morningId)
        Self.cancelMorningMainFallback()
        try? AlarmManager.shared.stop(id: Self.morningSnoozeId)
        try? AlarmManager.shared.cancel(id: Self.morningSnoozeId)
        for rid in Self.morningRetryIds {
          try? AlarmManager.shared.stop(id: rid)
          try? AlarmManager.shared.cancel(id: rid)
        }
        Self.purgeStaleRetrySlots(["A1000040", "A1000050"])
        Self.cancelMorningMissionExitLadder()
        Self.cancelStopEcho(kind: "morning")
      }
      result(true)

    case "markEveningMissionCompleted":
      // Amen: stamp today's date so stray evening retries are ignored.
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      Self.setEveningInProgress(false)
      // 도장 날짜는 '울린 날'(시작일) 기준 — 아침과 동일 원칙.
      // (시작일은 도장에 쓴 '뒤에' 지워야 한다 — 순서 주의.)
      let eveningStamp =
        Self.getEveningStartedDate()
        ?? f.string(from: Date())
      Self.setEveningStartedDate(nil)
      Self.setEveningCompletedDate(eveningStamp)
      // 완료로 사다리 base가 내일로 바뀌므로 서명 무효화(재빌드 유도).
      UserDefaults.standard.removeObject(forKey: Self.eveningBatchSignatureKey)
      if #available(iOS 26.0, *) {
        Self.cancelEveningChase()
        Self.cancelStopEcho(kind: "evening")
      }
      // 미션 도중 잔여 알람이 남긴 저녁 대기표를 아멘이 반드시 청소한다 —
      // 안 지우면 아멘 직후 미션이 한 번 더 뜬다(아침과 동일한 정리).
      if UserDefaults.standard.string(forKey: "pendingMissionKind") == "evening" {
        UserDefaults.standard.set(false, forKey: "pendingMission")
        UserDefaults.standard.removeObject(forKey: "pendingMissionKind")
        UserDefaults.standard.removeObject(forKey: "pendingMissionSource")
        UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmId")
      }
      result(true)

    case "clearMorningMissionCompleted":
      // User explicitly re-saved/re-enabled the morning alarm. Allow same-day
      // test schedules to build a retry ladder again after a prior Amen.
      Self.setMorningInProgress(false)
      Self.setMorningCompletedDate(nil)
      UserDefaults.standard.removeObject(forKey: Self.morningBatchSignatureKey)
      // alarmIds가 오면 그 알람들의 도장만 지운다 — 전부 지우면 늦은 알람을
      // 추가하는 저장이 이미 완료한 알람의 도장까지 지워 유령이 된다.
      if let onlyIds = (call.arguments as? [String: Any])?["alarmIds"] as? [String] {
        for id in onlyIds {
          UserDefaults.standard.removeObject(
            forKey: Self.morningCompletedPerAlarmPrefix + id
          )
        }
      } else {
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix(Self.morningCompletedPerAlarmPrefix) {
          UserDefaults.standard.removeObject(forKey: key)
        }
      }
      result(true)

    case "clearEveningMissionCompleted":
      // User explicitly re-saved/re-enabled the evening alarm. Allow same-day
      // tests after a prior Amen.
      Self.setEveningInProgress(false)
      Self.setEveningCompletedDate(nil)
      result(true)

    case "stopEveningAlert":
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      Task {
        try? AlarmManager.shared.stop(id: Self.eveningId)
        for rid in Self.eveningRetryIds {
          try? AlarmManager.shared.stop(id: rid)
          try? AlarmManager.shared.cancel(id: rid)
        }
        try? AlarmManager.shared.stop(id: Self.eveningSnoozeId)
        try? AlarmManager.shared.cancel(id: Self.eveningSnoozeId)
        try? AlarmManager.shared.stop(id: Self.eveningMissionWatchdogId)
        try? AlarmManager.shared.cancel(id: Self.eveningMissionWatchdogId)
        Self.setEveningInProgress(false)
        Self.setPending(kind: "evening", pending: false)
        await MainActor.run { result(true) }
      }

    case "closeCurrentScene":
      // Amen post-completion UX: ask iOS to close the current scene/window using
      // the public scene API. This is a best-effort request, not a process kill.
      DispatchQueue.main.async {
        result(Self.requestCurrentSceneDestruction())
      }

    case "openSubscriptionManagement":
      DispatchQueue.main.async {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }

    case "openExternalUrl":
      guard let args = call.arguments as? [String: Any],
            let rawUrl = args["url"] as? String,
            let url = URL(string: rawUrl),
            ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
        result(false)
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }

    case "stopAllActiveSounds":
      // 미션 화면 진입 즉시 울리고 있는 모든 AlarmKit 알람음을 강제 정지한다.
      // cancel은 하지 않는다 — 추격 사다리는 살려두되 소리만 즉각 끈다.
      guard #available(iOS 26.0, *) else {
        result(true)
        return
      }
      // 아침 알람 관련
      try? AlarmManager.shared.stop(id: Self.morningId)
      try? AlarmManager.shared.stop(id: Self.morningSnoozeId)
      for rid in Self.morningRetryIds {
        try? AlarmManager.shared.stop(id: rid)
      }
      for wid in Self.morningMissionWatchdogIds {
        try? AlarmManager.shared.stop(id: wid)
      }
      try? AlarmManager.shared.stop(id: Self.morningMissionWatchdogId)
      try? AlarmManager.shared.stop(id: Self.morningStopEchoId)
      // 저녁 알람 관련
      try? AlarmManager.shared.stop(id: Self.eveningId)
      try? AlarmManager.shared.stop(id: Self.eveningSnoozeId)
      for rid in Self.eveningRetryIds {
        try? AlarmManager.shared.stop(id: rid)
      }
      for wid in Self.eveningMissionWatchdogIds {
        try? AlarmManager.shared.stop(id: wid)
      }
      try? AlarmManager.shared.stop(id: Self.eveningMissionWatchdogId)
      try? AlarmManager.shared.stop(id: Self.eveningStopEchoId)
      // 알람별 등록(per-alarm) — 정지만, 취소는 안 한다.
      Self.stopAllPerAlarmRegistrations(cancelToo: false)
      NSLog("[ALARMKIT] stopAllActiveSounds: all ringing alarms silenced")
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func requestCurrentSceneDestruction() -> Bool {
    guard #available(iOS 13.0, *) else { return false }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { scene in
      scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
    }) ?? scenes.first else {
      NSLog("[ALARMKIT] closeCurrentScene: no UIWindowScene found")
      return false
    }

    UIApplication.shared.requestSceneSessionDestruction(
      scene.session,
      options: nil
    ) { error in
      NSLog("[ALARMKIT] closeCurrentScene failed: \(error.localizedDescription)")
    }
    NSLog("[ALARMKIT] closeCurrentScene requested")
    return true
  }

  // ── Production morning alarm via AlarmKit (iOS 26+) ──
  // Main alarm repeats weekly at the user's morning time. The retry ladder is
  // fixed one-shot dates for the next occurrence, so sub-minute retries are
  // possible and Amen can cancel today's remaining retries without deleting
  // tomorrow's main schedule.
  private static let retryIntervalSeconds = 30
  private static let retryCount = 20
  // 저녁 재울림: 1분 간격 10발 = 약 10분 커버(사용자 결정). 아침이 알람별
  // 독립 등록으로 슬림해져(총 ~10건) 예산 걱정 없이 늘릴 수 있다.
  private static let eveningRetryCount = 10
  private static let eveningRetryIntervalSeconds = 60
  // Sweep a slightly wider id range than the active ladder to remove stale
  // slots left by older builds or interrupted scheduling attempts.
  private static let maxRetrySlots = 24
  // Dart DateTime weekdays: Monday=1 ... Sunday=7.
  private static let defaultDartWeekdays = [1, 2, 3, 4, 5, 6, 7]
  private static let defaultMorningAlarmKitSoundName = "god_morning_1.wav"
  private static let morningAlarmKitSoundNameKey = "grace_morning_alarmkit_sound_name"
  private static let allowedMorningAlarmKitSoundNames = [
    "god_morning_1.wav",
    "god_morning_2.wav",
    "god_morning_3.wav",
    "god_morning_4.wav",
    "god_morning_5.wav",
    "god_morning_6.wav",
    "god_morning_7.wav",
    "god_morning_9.wav",
    "god_morning_10.wav",
  ]
  // Fixed, predictable retry alarm ids (morning ladder slots).
  private static let morningRetryIds: [UUID] = (1...retryCount).compactMap {
    UUID(uuidString: String(format: "A1000040-0000-4000-8000-%012X", $0))
  }
  // Fixed, predictable legacy retry ids. These are cancelled defensively so
  // older builds do not leave stale mission-exit alarms alive.
  private static let morningMissionWatchdogIds: [UUID] = (1...retryCount).compactMap {
    UUID(uuidString: String(format: "A1000050-0000-4000-8000-%012X", $0))
  }
  private static let eveningRetryIds: [UUID] = (1...eveningRetryCount).compactMap {
    UUID(uuidString: String(format: "A1000060-0000-4000-8000-%012X", $0))
  }

  @available(iOS 26.0, *)
  private static func cancelMorningMainFallback() {
    guard let raw = UserDefaults.standard.string(forKey: morningMainFallbackIdKey),
          let id = UUID(uuidString: raw) else { return }
    try? AlarmManager.shared.stop(id: id)
    try? AlarmManager.shared.cancel(id: id)
    UserDefaults.standard.removeObject(forKey: morningMainFallbackIdKey)
  }

  @available(iOS 26.0, *)
  private static func scheduleMorningMainFallback(
    at fireDate: Date,
    soundName: String,
    intentAlarmId: String? = nil
  ) async {
    cancelMorningMainFallback()
    guard fireDate > Date() else { return }
    let id = UUID()
    do {
      try await scheduleOneMorningFixedAlarm(
        id: id,
        fireDate: fireDate,
        soundName: soundName,
        intentAlarmId: intentAlarmId
      )
      UserDefaults.standard.set(id.uuidString, forKey: morningMainFallbackIdKey)
      NSLog("[ALARMKIT] main fallback armed at \(fireDate) id=\(id)")
      return
    } catch {
      NSLog("[ALARMKIT] fixed fallback failed for \(fireDate): \(error.localizedDescription) — retrying as relative one-shot")
    }
    // 실측(13:19:49, 13:28:56): .fixed 폴백이 invalidInput으로 거부된 사례.
    // 메인 알람이 검증된 relative 형태(1회성)로 같은 시각을 다시 시도한다.
    let hour = Calendar.current.component(.hour, from: fireDate)
    let minute = Calendar.current.component(.minute, from: fireDate)
    let relativeId = UUID()
    do {
      let schedule = Alarm.Schedule.relative(
        .init(time: .init(hour: hour, minute: minute), repeats: .never)
      )
      try await scheduleOneMorningAlarm(
        id: relativeId,
        schedule: schedule,
        soundName: soundName,
        intentAlarmId: intentAlarmId
      )
      UserDefaults.standard.set(relativeId.uuidString, forKey: morningMainFallbackIdKey)
      NSLog("[ALARMKIT] relative fallback armed \(hour):\(minute) id=\(relativeId)")
    } catch {
      NSLog("[ALARMKIT] relative fallback also failed: \(error.localizedDescription)")
    }
  }

  private static func morningBatchSignature(
    hour: Int,
    minute: Int,
    dartWeekdays: [Int],
    soundName: String,
    base: Date
  ) -> String {
    let days = dartWeekdays.sorted().map(String.init).joined(separator: ",")
    return "\(hour):\(minute)|\(days)|\(soundName)|\(Int(base.timeIntervalSince1970))"
  }

  // ── 알람별 독립 등록: 조정(reconcile) 동기화 ──

  struct PerAlarmSpec {
    let id: String
    let hour: Int
    let minute: Int
    let weekdays: [Int]
    let soundName: String
  }

  private static func loadStringMap(_ key: String) -> [String: String] {
    (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
  }

  /// 롤링 단일 알람 시대의 잔재(고정 morningId + 20슬롯)를 한 번만 정리.
  @available(iOS 26.0, *)
  private static func migrateToPerAlarmIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: migratedPerAlarmV1Key) else { return }
    try? AlarmManager.shared.stop(id: morningId)
    try? AlarmManager.shared.cancel(id: morningId)
    try? AlarmManager.shared.stop(id: morningSnoozeId)
    try? AlarmManager.shared.cancel(id: morningSnoozeId)
    cancelMorningMainFallback()
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    defaults.removeObject(forKey: morningBatchSignatureKey)
    defaults.set(true, forKey: migratedPerAlarmV1Key)
    NSLog("[ALARMKIT] migrated to per-alarm registrations")
  }

  /// 완료된 알람의 등록만 정지 — 전체 stop은 아직 안 울린 같은 날 뒤
  /// 알람의 오늘 발생을 건너뛰게 만든다(주간 반복의 stop = 현 주기 종료).
  @available(iOS 26.0, *)
  private static func stopPerAlarmRegistration(appAlarmId: String) {
    let uuidMap = loadStringMap(morningPerAlarmUuidMapKey)
    guard let raw = uuidMap[appAlarmId], let uuid = UUID(uuidString: raw) else { return }
    try? AlarmManager.shared.stop(id: uuid)
  }

  /// 미션 중 다른 알람이 못 울리게 전 등록을 정지한다. [cancelToo]면 예약도
  /// 제거하고 맵을 비운다 — 다음 동기화가 전부 '새 UUID'로 재등록하므로
  /// 같은 id 취소→재등록 레이스가 구조적으로 불가능해진다.
  @available(iOS 26.0, *)
  private static func stopAllPerAlarmRegistrations(cancelToo: Bool) {
    let uuidMap = loadStringMap(morningPerAlarmUuidMapKey)
    for (_, raw) in uuidMap {
      guard let uuid = UUID(uuidString: raw) else { continue }
      try? AlarmManager.shared.stop(id: uuid)
      if cancelToo {
        try? AlarmManager.shared.cancel(id: uuid)
      }
    }
    if cancelToo {
      UserDefaults.standard.removeObject(forKey: morningPerAlarmUuidMapKey)
      UserDefaults.standard.removeObject(forKey: morningPerAlarmSigMapKey)
      UserDefaults.standard.removeObject(forKey: morningLadderBaseEpochKey)
    }
  }

  /// 축소 사다리(+4/8/12/16분). base가 안 바뀌었고 슬롯이 데몬에 살아 있으면
  /// 아무것도 하지 않는다.
  @available(iOS 26.0, *)
  private static func reconcileMorningLadder(
    base: Date?,
    soundName: String,
    intentAlarmId: String?
  ) async {
    let defaults = UserDefaults.standard
    let slotIds = Array(morningRetryIds.prefix(morningLadderSlotOffsets.count))
    guard let base else {
      for rid in slotIds {
        try? AlarmManager.shared.stop(id: rid)
        try? AlarmManager.shared.cancel(id: rid)
      }
      defaults.removeObject(forKey: morningLadderBaseEpochKey)
      return
    }
    let epoch = Int(base.timeIntervalSince1970)
    // 슬롯 '전부'가 데몬에 살아 있을 때만 스킵 — 일부만 남은 반쪽 사다리는
    // 다음 동기화가 자가치유한다(any 조건이던 시절의 구멍).
    if defaults.integer(forKey: morningLadderBaseEpochKey) == epoch,
       defaults.string(forKey: morningLadderSoundKey) == soundName,
       let daemonIds = (try? AlarmManager.shared.alarms)?.map(\.id),
       slotIds.allSatisfy(daemonIds.contains) {
      return
    }
    for rid in slotIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    let now = Date()
    for (i, offset) in morningLadderSlotOffsets.enumerated() {
      let fireDate = base.addingTimeInterval(offset)
      if fireDate <= now { continue }
      do {
        try await scheduleOneMorningFixedAlarm(
          id: slotIds[i],
          fireDate: fireDate,
          soundName: soundName,
          intentAlarmId: intentAlarmId
        )
      } catch {
        NSLog("[ALARMKIT] ladder slot \(i + 1) failed: \(error.localizedDescription)")
      }
    }
    defaults.set(epoch, forKey: morningLadderBaseEpochKey)
    defaults.set(soundName, forKey: morningLadderSoundKey)
  }

  /// 미션 방치(아멘 없이 이탈) 시: pause가 취소했던 알람별 등록을 저장된
  /// 스펙에서 되살린다. 안 그러면 사용자가 앱을 다시 안 열 경우 내일 이후
  /// 알람이 전부 침묵한다. 오늘 이미 울린 알람의 주간 반복은 다음 발생일이
  /// 미래라 오늘 다시 울리지 않는다.
  @available(iOS 26.0, *)
  private static func reRegisterPerAlarmsAfterAbandon() async {
    guard
      let raw = UserDefaults.standard.array(forKey: morningSpecsKey)
        as? [[String: Any]],
      !raw.isEmpty
    else { return }
    var uuidMap = loadStringMap(morningPerAlarmUuidMapKey)
    var sigMap = loadStringMap(morningPerAlarmSigMapKey)
    // 이미 등록이 살아 있으면(중복 방지) 아무것도 하지 않는다.
    guard uuidMap.isEmpty else { return }
    for item in raw {
      guard let id = item["id"] as? String,
            let hour = item["hour"] as? Int,
            let minute = item["minute"] as? Int else { continue }
      let weekdays = normalizedDartWeekdays(item["weekdays"])
      let sound = validatedMorningAlarmKitSoundName(item["sound"] as? String)
      let uuid = UUID()
      do {
        try await scheduleOneMorningRelativeAlarm(
          id: uuid,
          hour: hour,
          minute: minute,
          dartWeekdays: weekdays,
          soundName: sound,
          intentAlarmId: id
        )
        uuidMap[id] = uuid.uuidString
        let days = weekdays.sorted().map(String.init).joined(separator: ",")
        sigMap[id] = "\(hour):\(minute)|\(days)|\(sound)"
      } catch {
        NSLog("[ALARMKIT] abandon re-register \(id) failed: \(error.localizedDescription)")
      }
    }
    UserDefaults.standard.set(uuidMap, forKey: morningPerAlarmUuidMapKey)
    UserDefaults.standard.set(sigMap, forKey: morningPerAlarmSigMapKey)
    NSLog("[ALARMKIT] abandon: re-registered \(uuidMap.count) per-alarm regs")
  }

  private static let lastOSVersionKey = "grace_last_os_version"

  /// iOS 업그레이드가 업그레이드 전 AlarmKit 등록을 조용히 무효화한 실측
  /// 사례가 있다(iOS 26.1→26.2b3, Apple 포럼 809398 / FB21273655). OS 버전이
  /// 바뀌면 조정 서명 전부를 무효화해 다음 동기화가 등록 전체를 새 UUID로
  /// 강제 재구축하게 한다. 첫 실행은 기준 버전만 기록한다.
  private static func invalidateSignaturesIfOSChanged() {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    let current = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    let defaults = UserDefaults.standard
    let last = defaults.string(forKey: lastOSVersionKey)
    if last == current { return }
    defaults.set(current, forKey: lastOSVersionKey)
    guard let last else { return }
    defaults.removeObject(forKey: morningPerAlarmSigMapKey)
    defaults.removeObject(forKey: morningBatchSignatureKey)
    defaults.removeObject(forKey: eveningBatchSignatureKey)
    // 사다리의 조정-스킵 근거도 함께 무효화 — 안 지우면 '데몬 목록에는
    // 보이지만 죽은' 업그레이드 잔해 사다리가 스킵으로 살아남는다.
    defaults.removeObject(forKey: morningLadderBaseEpochKey)
    defaults.removeObject(forKey: morningLadderSoundKey)
    NSLog("[ALARMKIT] OS \(last) -> \(current): signatures invalidated, full re-registration forced")
  }

  /// 앱 알람 목록을 데몬 등록과 '조정'한다: 바뀐 알람만 새 UUID로 재등록,
  /// 사라진 알람만 취소, 나머지는 건드리지 않는다. 아멘 후에도 이 함수 하나
  /// 뿐 — 주간 반복은 OS가 이어가므로 재예약이 없다.
  @available(iOS 26.0, *)
  private static func syncMorningAlarmList(
    specs: [PerAlarmSpec],
    nextAlarmId: String?,
    nextFireDate: Date?,
    fireImmediatelyAlarmId: String?
  ) async -> [String: Int] {
    migrateToPerAlarmIfNeeded()
    invalidateSignaturesIfOSChanged()
    // 주인 알람 삭제/비활성 감지는 미션-중 스킵보다 반드시 먼저 — 삭제는
    // 대개 미션이 미완료일 때 일어나고, 스킵 뒤에 두면 부활 고리(오늘
    // 시작·미완료 → 미션·알림 재무장)가 영원히 안 걷힌다(실측 2026-07-16:
    // 알람을 지웠는데 미션 탭이 계속 옴). 여기서 상태를 걷으면 아래 스킵
    // 가드도 통과되어 삭제된 등록 자체도 1단계에서 정리된다.
    var ownerRemoved = 0
    if isMorningMissionInProgress(),
       let owner = Self.getMorningActiveAlarmId(),
       !owner.isEmpty,
       !specs.contains(where: { $0.id == owner }) {
      Self.setMorningInProgress(false)
      Self.setMorningActiveAlarmId(nil)
      Self.setMorningStartedDate(nil)
      setPending(kind: "morning", pending: false)
      UserDefaults.standard.removeObject(forKey: "pendingMissionAlarmId")
      cancelMorningMissionExitLadder()
      cancelStopEcho(kind: "morning")
      ownerRemoved = 1
      NSLog("[ALARMKIT] mission owner deleted/disabled — mission state cleared")
    }
    if isMorningMissionInProgress() {
      NSLog("[ALARMKIT] peralarm sync skipped: mission in progress")
      return ["scheduled": 0, "skipped": 0, "failed": 0, "ownerRemoved": 0]
    }

    let defaults = UserDefaults.standard
    var uuidMap = loadStringMap(morningPerAlarmUuidMapKey)
    var sigMap = loadStringMap(morningPerAlarmSigMapKey)
    let daemonIds = (try? AlarmManager.shared.alarms)?.map(\.id)
    var scheduled = 0
    var skipped = 0
    var failed = 0

    // 1) 삭제·비활성 알람 등록 해제 — 유령 알람 원천 차단.
    let incomingIds = Set(specs.map(\.id))
    for (appId, raw) in uuidMap where !incomingIds.contains(appId) {
      if let uuid = UUID(uuidString: raw) {
        try? AlarmManager.shared.stop(id: uuid)
        try? AlarmManager.shared.cancel(id: uuid)
      }
      uuidMap.removeValue(forKey: appId)
      sigMap.removeValue(forKey: appId)
    }

    // 2) 알람별 조정.
    for spec in specs {
      let days = spec.weekdays.sorted().map(String.init).joined(separator: ",")
      let sound = validatedMorningAlarmKitSoundName(spec.soundName)
      let sig = "\(spec.hour):\(spec.minute)|\(days)|\(sound)"
      let existingUuid = uuidMap[spec.id].flatMap(UUID.init(uuidString:))
      // 데몬 목록을 못 읽었을 때는 서명을 신뢰한다(다음 열기 때 자가치유).
      let presentInDaemon = existingUuid.map { u in
        daemonIds?.contains(u) ?? true
      } ?? false
      if sigMap[spec.id] == sig, presentInDaemon {
        skipped += 1
        continue
      }
      if let old = existingUuid {
        try? AlarmManager.shared.stop(id: old)
        try? AlarmManager.shared.cancel(id: old)
      }
      var registered: UUID?
      for _ in 0..<2 {
        let candidate = UUID()
        do {
          try await scheduleOneMorningRelativeAlarm(
            id: candidate,
            hour: spec.hour,
            minute: spec.minute,
            dartWeekdays: spec.weekdays,
            soundName: sound,
            intentAlarmId: spec.id
          )
          registered = candidate
          break
        } catch {
          NSLog("[ALARMKIT] register \(spec.id) failed: \(error.localizedDescription)")
        }
      }
      if let registered {
        uuidMap[spec.id] = registered.uuidString
        sigMap[spec.id] = sig
        scheduled += 1
      } else {
        uuidMap.removeValue(forKey: spec.id)
        sigMap.removeValue(forKey: spec.id)
        failed += 1
      }
    }
    defaults.set(uuidMap, forKey: morningPerAlarmUuidMapKey)
    defaults.set(sigMap, forKey: morningPerAlarmSigMapKey)
    // 방치 복구용 스펙 원본 저장(plist-safe 딕셔너리 배열).
    defaults.set(
      specs.map { spec -> [String: Any] in
        [
          "id": spec.id,
          "hour": spec.hour,
          "minute": spec.minute,
          "weekdays": spec.weekdays,
          "sound": spec.soundName,
        ]
      },
      forKey: morningSpecsKey
    )

    // 3) 다음 발화 기록(잠금·놓친 울림 승격의 근거) — epoch와 알람 id는
    //    반드시 한 쌍으로 갱신한다(케이스 레벨 분리 저장 금지).
    if let nextFireDate {
      storeMorningNextFireEpoch(nextFireDate)
      storeScheduledMorningAlarmId(
        nextAlarmId,
        nextFireIsToday: Calendar.current.isDateInToday(nextFireDate)
      )
    } else {
      clearMorningNextFireEpoch()
      storeScheduledMorningAlarmId(nextAlarmId, nextFireIsToday: false)
    }

    // 4) 다음 발화용 축소 사다리 + 워치독 소리 저장.
    let nextSound = validatedMorningAlarmKitSoundName(
      specs.first(where: { $0.id == nextAlarmId })?.soundName
    )
    storeMorningAlarmKitSoundName(nextSound)
    await reconcileMorningLadder(
      base: nextFireDate,
      soundName: nextSound,
      intentAlarmId: nextAlarmId
    )

    // 5) 미션 중 시간이 지나간 알람의 즉시 재울림(1회성, 새 UUID).
    if let fid = fireImmediatelyAlarmId {
      let sound = validatedMorningAlarmKitSoundName(
        specs.first(where: { $0.id == fid })?.soundName
      )
      await scheduleMorningMainFallback(
        at: Date().addingTimeInterval(3),
        soundName: sound,
        intentAlarmId: fid
      )
    }

    // 6) 검증 — 등록돼 있어야 할 알람이 데몬에 실제로 보이는지.
    if let after = try? AlarmManager.shared.alarms {
      let afterIds = Set(after.map(\.id))
      let expected = uuidMap.values.compactMap(UUID.init(uuidString:))
      let present = expected.filter(afterIds.contains).count
      NSLog("[ALARMKIT] peralarm sync: +\(scheduled) =\(skipped) x\(failed) present \(present)/\(expected.count)")
    } else {
      NSLog("[ALARMKIT] peralarm sync: +\(scheduled) =\(skipped) x\(failed) (verify unavailable)")
    }
    return [
      "scheduled": scheduled,
      "skipped": skipped,
      "failed": failed,
      "ownerRemoved": ownerRemoved,
    ]
  }

  @available(iOS 26.0, *)
  private static func purgeStaleRetrySlots(_ prefixes: [String]) {
    // 옛 빌드 잔재 청소는 실행당 접두사별 1회면 충분하다. 활성 슬롯(1~20)은
    // 모든 호출부가 명시적으로 취소하므로, 매 동기화마다 존재하지 않는 id
    // 수십 개에 맹목 취소(unknownAlarm 에러 폭풍)를 보내 데몬을 바쁘게
    // 만들 이유가 없다.
    legacyPurgeLock.lock()
    let pending = prefixes.filter { !purgedLegacyPrefixes.contains($0) }
    pending.forEach { purgedLegacyPrefixes.insert($0) }
    legacyPurgeLock.unlock()
    for prefix in pending {
      for i in 1...maxRetrySlots {
        if let id = UUID(uuidString: String(format: "\(prefix)-0000-4000-8000-%012X", i)) {
          try? AlarmManager.shared.stop(id: id)
          try? AlarmManager.shared.cancel(id: id)
        }
      }
    }
  }

  @available(iOS 26.0, *)
  private static func scheduleMorningAlarmKit(
    hour: Int,
    minute: Int,
    soundName: String,
    dartWeekdays: [Int],
    nextFireDate: Date? = nil,
    nextAlarmId: String? = nil
  ) async throws {
    invalidateSignaturesIfOSChanged()
    purgeStaleRetrySlots(["A1000040", "A1000050"])
    storeMorningAlarmKitSoundName(soundName)
    if isMorningMissionInProgress() {
      cancelMorningMainFallback()
      do {
        try await scheduleOneMorningRelativeAlarm(
          id: morningId,
          hour: hour,
          minute: minute,
          dartWeekdays: dartWeekdays,
          soundName: soundName
        )
      } catch {
        NSLog("[ALARMKIT] mission-sync main schedule failed: \(error.localizedDescription)")
        if let nextFireDate, nextFireDate > Date() {
          await scheduleMorningMainFallback(at: nextFireDate, soundName: soundName)
        }
      }
      try? AlarmManager.shared.stop(id: morningSnoozeId)
      try? AlarmManager.shared.cancel(id: morningSnoozeId)
      for rid in morningRetryIds {
        try? AlarmManager.shared.stop(id: rid)
        try? AlarmManager.shared.cancel(id: rid)
      }
      cancelMorningMissionExitLadder()
      NSLog("[ALARMKIT] morning schedule sync during active mission: retries/watchdogs remain paused")
      return
    }

    try? AlarmManager.shared.stop(id: morningSnoozeId)
    try? AlarmManager.shared.cancel(id: morningSnoozeId)
    cancelMorningMissionExitLadder()
    cancelMorningMainFallback()

    // Retry ladder base: the next relevant occurrence.
    // If ensureScheduled runs during today's active retry window, preserve the
    // remaining retries for today. After Amen, the completion stamp forces the
    // base date to tomorrow so today stays silent.
    let base: Date
    if let nextFireDate, nextFireDate > Date() {
      // Dart가 준 실제 다음 발화 날짜 — 오늘/내일 추측 없이 그대로 쓴다.
      // (내일 발화인데 오늘 기준 사다리를 되살리던 유령 알람 차단.)
      base = nextFireDate
    } else {
      base = retryBaseDate(
        hour: hour,
        minute: minute,
        preserveActiveWindow: true,
        completedDateKey: morningMissionCompletedDateKey,
        dartWeekdays: dartWeekdays
      )
    }
    // 동일 배치 재등록 생략: 앱 열기/중복 저장마다 취소+재등록 폭풍을 데몬에
    // 보내면, 직후 기기가 잠들 때 하드웨어 웨이크 무장이 밀려 알람이 늦게
    // 배달되는 실측 사례가 있다. 내용이 같고 메인 알람이 실제로 등록돼
    // 있으면 아무것도 만지지 않는다.
    let signature = Self.morningBatchSignature(
      hour: hour,
      minute: minute,
      dartWeekdays: dartWeekdays,
      soundName: soundName,
      base: base
    )
    if UserDefaults.standard.string(forKey: morningBatchSignatureKey) == signature,
       let existing = try? AlarmManager.shared.alarms,
       existing.contains(where: { $0.id == morningId }) {
      NSLog("[ALARMKIT] batch unchanged — skip rebuild (base=\(base))")
      return
    }
    UserDefaults.standard.removeObject(forKey: morningBatchSignatureKey)

    // epoch·메인·폴백·사다리 순서로, 어느 한 단계가 실패해도 나머지는 반드시
    // 진행한다. (예전엔 메인 알람의 duplicate-ID 실패가 사다리·epoch까지
    // 통째로 날려 '켜둔 알람이 무음으로 지나가는' 상태를 만들었다.)
    storeMorningNextFireEpoch(base)
    NSLog("[ALARMKIT-DIAG] schedule h=\(hour) m=\(minute) completedStamp=\(getMorningCompletedDate() ?? "nil") base=\(base)")

    // Main alarm at exact time, repeating on the user's selected weekdays.
    var mainScheduled = false
    do {
      try await scheduleOneMorningRelativeAlarm(
        id: morningId,
        hour: hour,
        minute: minute,
        dartWeekdays: dartWeekdays,
        soundName: soundName,
        intentAlarmId: nextAlarmId
      )
      mainScheduled = true
    } catch {
      NSLog("[ALARMKIT] main schedule failed after retries: \(error.localizedDescription)")
    }

    // 정시 울림 보호가 우선 — 폴백을 사다리(최대 20건 등록)보다 먼저 심는다.
    if !mainScheduled {
      await scheduleMorningMainFallback(at: base, soundName: soundName, intentAlarmId: nextAlarmId)
    }
    await scheduleMorningRetryLadder(baseDate: base, soundName: soundName, intentAlarmId: nextAlarmId)
    if mainScheduled {
      UserDefaults.standard.set(signature, forKey: morningBatchSignatureKey)
    }
    NSLog("[ALARMKIT] morning(main=\(mainScheduled)) + retries scheduled from \(base), sound=\(soundName)")
  }

  @available(iOS 26.0, *)
  private static func scheduleEveningAlarmKit(
    hour: Int,
    minute: Int,
    soundName: String,
    nextFireDate: Date? = nil
  ) async throws {
    invalidateSignaturesIfOSChanged()
    // 사다리 base: Dart가 준 실제 다음 발화 날짜를 그대로 쓴다. 시:분만으로
    // 추측하면 '지난 10분 이내의 오늘 시각'을 base로 잡아 설정 저장 직후
    // 유령 슬롯이 울린다(아침 유령 알람과 같은 클래스 — 실측 재현).
    let sigBase: Date
    if let nextFireDate, nextFireDate > Date() {
      sigBase = nextFireDate
    } else {
      sigBase = retryBaseDate(
        hour: hour,
        minute: minute,
        preserveActiveWindow: true,
        completedDateKey: eveningMissionCompletedDateKey,
        dartWeekdays: defaultDartWeekdays
      )
    }
    // 다음 발화 스탬프 + 실제 소리 저장 — 잠금 판정(유령 미션 방지)과
    // 추격 소리의 근거. 스킵 여부와 무관하게 항상 최신으로 유지한다.
    UserDefaults.standard.set(
      sigBase.timeIntervalSince1970 * 1000.0,
      forKey: eveningNextFireEpochKey
    )
    UserDefaults.standard.set(soundName, forKey: eveningAlarmKitSoundNameKey)
    // 조정 스킵: 시각·소리·사다리 base가 같고 메인 등록이 살아 있으면
    // 데몬을 건드리지 않는다(아침과 동일 원칙). v3: base 산정 방식 변경.
    let signature = "v3|\(hour):\(minute)|\(soundName)|\(Int(sigBase.timeIntervalSince1970))"
    if UserDefaults.standard.string(forKey: eveningBatchSignatureKey) == signature,
       let existing = try? AlarmManager.shared.alarms,
       existing.contains(where: { $0.id == eveningId }) {
      NSLog("[ALARMKIT] evening unchanged — skip rebuild")
      return
    }
    UserDefaults.standard.removeObject(forKey: eveningBatchSignatureKey)

    purgeStaleRetrySlots(["A1000060"])
    try? AlarmManager.shared.stop(id: eveningSnoozeId)
    try? AlarmManager.shared.cancel(id: eveningSnoozeId)
    try? AlarmManager.shared.stop(id: eveningMissionWatchdogId)
    try? AlarmManager.shared.cancel(id: eveningMissionWatchdogId)

    let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    let weekdays: [Locale.Weekday] = [
      .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]
    let schedule = Alarm.Schedule.relative(
      .init(time: time, repeats: .weekly(weekdays))
    )
    try await scheduleOneMissionAlarm(
      id: eveningId,
      schedule: schedule,
      titleText: "Evening blessing",
      kind: "evening",
      source: "alarmkit_evening_stop",
      soundName: soundName
    )
    let base = sigBase
    await scheduleEveningRetryLadder(baseDate: base, soundName: soundName)
    UserDefaults.standard.set(signature, forKey: eveningBatchSignatureKey)
    NSLog("[ALARMKIT] evening + \(eveningRetryCount) fixed retries scheduled from \(base), sound=\(soundName)")
  }

  /// Schedule a single weekly morning alarm with the mission stop intent.
  /// Used for the main recurring alarm.
  @available(iOS 26.0, *)
  private static func scheduleOneMorningRelativeAlarm(
    id: UUID,
    hour: Int,
    minute: Int,
    dartWeekdays: [Int],
    soundName: String,
    intentAlarmId: String? = nil
  ) async throws {
    let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    let schedule = Alarm.Schedule.relative(
      .init(time: time, repeats: .weekly(localeWeekdays(from: dartWeekdays)))
    )
    try await scheduleOneMorningAlarm(
      id: id,
      schedule: schedule,
      soundName: soundName,
      intentAlarmId: intentAlarmId
    )
  }

  /// Schedule a one-shot fixed-date retry alarm with the same mission intents.
  @available(iOS 26.0, *)
  private static func scheduleOneMorningFixedAlarm(
    id: UUID,
    fireDate: Date,
    soundName: String,
    intentAlarmId: String? = nil
  ) async throws {
    try await scheduleOneMorningAlarm(
      id: id,
      schedule: .fixed(fireDate),
      soundName: soundName,
      intentAlarmId: intentAlarmId
    )
  }

  @available(iOS 26.0, *)
  private static func scheduleOneEveningFixedAlarm(
    id: UUID,
    fireDate: Date,
    soundName: String
  ) async throws {
    try await scheduleOneMissionAlarm(
      id: id,
      schedule: .fixed(fireDate),
      titleText: "Evening blessing",
      kind: "evening",
      source: "alarmkit_evening_retry_stop",
      soundName: soundName
    )
  }

  @available(iOS 26.0, *)
  private static func scheduleOneMorningAlarm(
    id: UUID,
    schedule: Alarm.Schedule,
    soundName: String,
    intentAlarmId: String? = nil
  ) async throws {
    try await scheduleOneMissionAlarm(
      id: id,
      schedule: schedule,
      titleText: "God Morning",
      kind: "morning",
      source: "alarmkit_stop",
      soundName: soundName,
      intentAlarmId: intentAlarmId
    )
  }

  @available(iOS 26.0, *)
  private static func scheduleOneMissionAlarm(
    id: UUID,
    schedule: Alarm.Schedule,
    titleText: String,
    kind: String,
    source: String,
    soundName: String,
    intentAlarmId: String? = nil
  ) async throws {
    try? AlarmManager.shared.stop(id: id)
    try? AlarmManager.shared.cancel(id: id)
    // 취소 반영을 폴링으로 기다리지 않는다(슬롯 20개 × 최대 1.5s = 배치가
    // 수십 초까지 늘어져 데몬 혼란 창이 커진다). 취소 지연으로 duplicate-ID가
    // 나면 아래 재시도 2·3차(stop+cancel+대기 후 재예약)가 흡수한다.

    let title = LocalizedStringResource(stringLiteral: titleText)
    let stopButton = AlarmButton(
      text: LocalizedStringResource(stringLiteral: "Stop"),
      textColor: .white,
      systemImageName: "stop.circle"
    )
    let alert = AlarmPresentation.Alert(
      title: title,
      stopButton: stopButton
    )
    let presentation = AlarmPresentation(alert: alert)
    let attributes = AlarmAttributes<GraceAlarmMetadata>(
      presentation: presentation,
      metadata: GraceAlarmMetadata(),
      tintColor: .white
    )
    // 이 예약이 어느 앱 알람의 것인지 정지 인텐트에 심는다(안드로이드의
    // 인텐트 extra 방식). 알람별 독립 등록은 intentAlarmId로 직접 지정하고,
    // id 없는 등록(추격·사다리)은 '진행 중 미션의 주인 알람' id를 싣는다.
    // ⚠️ scheduledMorningAlarmId 금지 — 재예약 때 '다음 알람'으로 덮여
    // 그 알람이 오완료된다(실측 2026-07-10 9:40 아멘이 9:50에 도장).
    let firedAlarmId = intentAlarmId
      ?? (kind == "morning"
        ? (Self.getMorningActiveAlarmId() ?? "")
        : "")
    let configuration = AlarmManager.AlarmConfiguration.alarm(
      schedule: schedule,
      attributes: attributes,
      stopIntent: OpenMissionFromAlarmIntent(
        source: source,
        kind: kind,
        alarmId: firedAlarmId,
        watchdogAlarmId: id.uuidString
      ),
      sound: .named(soundName)
    )
    // mobiletimerd의 취소 반영 지연이 길어지면 duplicate-ID로 연속 실패한다.
    // 마지막 시도만 throw — 호출부는 실패해도 배치를 중단하지 않는다.
    let retryDelays: [UInt64] = [0, 400_000_000, 900_000_000]
    var lastError: Error?
    for (attempt, delay) in retryDelays.enumerated() {
      if delay > 0 {
        try? AlarmManager.shared.stop(id: id)
        try? AlarmManager.shared.cancel(id: id)
        try? await Task.sleep(nanoseconds: delay)
      }
      do {
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
        return
      } catch {
        lastError = error
        NSLog("[ALARMKIT] schedule \(id) attempt \(attempt + 1) failed: \(error.localizedDescription)")
        // 주의: 한계 에러여도 재시도를 끊지 않는다 — '취소 후 재등록' 흐름
        // 에서는 앞선 취소가 데몬에 반영되는 순간 슬롯이 비어 다음 시도가
        // 성공한다(끊으면 '옛 등록 취소됨+새 등록 없음' 침묵 — 적대 검증).
        if isAlarmKitLimitError(error) {
          NSLog("[ALARMKIT-LIMIT] budget hit for \(id) — retrying after cancel settles")
        }
      }
    }
    if let lastError { throw lastError }
  }

  /// AlarmKit 동적 알람 수 한계(maximumLimitReached) 감지 — 정확한 케이스명
  /// 부분일치만 인정한다("limit" 단독은 무관한 에러 문구에 오탐해 배치를
  /// 헛되이 끊는다 — 적대 검증 지적). 오판 시 동작은 '중단 없음' = 종전과
  /// 동일이라 안전 방향. 순수-추가 배치(사다리/추격)에서만 조기 중단하고,
  /// '취소 후 재등록' 흐름에서는 쓰지 않는다(취소 반영 대기 중의 일시적
  /// 한계는 재시도가 정답이므로).
  private static func isAlarmKitLimitError(_ error: Error) -> Bool {
    return String(describing: error).lowercased().contains("maximumlimitreached")
  }

  /// 슬롯 하나의 실패가 나머지 슬롯·후속 예약을 죽이지 않도록 non-throwing.
  @available(iOS 26.0, *)
  private static func scheduleMorningRetryLadder(baseDate: Date, soundName: String, intentAlarmId: String? = nil) async {
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    purgeStaleRetrySlots(["A1000040"])

    let now = Date()
    var scheduled = 0
    var attempted = 0
    for i in 0..<retryCount {
      let offset = TimeInterval(retryIntervalSeconds * (i + 1))
      let fireDate = baseDate.addingTimeInterval(offset)
      if fireDate <= now { continue }
      attempted += 1
      do {
        try await scheduleOneMorningFixedAlarm(
          id: morningRetryIds[i],
          fireDate: fireDate,
          soundName: soundName,
          intentAlarmId: intentAlarmId
        )
        scheduled += 1
      } catch {
        NSLog("[ALARMKIT] morning retry slot \(i + 1) failed: \(error.localizedDescription)")
        if isAlarmKitLimitError(error) {
          NSLog("[ALARMKIT-LIMIT] ladder halted at slot \(i + 1) — budget exhausted")
          break
        }
      }
    }
    if scheduled < attempted {
      NSLog("[ALARMKIT] morning retry ladder partial: \(scheduled)/\(attempted)")
    }
  }

  @available(iOS 26.0, *)
  private static func scheduleEveningRetryLadder(baseDate: Date, soundName: String) async {
    purgeStaleRetrySlots(["A1000060"])
    for rid in eveningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }

    let now = Date()
    for i in 0..<eveningRetryCount {
      let offset = TimeInterval(eveningRetryIntervalSeconds * (i + 1))
      let fireDate = baseDate.addingTimeInterval(offset)
      if fireDate <= now { continue }
      do {
        try await scheduleOneEveningFixedAlarm(
          id: eveningRetryIds[i],
          fireDate: fireDate,
          soundName: soundName
        )
      } catch {
        NSLog("[ALARMKIT] evening retry slot \(i + 1) failed: \(error.localizedDescription)")
        if isAlarmKitLimitError(error) {
          NSLog("[ALARMKIT-LIMIT] evening ladder halted at slot \(i + 1) — budget exhausted")
          break
        }
      }
    }
  }

  @available(iOS 26.0, *)
  static func pauseMorningRetriesForMission() async throws {
    // 전원버튼 연타 마개: 이미 이번 미션에서 무장 해제를 끝냈다면(알람별
    // 맵이 비어 있음) 취소 폭풍을 반복하지 않는다 — press당 수십 건 취소가
    // 3~4번 만에 데몬 배달 억제를 만든 실측(2026-07-15, 포럼 825427의
    // churn-유발 저하와 동일 기전)의 마개. 방치 경로가 알람별 등록을
    // 되살리면 맵이 다시 차므로 그때는 전체 pause가 정상 실행된다.
    if isMorningMissionInProgress(),
       loadStringMap(morningPerAlarmUuidMapKey).isEmpty {
      setMorningInProgress(true)
      UserDefaults.standard.removeObject(forKey: morningBatchSignatureKey)
      // 소리 마개: 이미 무장 해제됐더라도 현재 울리고 있을 워치독/에코를
      // stop한다 — 미션 화면에서 소리가 잔류하는 것을 완전 차단.
      for wid in morningMissionWatchdogIds {
        try? AlarmManager.shared.stop(id: wid)
      }
      try? AlarmManager.shared.stop(id: morningStopEchoId)
      NSLog("[ALARMKIT] mission pause: already disarmed — skipping repeat cancel storm (sounds stopped)")
      return
    }
    setMorningInProgress(true)
    // 사다리를 지우므로 배치 서명 무효 — 이후 재예약이 생략되면 안 된다.
    UserDefaults.standard.removeObject(forKey: morningBatchSignatureKey)
    // 미션 중 다른 알람의 독립 등록이 울리면 안 된다 — 전부 취소하고 맵을
    // 비운다. 아멘 후 동기화가 전원 '새 UUID'로 재등록한다(레이스 불가).
    stopAllPerAlarmRegistrations(cancelToo: true)
    try? AlarmManager.shared.stop(id: morningId)
    cancelMorningMainFallback()
    try? AlarmManager.shared.stop(id: morningSnoozeId)
    try? AlarmManager.shared.cancel(id: morningSnoozeId)
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    purgeStaleRetrySlots(["A1000040"])
    // 현재 울리고 있을 추격 워치독과 에코의 소리를 즉시 정지한다.
    // 주의: cancel은 하지 않는다 — 추격 자체는 잠금 뒤에서도 계속 울려야
    // 하며, 여기서는 '미션 진입 시 겹치는 소리'만 끊는다.
    for wid in morningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: wid)
    }
    try? AlarmManager.shared.stop(id: morningMissionWatchdogId)
    try? AlarmManager.shared.stop(id: morningStopEchoId)
    NSLog("[ALARMKIT] mission active: normal retries paused, active sounds stopped; chase stays until user visibly engages")
  }

  /// 정지 메아리(Alare 기법, github.com/Cizzuk/Alare 출하 실증): 정지 실행
  /// 자체가 다음 울림 1발을 예약한다. perform() 뒤쪽이 시스템에 의해 도중
  /// 종료돼도 22초 뒤 메아리가 돌아오고, 그 발의 stop이 다시 전체 무장을
  /// 시도한다. 22초는 추격 1번 발과 같은 참여-취소 안전창(미션이 실제로
  /// 보이면 추격 취소 경로가 그 안에 메아리도 함께 정리). 실패해도 기존
  /// 사슬(추격·융단·백스톱)이 그대로 있으므로 non-throwing.
  @available(iOS 26.0, *)
  static func armStopEcho(kind: String) async {
    let id = kind == "evening" ? eveningStopEchoId : morningStopEchoId
    let generationKey = kind == "evening"
      ? eveningEchoGenerationKey : morningEchoGenerationKey
    let generation = UserDefaults.standard.integer(forKey: generationKey)
    try? AlarmManager.shared.stop(id: id)
    try? AlarmManager.shared.cancel(id: id)
    let fireDate = Date().addingTimeInterval(22)
    do {
      if kind == "evening" {
        let sound = validatedMorningAlarmKitSoundName(
          UserDefaults.standard.string(forKey: eveningAlarmKitSoundNameKey)
        )
        try await scheduleOneEveningFixedAlarm(
          id: id,
          fireDate: fireDate,
          soundName: sound
        )
      } else {
        try await scheduleOneMorningFixedAlarm(
          id: id,
          fireDate: fireDate,
          soundName: missionOwnerChaseSoundName()
        )
      }
      // 참여 취소가 예약이 뜨는 도중에 지나갔으면(세대 이동) 지금 걷는다 —
      // 방치 사다리와 같은 경주 마개. 없으면 취소를 비껴간 메아리가 미션
      // 중이나 아멘 후에 울린다(적대 검증이 잡은 구멍).
      if UserDefaults.standard.integer(forKey: generationKey) != generation {
        try? AlarmManager.shared.stop(id: id)
        try? AlarmManager.shared.cancel(id: id)
        NSLog("[ALARMKIT] stop echo swept post-landing (generation moved, \(kind))")
        return
      }
      NSLog("[ALARMKIT] stop echo armed +22s (\(kind))")
    } catch {
      NSLog("[ALARMKIT] stop echo failed (\(kind)): \(error.localizedDescription)")
    }
  }

  /// 메아리의 유일한 정리 경로 — '보이는 참여'(화면 활성/미션 표시)와
  /// 아멘·알람 OFF에서만 부른다. 사다리/워치독 재건축 청소에 편입 금지
  /// (거기 두면 메아리가 재무장 때마다 죽는다). 세대를 먼저 움직여 뜨는
  /// 도중인 메아리 예약도 착지 후 자진 철수하게 한다.
  @available(iOS 26.0, *)
  static func cancelStopEcho(kind: String) {
    let id = kind == "evening" ? eveningStopEchoId : morningStopEchoId
    let generationKey = kind == "evening"
      ? eveningEchoGenerationKey : morningEchoGenerationKey
    UserDefaults.standard.set(
      UserDefaults.standard.integer(forKey: generationKey) + 1,
      forKey: generationKey
    )
    try? AlarmManager.shared.stop(id: id)
    try? AlarmManager.shared.cancel(id: id)
  }

  /// 참여 판정의 교정된 의미(2026-07-15 15:37:07 로그 실측 후): '부대 전멸'이
  /// 아니라 '앞 N초만 조용히'. 창(지금~+N초) 안에 발화할 추격·메아리만 걷고
  /// 꼬리는 남긴다 — 미션 화면이 45초마다 창을 굴려 연장하고, 화면이 잠기면
  /// 연장이 끊겨 남은 부대가 저절로 복귀한다. 전멸+이탈-순간-재무장 설계는
  /// 전원버튼 오판(누르는 순간 Face ID 통과) 한 번에 부대가 사라진 뒤 재무장
  /// Task가 동면에 져서 영원 침묵이 됐다(실측: 3연타 후 큐 텅 빔).
  @available(iOS 26.0, *)
  static func suppressChaseWindow(kind: String, seconds: TimeInterval) async {
    let ids = kind == "evening" ? eveningMissionWatchdogIds : morningMissionWatchdogIds
    let legacyId = kind == "evening" ? eveningMissionWatchdogId : morningMissionWatchdogId
    let echoId = kind == "evening" ? eveningStopEchoId : morningStopEchoId
    let cutoff = Date().addingTimeInterval(seconds)
    guard let alarms = try? AlarmManager.shared.alarms else { return }
    
    let futureWatchdogs = alarms.filter { ids.contains($0.id) && (fixedFireDate($0) ?? Date.distantPast) > cutoff }
    let nearWatchdogs = alarms.filter { ids.contains($0.id) && (fixedFireDate($0) ?? Date.distantPast) <= cutoff }
    
    var suppressed = 0
    for a in nearWatchdogs {
      try? AlarmManager.shared.stop(id: a.id)
      try? AlarmManager.shared.cancel(id: a.id)
      suppressed += 1
    }
    try? AlarmManager.shared.stop(id: legacyId)
    try? AlarmManager.shared.cancel(id: legacyId)
    try? AlarmManager.shared.stop(id: echoId)
    try? AlarmManager.shared.cancel(id: echoId)
    
    NSLog("[ALARMKIT] chase quiet window +\(Int(seconds))s (\(kind)): \(suppressed) near slots suppressed, tail kept (\(futureWatchdogs.count) active)")
    
    let activeFutureCount = futureWatchdogs.count
    let needed = watchdogCount - activeFutureCount
    
    if needed > 0 {
      let interval = TimeInterval(missionAbandonIntervalSeconds) // 30s
      let soundName = kind == "morning"
        ? missionOwnerChaseSoundName()
        : validatedMorningAlarmKitSoundName(UserDefaults.standard.string(forKey: eveningAlarmKitSoundNameKey))
      let ownerId = kind == "morning" ? getMorningActiveAlarmId() : nil
      
      let maxFireDate = futureWatchdogs.compactMap { fixedFireDate($0) }.max()
      let startFireDate = maxFireDate ?? cutoff
      
      let scheduledIds = futureWatchdogs.map { $0.id }
      let availableIds = ids.filter { !scheduledIds.contains($0) }
      
      NSLog("[ALARMKIT] suppressChaseWindow: rebuilding \(needed) watchdogs after \(startFireDate) (\(kind))")
      for i in 0..<min(needed, availableIds.count) {
        let fireDate = startFireDate.addingTimeInterval(interval * TimeInterval(i + 1))
        let wid = availableIds[i]
        do {
          try await scheduleOneMissionAlarm(
            id: wid,
            schedule: .fixed(fireDate),
            titleText: kind == "morning" ? "God Morning" : "Evening blessing",
            kind: kind,
            source: kind == "morning" ? "alarmkit_stop" : "alarmkit_evening_retry_stop",
            soundName: soundName,
            intentAlarmId: ownerId
          )
        } catch {
          NSLog("[ALARMKIT] failed to reschedule suppressed watchdog \(wid): \(error.localizedDescription)")
        }
      }
    }
  }

  // MARK: - 워치독 잔존 검사 (IPC churn 방지)

  /// 향후 `seconds`초 이내(10초 이후~)에 아침 추격 워치독이 데몬에
  /// 살아있는지 검사한다. 살아있으면 stop intent가 전체 재등록을 생략해
  /// mobiletimerd IPC 부하를 완전 차단한다.
  @available(iOS 26.0, *)
  static func hasUpcomingMorningWatchdog(within seconds: TimeInterval) -> Bool {
    guard let alarms = try? AlarmManager.shared.alarms else { return false }
    let now = Date()
    let minTime = now.addingTimeInterval(10)
    let limit = now.addingTimeInterval(seconds)
    return alarms.contains {
      morningMissionWatchdogIds.contains($0.id)
        && (fixedFireDate($0) ?? Date.distantPast) >= minTime
        && (fixedFireDate($0) ?? Date.distantFuture) <= limit
    }
  }

  /// 향후 `seconds`초 이내에 저녁 추격 워치독이 데몬에 살아있는지 검사.
  @available(iOS 26.0, *)
  static func hasUpcomingEveningWatchdog(within seconds: TimeInterval) -> Bool {
    guard let alarms = try? AlarmManager.shared.alarms else { return false }
    let now = Date()
    let minTime = now.addingTimeInterval(10)
    let limit = now.addingTimeInterval(seconds)
    return alarms.contains {
      eveningMissionWatchdogIds.contains($0.id)
        && (fixedFireDate($0) ?? Date.distantPast) >= minTime
        && (fixedFireDate($0) ?? Date.distantFuture) <= limit
    }
  }

  /// stop 인텐트 직후의 추격 무장 — 전원 버튼이 stop을 실행해도 미션이
  /// 실제로 열리지 않으면 52초 뒤부터 다시 울린다(22초의 메아리와 겹치지
  /// 않게 30초 밀림). 미션이 열리면 미션-시작 pause와
  /// sceneDidBecomeActive가 이 사다리를 취소한다.
  @available(iOS 26.0, *)
  static func armMorningChaseAfterStop() async throws {
    // IPC churn 방지: 향후 45초 이내에 이미 예정된 워치독이 있으면
    // 재등록을 생략한다 — 사이드 버튼 연타 시 데몬 과부하를 100% 차단.
    if hasUpcomingMorningWatchdog(within: 45) {
      NSLog("[ALARMKIT] morning chase: upcoming watchdog exists within 45s — skip rearm")
      return
    }
    // firstDelayOverride = 52: 메아리(+22s)와 시간축 중첩 차단.
    try await rearmMorningNormalRetriesForMissionAbandon(
      reason: "stop_intent",
      firstDelayOverride: missionAbandonFirstRetryDelaySeconds + missionAbandonIntervalSeconds
    )
  }

  @available(iOS 26.0, *)
  static func armEveningChaseAfterStop() async throws {
    // IPC churn 방지: 향후 45초 이내에 이미 예정된 워치독이 있으면 생략.
    if hasUpcomingEveningWatchdog(within: 45) {
      NSLog("[ALARMKIT] evening chase: upcoming watchdog exists within 45s — skip rearm")
      return
    }
    // firstDelaySeconds = 52: 메아리(+22s)와 시간축 중첩 차단.
    await rearmEveningChaseIfEmpty(
      reason: "stop_intent",
      firstDelaySeconds: missionAbandonFirstRetryDelaySeconds + missionAbandonIntervalSeconds
    )
  }

  /// 저녁 추격(20발×30초) — 아침과 동일한 불가침 원칙: 슬롯이 하나라도
  /// 남아 있으면 절대 재건축하지 않는다.
  @available(iOS 26.0, *)
  static func rearmEveningChaseIfEmpty(
    reason: String,
    firstDelaySeconds: Int = missionAbandonFirstRetryDelaySeconds
  ) async {
    guard getEveningCompletedDate() != todayKey() else { return }
    do {
      try await scheduleMissionAbandonLadder(
        kind: "evening",
        firstDelayOverride: firstDelaySeconds
      )
    } catch {
      NSLog("[ALARMKIT] failed to rearm evening chase: \(error.localizedDescription)")
    }
  }

  @available(iOS 26.0, *)
  static func cancelEveningChase() {
    // 주의: 메아리는 여기서 걷지 않는다 — 이 함수는 워치독 재예약의
    // 청소 단계로도 불려서, 여기 두면 메아리가 재무장 때마다 죽는다.
    // 메아리 정리는 cancelStopEcho(참여/아멘/OFF 전용)가 담당.
    try? AlarmManager.shared.stop(id: eveningMissionWatchdogId)
    try? AlarmManager.shared.cancel(id: eveningMissionWatchdogId)
    for id in eveningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: id)
      try? AlarmManager.shared.cancel(id: id)
    }
  }

  @available(iOS 26.0, *)
  static func pauseEveningRetriesForMission() async throws {
    // 전원버튼 연타 마개(아침과 대칭): 이미 무장 해제됐고 메인 등록도
    // 데몬에 없으면 취소 반복을 생략한다. 메인이 되살아난 경우(미션 중
    // 앱 열기의 저녁 재예약)에는 전체 pause가 정상 실행된다.
    if isEveningMissionInProgress(),
       let existing = try? AlarmManager.shared.alarms,
       !existing.contains(where: { $0.id == eveningId }) {
      setEveningInProgress(true)
      setEveningStartedDate(todayKey())
      UserDefaults.standard.removeObject(forKey: eveningBatchSignatureKey)
      // 소리 마개: 이미 무장 해제됐더라도 현재 울리고 있을 워치독/에코를 stop.
      for wid in eveningMissionWatchdogIds {
        try? AlarmManager.shared.stop(id: wid)
      }
      try? AlarmManager.shared.stop(id: eveningStopEchoId)
      NSLog("[ALARMKIT] evening pause: already disarmed — skipping repeat cancels (sounds stopped)")
      return
    }
    setEveningInProgress(true)
    setEveningStartedDate(todayKey())
    UserDefaults.standard.removeObject(forKey: eveningBatchSignatureKey)
    try? AlarmManager.shared.stop(id: eveningId)
    try? AlarmManager.shared.stop(id: eveningSnoozeId)
    try? AlarmManager.shared.cancel(id: eveningSnoozeId)
    for rid in eveningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    // 현재 울리고 있을 추격 워치독과 에코의 소리를 즉시 정지한다.
    // cancel은 하지 않는다 — 소리만 끊고 추격 사다리는 잠금 뒤를 위해 보존.
    for wid in eveningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: wid)
    }
    try? AlarmManager.shared.stop(id: eveningMissionWatchdogId)
    try? AlarmManager.shared.stop(id: eveningStopEchoId)
    NSLog("[ALARMKIT] evening mission active: retries paused, active sounds stopped")
  }

  static func armMorningMissionExitWatchdogIfNeeded(reason: String) {
    guard #available(iOS 26.0, *) else { return }
    guard isMorningMissionInProgress() else { return }

    Task {
      do {
        try await rearmMorningNormalRetriesForMissionAbandon(reason: reason)
      } catch {
        NSLog("[ALARMKIT] morning abandon normal retry failed: \(error.localizedDescription)")
      }
    }
  }

  static func armMissionExitWatchdogsIfNeeded(reason: String) {
    guard #available(iOS 26.0, *) else { return }

    if isMorningMissionInProgress() {
      Self.runWithBackgroundTask(name: "armMorningExitWatchdogs") {
        do {
          try await rearmMorningNormalRetriesForMissionAbandon(reason: reason)
        } catch {
          NSLog("[ALARMKIT] morning abandon normal retry failed: \(error.localizedDescription)")
        }
      }
    }

    if isEveningMissionInProgress() {
      Self.runWithBackgroundTask(name: "armEveningExitWatchdogs") {
        await rearmEveningChaseIfEmpty(reason: reason)
      }
    }
  }

  @available(iOS 26.0, *)
  static func cancelForegroundMissionExitWatchdogs(reason: String) async {
    if isMorningMissionInProgress() {
      await suppressChaseWindow(kind: "morning", seconds: 120)
      // 방치 경로가 되살린 알람별 등록은 미션 복귀 시 다시 잠재운다.
      stopAllPerAlarmRegistrations(cancelToo: true)
      NSLog("[ALARMKIT] foreground mission active — chase quiet window opened: \(reason)")
    }
    // 저녁도 대칭: 화면이 실제로 활성일 때만 조용 창을 연다.
    if isEveningMissionInProgress() {
      await suppressChaseWindow(kind: "evening", seconds: 120)
    }
  }

  @available(iOS 26.0, *)
  static func stopAllActiveRingingSounds() {
    guard let alarms = try? AlarmManager.shared.alarms else { return }
    for a in alarms {
      try? AlarmManager.shared.stop(id: a.id)
    }
    try? AlarmManager.shared.stop(id: morningId)
    try? AlarmManager.shared.stop(id: eveningId)
    try? AlarmManager.shared.stop(id: morningSnoozeId)
    try? AlarmManager.shared.stop(id: eveningSnoozeId)
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
    }
    for rid in eveningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
    }
    for wid in morningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: wid)
    }
    for wid in eveningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: wid)
    }
    try? AlarmManager.shared.stop(id: morningStopEchoId)
    try? AlarmManager.shared.stop(id: eveningStopEchoId)
    NSLog("[ALARMKIT] stopAllActiveRingingSounds: stopped all native alarm sounds immediately")
  }

  @available(iOS 26.0, *)
  private static func scheduleMorningMissionWatchdog(after seconds: TimeInterval) async throws {
    if getMorningCompletedDate() == todayKey() {
      return
    }
    cancelMorningMissionExitLadder()
    let baseDate = Date().addingTimeInterval(seconds)
    let soundName = missionOwnerChaseSoundName()
    var scheduledCount = 0
    var lastError: Error?
    for i in 0..<retryCount {
      let fireDate = baseDate.addingTimeInterval(
        TimeInterval(retryIntervalSeconds * i)
      )
      do {
        try await scheduleOneMorningFixedAlarm(
          id: morningMissionWatchdogIds[i],
          fireDate: fireDate,
          soundName: soundName
        )
        scheduledCount += 1
      } catch {
        lastError = error
        NSLog("[ALARMKIT] morning mission exit slot \(i + 1) failed: \(error.localizedDescription)")
      }
    }
    if scheduledCount == 0, let lastError {
      throw lastError
    }
    NSLog("[ALARMKIT] morning mission exit ladder scheduled: \(scheduledCount)/\(retryCount)x every \(retryIntervalSeconds)s from \(baseDate)")
  }

  @available(iOS 26.0, *)
  @MainActor
  private static func rearmMorningNormalRetriesForMissionAbandon(
    reason: String,
    firstDelayOverride: Int? = nil
  ) async throws {
    guard isMorningMissionInProgress() else { return }

    if morningMissionExitRearmInFlight {
      UserDefaults.standard.set(reason, forKey: morningRearmReasonKey)
      NSLog("[ALARMKIT] morning abandon rearm already in flight: \(reason)")
      return
    }
    morningMissionExitRearmInFlight = true
    defer { morningMissionExitRearmInFlight = false }

    try await scheduleMissionAbandonLadder(
      kind: "morning",
      firstDelayOverride: firstDelayOverride
    )
    // 방치 상태에서도 내일 이후의 알람별 등록은 살아 있어야 한다.
    await reRegisterPerAlarmsAfterAbandon()
  }

  @available(iOS 26.0, *)
  private static func scheduleMissionAbandonLadder(
    kind: String,
    firstDelayOverride: Int? = nil
  ) async throws {
    guard kind == "morning" ? isMorningMissionInProgress() : isEveningMissionInProgress() else {
      return
    }

    let watchdogIds = kind == "morning" ? morningMissionWatchdogIds : eveningMissionWatchdogIds
    let interval = TimeInterval(missionAbandonIntervalSeconds) // 30s
    let firstDelay = TimeInterval(firstDelayOverride ?? missionAbandonFirstRetryDelaySeconds) // 22s
    let count = watchdogCount // 6

    let soundName = kind == "morning"
      ? missionOwnerChaseSoundName()
      : validatedMorningAlarmKitSoundName(UserDefaults.standard.string(forKey: eveningAlarmKitSoundNameKey))
    let ownerId = kind == "morning" ? getMorningActiveAlarmId() : nil
    let startTime = Date()

    NSLog("[ALARMKIT] scheduling initial watchdog ladder for \(kind)...")
    var scheduledCount = 0
    for i in 0..<count {
      let fireDate = startTime.addingTimeInterval(firstDelay + interval * TimeInterval(i))
      do {
        try await scheduleOneMissionAlarm(
          id: watchdogIds[i],
          schedule: .fixed(fireDate),
          titleText: kind == "morning" ? "God Morning" : "Evening blessing",
          kind: kind,
          source: kind == "morning" ? "alarmkit_stop" : "alarmkit_evening_retry_stop",
          soundName: soundName,
          intentAlarmId: ownerId
        )
        scheduledCount += 1
      } catch {
        NSLog("[ALARMKIT] failed to schedule watchdog \(i + 1): \(error.localizedDescription)")
      }
    }
    NSLog("[ALARMKIT] scheduled \(scheduledCount)/\(count) watchdogs for \(kind)")
  }

  @available(iOS 26.0, *)
  static func handleAlarmStopped(kind: String, alarmId: String, watchdogAlarmId: String) async {
    guard kind == "morning" ? isMorningMissionInProgress() : isEveningMissionInProgress() else {
      NSLog("[ALARMKIT] handleAlarmStopped: mission is not in progress. Skip reschedule.")
      return
    }

    let watchdogIds = kind == "morning" ? morningMissionWatchdogIds : eveningMissionWatchdogIds
    let interval = TimeInterval(missionAbandonIntervalSeconds) // 30s
    let firstDelay = TimeInterval(missionAbandonFirstRetryDelaySeconds) // 22s
    let count = watchdogCount

    if let watchdogUuid = UUID(uuidString: watchdogAlarmId),
       let index = watchdogIds.firstIndex(of: watchdogUuid) {
      let alarms = (try? AlarmManager.shared.alarms) ?? []
      let otherWatchdogAlarms = alarms.filter { watchdogIds.contains($0.id) && $0.id != watchdogUuid }
      
      let otherFireDates = otherWatchdogAlarms.compactMap { fixedFireDate($0) }.filter { $0 > Date() }
      let nextFireDate: Date
      if let maxDate = otherFireDates.max() {
        nextFireDate = maxDate.addingTimeInterval(interval)
      } else {
        nextFireDate = Date().addingTimeInterval(firstDelay)
      }

      do {
        let soundName = kind == "morning"
          ? missionOwnerChaseSoundName()
          : validatedMorningAlarmKitSoundName(UserDefaults.standard.string(forKey: eveningAlarmKitSoundNameKey))
        let ownerId = kind == "morning" ? getMorningActiveAlarmId() : nil
        
        try await scheduleOneMissionAlarm(
          id: watchdogUuid,
          schedule: .fixed(nextFireDate),
          titleText: kind == "morning" ? "God Morning" : "Evening blessing",
          kind: kind,
          source: kind == "morning" ? "alarmkit_stop" : "alarmkit_evening_retry_stop",
          soundName: soundName,
          intentAlarmId: ownerId
        )
        NSLog("[ALARMKIT] rotated watchdog \(index + 1) to \(nextFireDate) (\(kind))")
      } catch {
        NSLog("[ALARMKIT] failed to rotate watchdog \(index + 1): \(error.localizedDescription)")
      }
    } else {
      // It is not a watchdog alarm (e.g. main alarm). This is the initial stop or a recovery attempt!
      if kind == "morning" {
        setMorningInProgress(true)
        setMorningStartedDate(todayKey())
      } else {
        setEveningInProgress(true)
        setEveningStartedDate(todayKey())
      }
      do {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        let activeWatchdogs = alarms.filter { watchdogIds.contains($0.id) }
        let futureWatchdogs = activeWatchdogs.filter { (fixedFireDate($0) ?? Date.distantPast) > Date() }
        
        if futureWatchdogs.count < count {
          let soundName = kind == "morning"
            ? missionOwnerChaseSoundName()
            : validatedMorningAlarmKitSoundName(UserDefaults.standard.string(forKey: eveningAlarmKitSoundNameKey))
          let ownerId = kind == "morning" ? getMorningActiveAlarmId() : nil
          let startTime = Date()
          
          NSLog("[ALARMKIT] rebuilding watchdog ladder for \(kind)...")
          var scheduledCount = 0
          for i in 0..<count {
            let wid = watchdogIds[i]
            if futureWatchdogs.contains(where: { $0.id == wid }) {
              continue
            }
            let fireDate = startTime.addingTimeInterval(firstDelay + interval * TimeInterval(scheduledCount))
            do {
              try await scheduleOneMissionAlarm(
                id: wid,
                schedule: .fixed(fireDate),
                titleText: kind == "morning" ? "God Morning" : "Evening blessing",
                kind: kind,
                source: kind == "morning" ? "alarmkit_stop" : "alarmkit_evening_retry_stop",
                soundName: soundName,
                intentAlarmId: ownerId
              )
              scheduledCount += 1
            } catch {
              NSLog("[ALARMKIT] failed to schedule watchdog \(i + 1): \(error.localizedDescription)")
            }
          }
          NSLog("[ALARMKIT] rebuilt watchdog ladder (\(scheduledCount) new, \(futureWatchdogs.count) existing) for \(kind)")
        } else {
          NSLog("[ALARMKIT] watchdog ladder already complete (\(futureWatchdogs.count) slots). Skip rebuild.")
        }
      } catch {
        NSLog("[ALARMKIT] failed during watchdog handle/rebuild: \(error.localizedDescription)")
      }
    }
  }

  @available(iOS 26.0, *)
  private static func scheduleEveningMissionWatchdog(after seconds: TimeInterval) async throws {
    try await scheduleMissionAbandonLadder(kind: "evening", firstDelayOverride: Int(seconds))
  }

  private static func retryBaseDate(
    hour: Int,
    minute: Int,
    preserveActiveWindow: Bool,
    completedDateKey: String,
    dartWeekdays: [Int]
  ) -> Date {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let todayBase = calendar.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: today
    ) ?? now

    let completedToday: Bool
    if completedDateKey == morningMissionCompletedDateKey {
      completedToday = getMorningCompletedDate() == todayKey()
    } else if completedDateKey == eveningMissionCompletedDateKey {
      completedToday = getEveningCompletedDate() == todayKey()
    } else {
      completedToday = UserDefaults.standard.string(forKey: completedDateKey) == todayKey()
    }
    let lastRetry = todayBase.addingTimeInterval(TimeInterval(retryIntervalSeconds * retryCount))
    let selectedCalendarWeekdays = Set(
      normalizedDartWeekdays(dartWeekdays).map(calendarWeekday)
    )

    for offset in 0..<14 {
      guard let candidate = calendar.date(byAdding: .day, value: offset, to: todayBase)
      else { continue }
      let candidateWeekday = calendar.component(.weekday, from: candidate)
      guard selectedCalendarWeekdays.contains(candidateWeekday) else {
        continue
      }
      if offset == 0 {
        if !completedToday {
          if candidate > now {
            return candidate
          }
          if preserveActiveWindow && now <= lastRetry {
            return candidate
          }
        }
        continue
      }
      return candidate
    }

    return calendar.date(byAdding: .day, value: 1, to: todayBase)
      ?? todayBase.addingTimeInterval(24 * 60 * 60)
  }

  /// 새로 예약된 아침 알람 id 저장. 그 알람이 오늘 완료된 알람이 아니면
  /// 전역 완료 스탬프를 지워 같은 날 두 번째 알람도 울릴 수 있게 한다
  /// (완료된 알람의 AlarmKit 알람은 이미 취소되어 있어 안전).
  /// 놓친 울림 승격: 저장된 다음-울림 시각이 "오늘"이고 이미 지났는데 그 알람이
  /// 완료되지 않았다면, 재예약으로 스탬프가 미래로 굴러가기 전에 pendingMission으로
  /// 승격한다 — 울림을 끝까지 무시한 채 앱을 열어도 미션이 반드시 뜨는 안전망.
  static func promoteMissedMorningFireIfNeeded() {
    let defaults = UserDefaults.standard
    let epochMillis = defaults.double(forKey: morningNextFireEpochKey)
    guard epochMillis > 0 else { return }
    let fireDate = Date(timeIntervalSince1970: epochMillis / 1000.0)
    guard fireDate <= Date(), Calendar.current.isDateInToday(fireDate) else { return }
    // 완료 판정은 '그 스탬프의 알람' 기준(알람별 도장). 전역 도장은 같은 날
    // 다른 알람의 아멘으로도 찍히므로(멀티 알람) 여기서 보면 놓친 발화
    // 승격이 막힌다 — 실측 2026-07-10: 10:00 발화가 울리다 끊겼는데
    // 9:40의 다른 아멘 도장 때문에 승격 거부, 알람이 조용히 내일로 밀림.
    let stampAlarmId = defaults.string(forKey: scheduledMorningAlarmIdKey) ?? ""
    if !stampAlarmId.isEmpty {
      if defaults.string(forKey: morningCompletedPerAlarmPrefix + stampAlarmId)
        == todayKey() {
        return
      }
    } else if getMorningCompletedDate() == todayKey() {
      return
    }
    defaults.set(true, forKey: "pendingMission")
    defaults.set("morning", forKey: "pendingMissionKind")
    defaults.set("missed_fire_promotion", forKey: "pendingMissionSource")
    if !stampAlarmId.isEmpty {
      defaults.set(stampAlarmId, forKey: "pendingMissionAlarmId")
      // 승격된 미션의 주인 — 이후 추격 재무장이 이 id를 싣는다.
      setMorningActiveAlarmId(stampAlarmId)
    }
    NSLog("[ALARMKIT] missed morning fire promoted to pending mission")
    // 게이트는 이미 지나갔을 수 있다 — 인텐트와 같은 Darwin 알림으로
    // 앱에 즉시 알려 미션이 바로 뜨게 한다(다음 실행까지 잠들지 않게).
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName("com.bagseonghwa.meansofgrace.pendingMission" as CFString),
      nil,
      nil,
      true
    )
  }

  static func storeMorningNextFireEpoch(_ date: Date) {
    UserDefaults.standard.set(
      date.timeIntervalSince1970 * 1000.0,
      forKey: morningNextFireEpochKey
    )
  }

  static func clearMorningNextFireEpoch() {
    UserDefaults.standard.removeObject(forKey: morningNextFireEpochKey)
  }

  static func storeScheduledMorningAlarmId(
    _ alarmId: String?,
    nextFireIsToday: Bool? = nil
  ) {
    let defaults = UserDefaults.standard
    if let alarmId, !alarmId.isEmpty {
      defaults.set(alarmId, forKey: scheduledMorningAlarmIdKey)
      let notCompleted =
        defaults.string(forKey: morningCompletedPerAlarmPrefix + alarmId) != todayKey()
      // 내일 발화 예약이 오늘의 완료 스탬프를 지우면, 재시도 창 안의 저장/삭제가
      // 오늘 기준 유령 사다리를 부활시킨다(삭제한 알람이 7:03에 울리던 원인).
      // '다음 발화가 오늘'일 때만 지운다(정보 없으면 기존 동작 유지).
      if notCompleted && (nextFireIsToday ?? true) {
        setMorningCompletedDate(nil)
        NSLog("[ALARMKIT-DIAG] storeScheduledId=\(alarmId) cleared global completed stamp")
      } else {
        NSLog("[ALARMKIT-DIAG] storeScheduledId=\(alarmId) stamp kept (completed=\(!notCompleted) today=\(String(describing: nextFireIsToday)))")
      }
    } else {
      NSLog("[ALARMKIT-DIAG] storeScheduledId=NIL — stamp untouched (completedToday may stay set!)")
    }
  }

  private static func todayKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }

  @available(iOS 26.0, *)
  static func isEveningMissionInProgress() -> Bool {
    getEveningInProgress()
      && getEveningStartedDate() == todayKey()
      && getEveningCompletedDate() != todayKey()
  }

  private static func isMorningMissionInProgress() -> Bool {
    // 날짜 스코프 필수: 플래그만 보면 미션 중 프로세스 사망 후 플래그가
    // 자정을 넘겨 살아남아 동기화가 무기한 스킵된다(알람 전체 침묵 +
    // 시간 편집이 데몬에 영영 미적용). '오늘 시작한 미션'만 진행 중.
    getMorningInProgress()
      && getMorningStartedDate() == todayKey()
      && getMorningCompletedDate() != todayKey()
  }

  @available(iOS 26.0, *)
  private static func ensureMorningMissionExitLadder() async throws {
    let alarms = (try? AlarmManager.shared.alarms) ?? []
    let activeMissionExitCount = alarms.filter {
      morningMissionWatchdogIds.contains($0.id)
    }.count
    if activeMissionExitCount >= watchdogCount {
      return
    }
    try await scheduleMissionAbandonLadder(kind: "morning")
  }

  @available(iOS 26.0, *)
  private static func morningAlarmKitDiagnostics() -> [String: Any] {
    let defaults = UserDefaults.standard
    let completedToday = getMorningCompletedDate() == todayKey()
    let inProgress = getMorningInProgress()
    let pendingMission = defaults.bool(forKey: "pendingMission")
    let nativePending = defaults.bool(forKey: morningPendingKey)
    let now = Date()

    do {
      let alarms = try AlarmManager.shared.alarms
      let alarmsById = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0) })
      let normalRetries = morningRetryIds.compactMap { alarmsById[$0] }
      let missionExitRetries = morningMissionWatchdogIds.compactMap { alarmsById[$0] }
      let mainAlarm = alarmsById[morningId]
      let legacyMissionAlarm = alarmsById[morningMissionWatchdogId]
      let firstNormalRetry = firstAlarm(in: morningRetryIds, alarmsById: alarmsById)
      let firstMissionExitRetry = firstAlarm(in: morningMissionWatchdogIds, alarmsById: alarmsById)
      let firstNormalDate = firstNormalRetry.flatMap(fixedFireDate)
      let firstMissionExitDate = firstMissionExitRetry.flatMap(fixedFireDate)
      let todayRetryCounts = retryCountsForToday(
        normalRetries: normalRetries,
        missionExitRetries: missionExitRetries
      )
      let morningIds = Set(
        [morningId, morningSnoozeId, morningMissionWatchdogId]
          + morningRetryIds
          + morningMissionWatchdogIds
      )
      let morningOwnedCount = alarms.filter { morningIds.contains($0.id) }.count
      let amenClearedTodayRetries = completedToday
        && todayRetryCounts.normal == 0
        && todayRetryCounts.missionExit == 0
        && legacyMissionAlarm == nil
      let missionExitNeededButMissing = inProgress
        && !completedToday
        && missionExitRetries.isEmpty

      return [
        "available": true,
        "authorizationState": authorizationStateDescription(AlarmManager.shared.authorizationState),
        "completedToday": completedToday,
        "inProgress": inProgress,
        "pendingMission": pendingMission,
        "nativePending": nativePending,
        "pendingMissionKind": defaults.string(forKey: "pendingMissionKind") ?? "",
        "pendingMissionSource": defaults.string(forKey: "pendingMissionSource") ?? "",
        "retryIntervalSeconds": retryIntervalSeconds,
        "retryCount": retryCount,
        "missionAbandonRetryCount": missionAbandonRetryCount,
        "alarmsTotal": alarms.count,
        "morningOwnedCount": morningOwnedCount,
        "mainAlarmExists": mainAlarm != nil,
        "mainAlarmState": mainAlarm.map { alarmStateDescription($0.state) } ?? "missing",
        "mainAlarmSchedule": mainAlarm.map(alarmScheduleDescription) ?? "missing",
        "normalRetryCount": normalRetries.count,
        "missionExitRetryCount": missionExitRetries.count,
        "missionExitNeededButMissing": missionExitNeededButMissing,
        "legacyMissionWatchdogExists": legacyMissionAlarm != nil,
        "normalRetryTodayCount": todayRetryCounts.normal,
        "missionExitRetryTodayCount": todayRetryCounts.missionExit,
        "firstNormalRetryFireDate": firstNormalDate.map(isoDateString) ?? "",
        "firstNormalRetrySecondsFromNow": firstNormalDate.map { $0.timeIntervalSince(now) } ?? -1,
        "firstNormalRetrySchedule": firstNormalRetry.map(alarmScheduleDescription) ?? "missing",
        "firstMissionExitRetryFireDate": firstMissionExitDate.map(isoDateString) ?? "",
        "firstMissionExitRetrySecondsFromNow": firstMissionExitDate.map { $0.timeIntervalSince(now) } ?? -1,
        "firstMissionExitRetrySchedule": firstMissionExitRetry.map(alarmScheduleDescription) ?? "missing",
        "amenClearedTodayRetries": amenClearedTodayRetries,
        "rearmReason": defaults.string(forKey: morningRearmReasonKey) ?? "",
        "rearmStartedAt": (defaults.object(forKey: morningRearmStartedAtKey) as? Date).map(isoDateString) ?? "",
        "rearmFinishedAt": (defaults.object(forKey: morningRearmFinishedAtKey) as? Date).map(isoDateString) ?? "",
        "rearmFirstScheduled": defaults.integer(forKey: morningRearmFirstScheduledKey),
        "rearmFirstFireDate": (defaults.object(forKey: morningRearmFirstFireDateKey) as? Date).map(isoDateString) ?? "",
        "rearmFirstError": defaults.string(forKey: morningRearmFirstErrorKey) ?? "",
        "rearmTrailingScheduled": defaults.integer(forKey: morningRearmTrailingScheduledKey),
        "rearmImmediateCount": defaults.integer(forKey: morningRearmImmediateCountKey),
        "rearmImmediateFirstFire": (defaults.object(forKey: morningRearmImmediateFirstFireKey) as? Date).map(isoDateString) ?? "",
      ]
    } catch {
      return [
        "available": true,
        "authorizationState": authorizationStateDescription(AlarmManager.shared.authorizationState),
        "completedToday": completedToday,
        "inProgress": inProgress,
        "pendingMission": pendingMission,
        "nativePending": nativePending,
        "retryIntervalSeconds": retryIntervalSeconds,
        "retryCount": retryCount,
        "missionAbandonRetryCount": missionAbandonRetryCount,
        "error": error.localizedDescription,
      ]
    }
  }

  @available(iOS 26.0, *)
  private static func firstAlarm(
    in ids: [UUID],
    alarmsById: [UUID: Alarm]
  ) -> Alarm? {
    for id in ids {
      if let alarm = alarmsById[id] {
        return alarm
      }
    }
    return nil
  }

  @available(iOS 26.0, *)
  private static func fixedFireDate(_ alarm: Alarm) -> Date? {
    guard let schedule = alarm.schedule else { return nil }
    if case .fixed(let date) = schedule {
      return date
    }
    return nil
  }

  @available(iOS 26.0, *)
  private static func retryCountsForToday(
    normalRetries: [Alarm],
    missionExitRetries: [Alarm]
  ) -> (normal: Int, missionExit: Int) {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let startOfTomorrow = calendar.date(
      byAdding: .day,
      value: 1,
      to: startOfToday
    ) ?? startOfToday.addingTimeInterval(24 * 60 * 60)

    func isToday(_ alarm: Alarm) -> Bool {
      guard let date = fixedFireDate(alarm) else { return false }
      return date >= startOfToday && date < startOfTomorrow
    }

    return (
      normal: normalRetries.filter(isToday).count,
      missionExit: missionExitRetries.filter(isToday).count
    )
  }

  @available(iOS 26.0, *)
  private static func alarmScheduleDescription(_ alarm: Alarm) -> String {
    guard let schedule = alarm.schedule else {
      return "none"
    }
    switch schedule {
    case .fixed(let date):
      return "fixed \(isoDateString(date))"
    case .relative(let relative):
      return String(
        format: "relative %02d:%02d %@",
        relative.time.hour,
        relative.time.minute,
        recurrenceDescription(relative.repeats)
      )
    @unknown default:
      return "unknown"
    }
  }

  @available(iOS 26.0, *)
  private static func recurrenceDescription(
    _ recurrence: Alarm.Schedule.Relative.Recurrence
  ) -> String {
    switch recurrence {
    case .weekly(let weekdays):
      return "weekly(\(weekdays.map { String(describing: $0) }.joined(separator: ",")))"
    case .never:
      return "never"
    @unknown default:
      return "unknown"
    }
  }

  @available(iOS 26.0, *)
  private static func alarmStateDescription(_ state: Alarm.State) -> String {
    switch state {
    case .scheduled:
      return "scheduled"
    case .countdown:
      return "countdown"
    case .paused:
      return "paused"
    case .alerting:
      return "alerting"
    @unknown default:
      return "unknown"
    }
  }

  @available(iOS 26.0, *)
  private static func authorizationStateDescription(
    _ state: AlarmManager.AuthorizationState
  ) -> String {
    switch state {
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "unknown"
    }
  }

  private static func isoDateString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func normalizedDartWeekdays(_ raw: Any?) -> [Int] {
    if let values = raw as? [Int] {
      return normalizedDartWeekdays(values)
    }
    if let values = raw as? [NSNumber] {
      return normalizedDartWeekdays(values.map { $0.intValue })
    }
    return defaultDartWeekdays
  }

  private static func normalizedDartWeekdays(_ weekdays: [Int]) -> [Int] {
    let values = Set(weekdays.filter { $0 >= 1 && $0 <= 7 })
    if values.isEmpty {
      return defaultDartWeekdays
    }
    return values.sorted()
  }

  private static func calendarWeekday(_ dartWeekday: Int) -> Int {
    dartWeekday == 7 ? 1 : dartWeekday + 1
  }

  @available(iOS 26.0, *)
  private static func localeWeekdays(from dartWeekdays: [Int]) -> [Locale.Weekday] {
    normalizedDartWeekdays(dartWeekdays).map { weekday in
      switch weekday {
      case 1:
        return .monday
      case 2:
        return .tuesday
      case 3:
        return .wednesday
      case 4:
        return .thursday
      case 5:
        return .friday
      case 6:
        return .saturday
      default:
        return .sunday
      }
    }
  }

  private static func validatedMorningAlarmKitSoundName(_ raw: String?) -> String {
    guard let raw, allowedMorningAlarmKitSoundNames.contains(raw) else {
      return defaultMorningAlarmKitSoundName
    }
    return raw
  }

  private static func storeMorningAlarmKitSoundName(_ soundName: String) {
    UserDefaults.standard.set(
      validatedMorningAlarmKitSoundName(soundName),
      forKey: morningAlarmKitSoundNameKey
    )
  }

  private static func storedMorningAlarmKitSoundName() -> String {
    validatedMorningAlarmKitSoundName(
      UserDefaults.standard.string(forKey: morningAlarmKitSoundNameKey)
    )
  }

  /// 방치 추격의 소리는 '미션 주인 알람'의 알람별 소리 — 저장된 소리
  /// (morningAlarmKitSoundNameKey)는 동기화 때 '다음 알람'의 소리로
  /// 덮이므로(실측 2026-07-10 저녁: 첫 알람 방치 추격이 두 번째 알람
  /// 소리로 울림) 주인 스펙에서 직접 찾는다. 없으면 저장 소리 폴백.
  private static func missionOwnerChaseSoundName() -> String {
    let owner =
      getMorningActiveAlarmId() ?? ""
    if !owner.isEmpty,
       let raw = UserDefaults.standard.array(forKey: morningSpecsKey)
         as? [[String: Any]],
       let spec = raw.first(where: { ($0["id"] as? String) == owner }),
       let sound = spec["sound"] as? String,
       !sound.isEmpty {
      return validatedMorningAlarmKitSoundName(sound)
    }
    return storedMorningAlarmKitSoundName()
  }

  @available(iOS 26.0, *)
  private static func cancelMorningMissionExitLadder() {
    let defaults = UserDefaults.standard
    defaults.set(
      defaults.integer(forKey: morningMissionExitGenerationKey) + 1,
      forKey: morningMissionExitGenerationKey
    )
    // Cancel the legacy single-watchdog id too, so devices upgraded from an
    // older TestFlight build do not keep one stale alarm alive.
    try? AlarmManager.shared.stop(id: morningMissionWatchdogId)
    try? AlarmManager.shared.cancel(id: morningMissionWatchdogId)
    for id in morningMissionWatchdogIds {
      try? AlarmManager.shared.stop(id: id)
      try? AlarmManager.shared.cancel(id: id)
    }
    // 주의: 메아리는 여기서 걷지 않는다 — 이 함수는 사다리 재건축의 청소
    // 단계(scheduleMorningMissionAbandonLadder/Watchdog 초입)로도 불려서,
    // 여기 두면 '지은 지 1초 만에 메아리 사망'이 된다(적대 검증 확정).
    // 메아리 정리는 cancelStopEcho(참여/아멘/OFF 전용)가 담당.
    purgeStaleRetrySlots(["A1000050"])
  }

  /// Amen post-completion: re-arm the main weekly morning alarm and rebuild the
  /// fixed retry ladder for the next occurrence only. Today's retry alarms stay
  /// cancelled because missionCompletedDate is stamped before this is called.
  @available(iOS 26.0, *)
  private static func scheduleNextMorningAfterCompletion(
    hour: Int,
    minute: Int,
    soundName: String,
    dartWeekdays: [Int],
    fireImmediately: Bool = false,
    nextFireDate: Date? = nil,
    nextAlarmId: String? = nil
  ) async throws {
    storeMorningAlarmKitSoundName(soundName)
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    purgeStaleRetrySlots(["A1000040", "A1000050"])
    cancelMorningMissionExitLadder()
    cancelMorningMainFallback()
    UserDefaults.standard.removeObject(forKey: morningBatchSignatureKey)
    // epoch·메인·폴백·사다리 어느 하나의 실패가 나머지를 중단시키지 않는다
    // (duplicate-ID 레이스로 다음 알람이 통째로 사라지던 경로 차단).
    let base: Date
    if fireImmediately {
      base = Date().addingTimeInterval(3)
    } else if let nextFireDate, nextFireDate > Date() {
      // Dart가 준 실제 다음 발화 날짜 — 오늘/내일 추측 제거(유령 사다리 차단).
      base = nextFireDate
    } else {
      base = retryBaseDate(
        hour: hour,
        minute: minute,
        preserveActiveWindow: false,
        completedDateKey: morningMissionCompletedDateKey,
        dartWeekdays: dartWeekdays
      )
    }
    storeMorningNextFireEpoch(base)
    NSLog("[ALARMKIT-DIAG] afterCompletion h=\(hour) m=\(minute) immediate=\(fireImmediately) completedStamp=\(UserDefaults.standard.string(forKey: morningMissionCompletedDateKey) ?? "nil") base=\(base)")

    var mainScheduled = false
    do {
      if fireImmediately {
        try await scheduleOneMorningFixedAlarm(
          id: morningId,
          fireDate: base,
          soundName: soundName,
          intentAlarmId: nextAlarmId
        )
      } else {
        try await scheduleOneMorningRelativeAlarm(
          id: morningId,
          hour: hour,
          minute: minute,
          dartWeekdays: dartWeekdays,
          soundName: soundName,
          intentAlarmId: nextAlarmId
        )
      }
      mainScheduled = true
    } catch {
      NSLog("[ALARMKIT] afterCompletion main schedule failed: \(error.localizedDescription)")
    }

    if !mainScheduled {
      await scheduleMorningMainFallback(at: base, soundName: soundName, intentAlarmId: nextAlarmId)
    }
    await scheduleMorningRetryLadder(baseDate: base, soundName: soundName, intentAlarmId: nextAlarmId)
    if mainScheduled, !fireImmediately {
      UserDefaults.standard.set(
        morningBatchSignature(
          hour: hour,
          minute: minute,
          dartWeekdays: dartWeekdays,
          soundName: soundName,
          base: base
        ),
        forKey: morningBatchSignatureKey
      )
    }
    NSLog("[ALARMKIT] next morning re-armed at \(hour):\(minute) (main=\(mainScheduled)), fixed retries from \(base), sound=\(soundName)")
  }

  /// Cancel the entire morning ladder (main + all retries). For OFF/time-change.
  @available(iOS 26.0, *)
  private static func cancelMorningLadder() {
    UserDefaults.standard.removeObject(forKey: morningBatchSignatureKey)
    // 아침 알람 전체 OFF — 알람별 등록도 전부 제거.
    stopAllPerAlarmRegistrations(cancelToo: true)
    try? AlarmManager.shared.cancel(id: morningId)
    cancelMorningMainFallback()
    for rid in morningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    purgeStaleRetrySlots(["A1000040", "A1000050"])
    cancelMorningMissionExitLadder()
  }

  @available(iOS 26.0, *)
  private static func cancelEveningLadder() {
    UserDefaults.standard.removeObject(forKey: eveningBatchSignatureKey)
    cancelEveningChase()
    try? AlarmManager.shared.cancel(id: eveningId)
    purgeStaleRetrySlots(["A1000060"])
    for rid in eveningRetryIds {
      try? AlarmManager.shared.stop(id: rid)
      try? AlarmManager.shared.cancel(id: rid)
    }
    try? AlarmManager.shared.stop(id: eveningSnoozeId)
    try? AlarmManager.shared.cancel(id: eveningSnoozeId)
    try? AlarmManager.shared.stop(id: eveningMissionWatchdogId)
    try? AlarmManager.shared.cancel(id: eveningMissionWatchdogId)
  }

  private func startMonitoringIfNeeded() {
    guard #available(iOS 26.0, *) else { return }
    guard monitoringTask == nil else { return }

    monitoringTask = Task { [weak self] in
      var previousStates: [UUID: Alarm.State] = [:]

      do {
        for await alarms in AlarmManager.shared.alarmUpdates {
          guard !Task.isCancelled else { return }

          for alarm in alarms {
            let id = alarm.id
            guard Self.isTrackedAlarm(id) else { continue }

            let kind = Self.kind(for: id)
            let previous = previousStates[id]

            if alarm.state == .alerting {
              Self.setPending(kind: kind, pending: true)
              await MainActor.run {
                self?.channel?.invokeMethod("onNativeAlarmAlerting", arguments: kind)
              }
            } else if previous == .alerting, alarm.state != .alerting {
              if Self.isPending(kind: kind), !Self.isPrayerActive(kind: kind) {
                try? await Self.scheduleSnooze(kind: kind)
              }
            }

            previousStates[id] = alarm.state
          }
        }
      } catch {
        NSLog("NativeAlarmPlugin monitoring failed: \(error.localizedDescription)")
      }
    }
  }

  @available(iOS 26.0, *)
  private static func isTrackedAlarm(_ id: UUID) -> Bool {
    id == morningId || id == eveningId || id == morningSnoozeId || id == eveningSnoozeId
  }

  @available(iOS 26.0, *)
  private static func kind(for id: UUID) -> String {
    switch id {
    case eveningId, eveningSnoozeId:
      return "evening"
    default:
      return "morning"
    }
  }

  private static func setPending(kind: String, pending: Bool) {
    let key = kind == "evening" ? eveningPendingKey : morningPendingKey
    UserDefaults.standard.set(pending, forKey: key)
  }

  private static func isPending(kind: String) -> Bool {
    let key = kind == "evening" ? eveningPendingKey : morningPendingKey
    return UserDefaults.standard.bool(forKey: key)
  }

  private static func setPrayerActive(kind: String, active: Bool) {
    let key = kind == "evening" ? eveningPrayerActiveKey : morningPrayerActiveKey
    UserDefaults.standard.set(active, forKey: key)
  }

  private static func isPrayerActive(kind: String) -> Bool {
    let key = kind == "evening" ? eveningPrayerActiveKey : morningPrayerActiveKey
    return UserDefaults.standard.bool(forKey: key)
  }

  @available(iOS 26.0, *)
  private static func pauseAlertSound(kind: String) async {
    setPrayerActive(kind: kind, active: true)
    let snoozeId = kind == "evening" ? eveningSnoozeId : morningSnoozeId
    let mainId = kind == "evening" ? eveningId : morningId
    try? AlarmManager.shared.stop(id: snoozeId)
    try? AlarmManager.shared.stop(id: mainId)
  }

  @available(iOS 26.0, *)
  private static func clearPersistence(kind: String) async {
    setPending(kind: kind, pending: false)
    setPrayerActive(kind: kind, active: false)
    let snoozeId = kind == "evening" ? eveningSnoozeId : morningSnoozeId
    let mainId = kind == "evening" ? eveningId : morningId
    try? AlarmManager.shared.cancel(id: snoozeId)
    try? AlarmManager.shared.stop(id: mainId)
  }

  @available(iOS 26.0, *)
  private static func scheduleSnooze(kind: String) async throws {
    guard isPending(kind: kind) else { return }

    let snoozeId = kind == "evening" ? eveningSnoozeId : morningSnoozeId
    let title = kind == "evening" ? "Evening blessing" : "Morning prayer"
    try? AlarmManager.shared.cancel(id: snoozeId)

    let fire = Calendar.current.date(
      byAdding: .second,
      value: snoozeDelaySeconds,
      to: Date()
    ) ?? Date().addingTimeInterval(TimeInterval(snoozeDelaySeconds))

    let hour = Calendar.current.component(.hour, from: fire)
    let minute = Calendar.current.component(.minute, from: fire)
    try await scheduleNativeAlarm(
      id: snoozeId,
      hour: hour,
      minute: minute,
      title: title,
      weekly: false,
      dartWeekdays: defaultDartWeekdays
    )
  }

  @available(iOS 26.0, *)
  private static func scheduleNativeAlarm(
    id: UUID,
    hour: Int,
    minute: Int,
    title: String,
    weekly: Bool,
    dartWeekdays: [Int]
  ) async throws {
    if weekly {
      try? AlarmManager.shared.cancel(id: id)
    }

    let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
    let repeats: Alarm.Schedule.Relative.Recurrence
    if weekly {
      repeats = .weekly(localeWeekdays(from: dartWeekdays))
    } else {
      repeats = .never
    }
    let schedule = Alarm.Schedule.relative(
      .init(time: time, repeats: repeats)
    )

    let localizedTitle = LocalizedStringResource(stringLiteral: title)
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(title: localizedTitle)
    } else {
      let stopButton = AlarmButton(
        text: LocalizedStringResource(stringLiteral: "Stop"),
        textColor: .white,
        systemImageName: "stop.circle"
      )
      alert = AlarmPresentation.Alert(title: localizedTitle, stopButton: stopButton)
    }
    let presentation = AlarmPresentation(alert: alert)

    let attributes = AlarmAttributes<GraceAlarmMetadata>(
      presentation: presentation,
      metadata: GraceAlarmMetadata(),
      tintColor: .white
    )

    let configuration = AlarmManager.AlarmConfiguration<GraceAlarmMetadata>(
      schedule: schedule,
      attributes: attributes,
      sound: .named(defaultMorningAlarmKitSoundName)
    )

    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
  }
}
