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
struct OpenMissionFromAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop Alarm"
#if canImport(AlarmKit)
  // ✅ .foreground(.immediate) — 슬라이드 정지 시 시스템이 앱을 실제로 연다.
  //
  // 실측(2026-08-05, Chirag): 예전의 .foreground(.dynamic) +
  // ForegroundContinuableIntent.requestToContinueInForeground()는 잠금 해제
  // (Face ID/패스코드) 후에도 앱을 열지 못하고 홈 화면만 떴다. AlarmKit 정지
  // 버튼에서 앱을 여는 Apple 공식 방식은 .foreground(.immediate)이며, 이는
  // (deprecated된) openAppWhenRun = true와 동일하게 동작한다. 정지 버튼을 누른
  // 것 자체가 사용자 상호작용이므로 잠금 화면 뒤에서도 인증 직후 앱이 뜬다.
  //
  // 무음 모드 관련: 예전 .dynamic 선택 이유였던 "큰 소리 재무장을 배경에서
  // 먼저 돌린다"는, 이제 아래 perform()에서 재무장을 Task.detached로 떼어내어
  // 대체한다 — .immediate가 열어준 앱 프로세스 안에서 재무장이 계속 돈다.
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
    // 겹쳐 울리던 나머지 발도 전부 멈춘다 — 슬라이드 정지 순간 모든 소리가
    // 꺼지고 미션 화면만 뜨도록. (지금 울고 있는 .alerting 발만 멈추므로 미래
    // 사다리는 그대로다. 아래 handleAlarmStopped가 방치 대비 사다리를 재무장한다.)
    NativeAlarmPlugin.stopAllActiveRingingSounds()

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

    // ⚠️ pendingMission을 '무거운 재무장 이전에' 먼저 쓴다.
    // force-quit + 잠금 상태에서 iOS는 이 정지 인텐트의 perform()에 아주 짧은
    // 배경 실행 시간만 준다. 예전 순서(armStopEcho·handleAlarmStopped 재무장을
    // 먼저 돌리고 그 뒤에 pendingMission 기록)는, 재무장(최대 20슬롯 × 재시도·
    // 대기 = 수 초)이 그 예산을 다 써버려 perform()이 플래그를 쓰기 전에 종료되면
    // pendingMission이 끝내 기록되지 않았다 → 잠금 해제 후 앱을 열어도 미션으로
    // 라우팅할 근거가 없어 "슬라이드 정지했는데 아무것도 안 열림"이 된다.
    // 플래그는 UserDefaults 한 줄이라 즉시 영구 저장 — 먼저 남기면 재무장이
    // 중간에 죽어도 다음 앱 실행에서 미션이 열린다. (큰 소리 재무장은 아래에서
    // 그대로 돌고, 포그라운드 전환 요청은 재무장 완료 후 맨 끝에서 한다 — 무음
    // 모드 수정의 '재무장 먼저, 포그라운드 나중' 순서 계약은 그대로 유지.)
    //
    // 대기표는 한 자리 — 이미 '아침' 대기표가 있으면 저녁 stop은 덮지 않는다
    // (아침 우선, 저녁은 자체 잠금·추격이 되살린다).
    let morningAlreadyPending = UserDefaults.standard.bool(forKey: "pendingMission")
      && UserDefaults.standard.string(forKey: "pendingMissionKind") == "morning"
    if !(morningAlreadyPending && kind == "evening") {
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
    }

    // ⚠️ 큰 소리 재무장(armStopEcho + handleAlarmStopped)을 '분리된' 백그라운드
    // Task로 떼어낸다. 재무장은 최대 20슬롯 × 재시도·XPC = 수 초가 걸리는데,
    // perform() 본문에서 이를 await로 끝까지 기다리면 정지 인텐트의 빠듯한
    // 실행 예산을 다 써 앱 오픈/라우팅이 지연·중단될 수 있다. Task.detached는
    // .immediate가 열어준 앱 프로세스 안에서 perform() 반환과 무관하게 계속
    // 돌므로, 무음 모드의 '큰 소리 사다리 재무장'을 지키면서도 미션 오픈을
    // 막지 않는다. (evening stop이어도 재무장은 항상 돌도록 이 블록은 아래
    // 아침-우선 조기 반환보다 먼저 실행한다.)
    let rearmKind = kind
    let rearmAlarmId = alarmId
    let rearmWatchdogId = watchdogAlarmId
    Task.detached(priority: .userInitiated) {
      await NativeAlarmPlugin.armStopEcho(kind: rearmKind)
      await NativeAlarmPlugin.handleAlarmStopped(
        kind: rearmKind,
        alarmId: rearmAlarmId,
        watchdogAlarmId: rearmWatchdogId
      )
    }

    // supportedModes = .foreground(.immediate) 이므로 이 인텐트가 실행되면
    // 시스템이 자동으로 앱을 포그라운드로 연다(잠금 화면이면 인증 후). 어느
    // 미션을 열지는 위에서 쓴 pendingMission 플래그가 결정한다 — 아침 우선
    // 규칙상 evening stop은 기존 아침 대기표를 덮지 않으므로, 앱이 열려도
    // 항상 올바른 미션(아침)으로 라우팅된다. 별도의 포그라운드 요청 호출은
    // 필요 없다.
    return .result()
  }

  static func todayKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }
}
