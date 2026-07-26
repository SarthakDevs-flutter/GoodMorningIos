import AppIntents
import Foundation

/// AlarmKit mission intent for the alarm's stop/slide action. It opens the app
/// to the foreground and sets a pending-mission flag that Flutter consumes on
/// launch to route into SimpleMorningMissionScreen.
///
/// Note: stop here does NOT complete/cancel the alarm in our app logic — only
/// Amen does. This intent just routes the user into the mission.
@available(iOS 26.0, *)
struct OpenMissionFromAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Alarm"
#if canImport(AlarmKit)
  static var supportedModes: IntentModes { .foreground(.immediate) }
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

  init() {
    self.source = "alarmkit_stop"
    self.kind = "morning"
    self.alarmId = ""
  }

  init(source: String, kind: String = "morning", alarmId: String = "") {
    self.source = source
    self.kind = kind
    self.alarmId = alarmId
  }

  func perform() async throws -> some IntentResult {
    // If today's mission is already done (Amen), ignore stray retry-ladder
    // alarms — don't route the user back into the mission.
    let today = Self.todayKey()
    // 알람별 완료 우선: 그 알람이 오늘 끝났으면 잔여 재시도는 무시한다.
    if kind == "morning", !alarmId.isEmpty,
       UserDefaults.standard.string(forKey: "morningCompleted_" + alarmId) == today {
      return .result()
    }
    if kind == "morning", alarmId.isEmpty,
       UserDefaults.standard.string(forKey: "missionCompletedDate") == today {
      return .result()
    }
    // 저녁도 동일: 오늘 축복을 마쳤으면 잔여 알람 정지가 미션을 다시 열지
    // 않는다(아멘 후 두 번째 미션이 뜨던 버그의 가드).
    if kind == "evening",
       UserDefaults.standard.string(forKey: "eveningMissionCompletedDate") == today {
      return .result()
    }
    if kind == "morning" {
      // 울린 알람이 이 미션의 주인 — 이후 추격 재무장 슬롯들이 이 id를
      // 싣는다(다음 알람 id가 실리면 그 알람이 오완료되는 사고 방지).
      if !alarmId.isEmpty {
        UserDefaults.standard.set(
          alarmId,
          forKey: NativeAlarmPlugin.morningMissionActiveAlarmIdKey
        )
      }
      UserDefaults.standard.set(
        OpenMissionFromAlarmIntent.todayKey(),
        forKey: NativeAlarmPlugin.morningMissionStartedDateKey
      )
      // 정지 메아리 먼저(Alare 기법): 아래의 무거운 pause·추격 무장이 도중에
      // 끊겨도 22초 뒤 한 발이 돌아와 이 perform 전체를 다시 시도한다.
      // '침묵 먼저, 생존 나중' 순서가 남기던 구멍의 마개.
      await NativeAlarmPlugin.armStopEcho(kind: "morning")
      try? await NativeAlarmPlugin.pauseMorningRetriesForMission()
      // iOS 26은 알람 중 전원(측면) 버튼도 이 stop 인텐트를 실행한다(실측:
      // 06:00:08 앱 기동 + 06:00:10 전면 취소 → 20분 침묵). '잡았지만 안
      // 일어난' 경우를 위해 추격을 즉시 무장한다 — 미션 화면이 실제로 열리면
      // 기존 경로(미션 시작 pause·sceneDidBecomeActive)가 22초 안에 취소하고,
      // 안 열리면 알람이 계속 돌아온다(알라미 원칙).
      try? await NativeAlarmPlugin.armMorningChaseAfterStop()
      // 콜드스타트 재시도: 인텐트로 갓 깨어난 프로세스의 '첫' 예약(메아리)이
      // 거부되는 실측(2026-07-15 15:36, 3회 전부) — 연결이 데워진 지금
      // 한 번 더. 이미 성공해 있으면 같은 고정 id 교체라 무해.
      await NativeAlarmPlugin.armStopEcho(kind: "morning")
    } else if kind == "evening" {
      // 아침과 동일한 메아리-먼저 순서.
      await NativeAlarmPlugin.armStopEcho(kind: "evening")
      try? await NativeAlarmPlugin.pauseEveningRetriesForMission()
      try? await NativeAlarmPlugin.armEveningChaseAfterStop()
      await NativeAlarmPlugin.armStopEcho(kind: "evening")
    }
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
    return .result()
  }

  static func todayKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }
}
