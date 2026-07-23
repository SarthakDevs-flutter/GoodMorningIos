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
      // 순간 신호는 전원 버튼을 누르는 손짓(Face ID 순간 해제)에도 참이
      // 된다 — 1.5초 뒤에도 유지될 때만 '참여'로 인정한다. 실측
      // 2026-07-11 07:21/07:51: 3번째 전원 누름 3초 뒤 추격 전멸의 뿌리.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let stillUnlocked = UIApplication.shared.isProtectedDataAvailable
        let stillOn = UIScreen.main.brightness > 0.01
        let stillActive = UIApplication.shared.applicationState == .active
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
