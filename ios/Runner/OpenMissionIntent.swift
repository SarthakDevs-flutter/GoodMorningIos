import AppIntents
import Foundation
#if canImport(AlarmKit)
import AlarmKit
#endif

/// AlarmKit mission intent for the alarm's stop/slide action. It opens the app
/// to the foreground and sets a pending-mission flag that Flutter consumes on
/// launch to route into SimpleMorningMissionScreen.
///
/// Note: stop here does NOT complete/cancel the alarm in our app logic — only
/// Amen does. This intent just routes the user into the mission.
@available(iOS 26.0, *)
struct OpenMissionFromAlarmIntent: LiveActivityIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "Stop Alarm"
#if canImport(AlarmKit)
  // ⚠️ .foreground(.immediate)가 아니라 .foreground(.dynamic)를 쓴다.
  //
  // .immediate는 stop을 누르는 즉시 앱을 포그라운드로 끌어올리려 하는데,
  // 기기가 잠겨 있고 앱이 종료된 상태에서는 포그라운드 전환이 불가능하므로
  // 시스템이 perform() 본문을 잠금 해제까지 지연/종료해버린다. 그 결과
  // 큰 소리 AlarmKit 재무장(armStopEcho + 추격 사다리 재건축)이 실행되지
  // 못하고, 무음 스위치를 존중하는 UNNotification 백스톱만 남는다 —
  // 이것이 "무음 모드에서 첫 알람은 울리는데 재시도는 무음"의 뿌리였다.
  //
  // .dynamic은 perform()을 먼저 '배경'에서 실행한다(잠금 중에도 동작).
  // 재무장을 모두 마친 뒤에야 requestToContinueInForeground()로 포그라운드
  // 전환을 요청하므로, 잠금 해제 전에도 큰 소리 사다리가 계속 살아 있다.
  static var supportedModes: IntentModes { .foreground(.dynamic) }
#else
  static var openAppWhenRun: Bool { true }
#endif

  @Parameter(title: "Source")
  var source: String

  @Parameter(title: "Kind")
  var kind: String

  // 안드로이드의 인텐트 extra처럼, 울린 알람의 앱 알람 id를 정지 버튼에 실어
  // 보낸다. 재예약 레이스와 무관하게 "지금 울린 알람"을 정확히 식별한다.
  @Parameter(title: "AlarmId")
  var alarmId: String

  @Parameter(title: "WatchdogAlarmId")
  var watchdogAlarmId: String

  init() {
    self.source = "alarmkit_stop"
    self.kind = "morning"
    self.alarmId = ""
    self.watchdogAlarmId = ""
  }

  init(source: String, kind: String = "morning", alarmId: String = "", watchdogAlarmId: String = "") {
    self.source = source
    self.kind = kind
    self.alarmId = alarmId
    self.watchdogAlarmId = watchdogAlarmId
  }

  func perform() async throws -> some IntentResult {
    // 이 stop intent가 실행된 시각을 기록한다. 미션 화면이 이 값을 읽어
    // '사이드 버튼에서 온 미션'과 '사용자가 직접 시작한 미션'을 구분한다.
    // Face ID가 사이드 버튼과 동시에 잠금을 풀면 isDeviceInteractive가
    // 거짓 양성을 반환해 engaged 분기로 잘못 들어가는 것을 방지한다.
    UserDefaults.standard.set(
      Date().timeIntervalSince1970,
      forKey: "grace_stop_intent_ts"
    )
    // If today's mission is already done (Amen), ignore stray retry-ladder
    // alarms — don't route the user back into the mission.
    let today = Self.todayKey()
    // 알람별 완료 우선: 그 알람이 오늘 끝났으면 잔여 재시도는 무시한다.
    if kind == "morning", !alarmId.isEmpty,
       UserDefaults.standard.string(forKey: "morningCompleted_" + alarmId) == today {
      return .result()
    }
    if kind == "morning", alarmId.isEmpty,
       NativeAlarmPlugin.getMorningCompletedDate() == today {
      return .result()
    }
    // 저녁도 동일: 오늘 축복을 마쳤으면 잔여 알람 정지가 미션을 다시 열지
    // 않는다(아멘 후 두 번째 미션이 뜨던 버그의 가드).
    if kind == "evening",
       NativeAlarmPlugin.getEveningCompletedDate() == today {
      return .result()
    }
    // 즉시 정지: swiped/stopped된 알람의 소리를 최상단에서 정지.
    if !alarmId.isEmpty, let uuid = UUID(uuidString: alarmId) {
      try? AlarmManager.shared.stop(id: uuid)
    }

    if kind == "morning" {
      NativeAlarmPlugin.setMorningInProgress(true)
      if !alarmId.isEmpty {
        NativeAlarmPlugin.setMorningActiveAlarmId(alarmId)
      }
      NativeAlarmPlugin.setMorningStartedDate(OpenMissionFromAlarmIntent.todayKey())
    } else if kind == "evening" {
      NativeAlarmPlugin.setEveningInProgress(true)
      NativeAlarmPlugin.setEveningStartedDate(OpenMissionFromAlarmIntent.todayKey())
    }

    await NativeAlarmPlugin.armStopEcho(kind: kind)

    try? await NativeAlarmPlugin.handleAlarmStopped(
      kind: kind,
      alarmId: alarmId,
      watchdogAlarmId: watchdogAlarmId
    )
    // 대기표는 한 자리 — 이미 '아침' 대기표가 있는데 저녁 stop이 오면
    // 아침을 지키고(아침 우선), 저녁은 자체 잠금·추격이 되살린다.
    let existingKind = UserDefaults.standard.string(forKey: "pendingMissionKind")
    if UserDefaults.standard.bool(forKey: "pendingMission"),
       existingKind == "morning", kind == "evening" {
      return .result()
    }
    UserDefaults.standard.set(true, forKey: "pendingMission")
    UserDefaults.standard.set(kind, forKey: "pendingMissionKind")
    UserDefaults.standard.set(source, forKey: "pendingMissionSource")
    if !alarmId.isEmpty {
      UserDefaults.standard.set(alarmId, forKey: "pendingMissionAlarmId")
    }
    // 앱이 이미 포그라운드면 launch/resume 소비 경로가 돌지 않는다 — Darwin
    // 알림으로 플러그인에 즉시 알려 미션이 바로 뜨게 한다.
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName("com.bagseonghwa.meansofgrace.pendingMission" as CFString),
      nil,
      nil,
      true
    )
#if canImport(AlarmKit)
    // 위의 큰 소리 재무장(armStopEcho + handleAlarmStopped)이 '배경'에서
    // 모두 끝난 뒤에야 포그라운드 전환을 요청한다. 잠금 화면 뒤에서는 잠금
    // 해제까지 여기서 대기하지만, 그 사이에도 재무장된 AlarmKit 사다리가
    // 무음/진동 스위치를 뚫고 계속 울린다. 잠금 해제되면 앱이 떠서 Flutter가
    // pendingMission 플래그를 소비해 미션 화면으로 라우팅한다(기존 경로).
    // 포그라운드 전환이 실패해도 재무장은 이미 완료됐으므로 try?로 무시한다.
    try? await requestToContinueInForeground()
#endif
    return .result()
  }

  static func todayKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }
}
