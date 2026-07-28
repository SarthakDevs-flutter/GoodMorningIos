import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillResignActive(_ scene: UIScene) {
    // sceneWillResignActive also fires for transient system UI / AlarmKit /
    // speech-recognition focus changes while the mission is still visible.
    // Do not arm retry watchdogs here, or they can interrupt an active mission.
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    // 잠금 화면 뒤에서 포그라운드로 실행돼도 becomeActive가 온다 — 그때
    // 추격을 취소하면 잠든 사용자에게 침묵이 된다(실측). 기기가 실제로
    // 잠금 해제됐고 화면이 켜져 있을 때만 '참여'로 인정한다.
    let unlocked = UIApplication.shared.isProtectedDataAvailable
    let screenOn = UIScreen.main.brightness > 0.01
    if unlocked && screenOn {
      // stop intent(사이드 버튼) 직후에 Face ID 잠금 해제로 인해 활성화된 것이라면,
      // 사용자가 아직 미션에 의식적으로 참여한 것이 아니므로 chase를 걷지 않고 유지한다.
      let ts = UserDefaults.standard.double(forKey: "grace_stop_intent_ts")
      let elapsed = Date().timeIntervalSince1970 - ts
      if ts > 0 && elapsed < 10.0 {
        NSLog("[ALARMKIT] becomeActive due to recent stop intent (\(Int(elapsed))s ago) — keeping chase")
        super.sceneDidBecomeActive(scene)
        return
      }

      // 순간 신호는 전원 버튼을 누르는 손짓(Face ID 순간 해제)에도 참이
      // 된다 — 1.5초 뒤에도 유지될 때만 '참여'로 인정한다. 실측
      // 2026-07-11 07:21/07:51: 3번째 전원 누름 3초 뒤 추격 전멸의 뿌리.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let stillUnlocked = UIApplication.shared.isProtectedDataAvailable
        let stillOn = UIScreen.main.brightness > 0.01
        let stillActive = UIApplication.shared.applicationState == .active
        
        // 1.5초 뒤 시점에서도 최근 stop intent 조건이 유효한지 다시 확인한다 (비동기 지연 실행 대응)
        let currentTs = UserDefaults.standard.double(forKey: "grace_stop_intent_ts")
        let currentElapsed = Date().timeIntervalSince1970 - currentTs
        if currentTs > 0 && currentElapsed < 12.0 {
          NSLog("[ALARMKIT] engagement check deferred due to recent stop intent — keeping chase")
          return
        }

        if stillUnlocked && stillOn && stillActive {
          NativeAlarmPlugin.cancelForegroundMissionExitWatchdogs(
            reason: "sceneDidBecomeActive_sustained"
          )
        } else {
          NSLog("[ALARMKIT] engagement not sustained — chase kept")
        }
      }
    } else {
      NSLog("[ALARMKIT] becomeActive behind lock/screen-off — chase kept")
    }
    super.sceneDidBecomeActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    NativeAlarmPlugin.armMissionExitWatchdogsIfNeeded(reason: "sceneDidEnterBackground")
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    NativeAlarmPlugin.armMissionExitWatchdogsIfNeeded(reason: "sceneDidDisconnect")
    super.sceneDidDisconnect(scene)
  }
}
