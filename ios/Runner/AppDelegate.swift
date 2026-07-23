import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var alarmLaunchChannel: FlutterMethodChannel?
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AlarmAudioPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "AlarmAudioPlugin")!
    )
    // AlarmKit PoC probe — register native plugin so Flutter can call
    // isAvailable / requestAuthorization / authorizationState (means_of_grace/native_alarm).
    NativeAlarmPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "NativeAlarmPlugin")!
    )
    StoreKitSubscriptionPlugin.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "StoreKitSubscriptionPlugin")!
    )

    let messenger = engineBridge.applicationRegistrar.messenger()
    alarmLaunchChannel = FlutterMethodChannel(
      name: "means_of_grace/alarm_launch",
      binaryMessenger: messenger
    )
    shareChannel = FlutterMethodChannel(
      name: "god_morning/share",
      binaryMessenger: messenger
    )
    shareChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "shareText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(FlutterError(
          code: "bad_args",
          message: "shareText requires non-empty text.",
          details: nil
        ))
        return
      }
      self?.presentShareSheet(text: text, result: result)
    }

    // Must be AppDelegate so alarm fires in foreground + we still forward taps to Flutter.
    UNUserNotificationCenter.current().delegate = self
  }

  private func presentShareSheet(text: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "no_presenter",
          message: "Could not find a view controller for sharing.",
          details: nil
        ))
        return
      }

      let controller = UIActivityViewController(
        activityItems: [text],
        applicationActivities: nil
      )
      if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }
      controller.completionWithItemsHandler = { _, completed, _, _ in
        result(completed)
      }
      presenter.present(controller, animated: true)
    }
  }

  private func topViewController(
    base: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  ) -> UIViewController? {
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController,
       let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }

  private func alarmPayload(from notification: UNNotification) -> String? {
    guard let payload = notification.request.content.userInfo["payload"] as? String else {
      return nil
    }
    if payload == "morning_alarm" || payload == "evening_blessing_alarm" {
      return payload
    }
    return nil
  }

  private func fireAlarmLaunch(_ payload: String) {
    alarmLaunchChannel?.invokeMethod("onAlarmNotification", arguments: payload)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let payload = alarmPayload(from: notification) {
      fireAlarmLaunch(payload)
    }

    // 예약 시 실어둔 포그라운드 표시 플래그(presentBanner/List/Sound/Badge)를
    // 존중한다. 이전에는 무조건 [.banner .list .sound .badge]를 돌려줘서,
    // 미션 화면 위로 융단·방치 시리즈가 10~15초마다 배너로 덮치던 원인.
    // 플래그가 없는 알림은 기존대로 모두 표시. 예약·배달에는 무영향 —
    // 백그라운드/종료 상태 배달은 이 콜백을 아예 거치지 않는다.
    let info = notification.request.content.userInfo
    func flag(_ key: String) -> Bool {
      guard let value = info[key] as? NSNumber else { return true }
      return value.boolValue
    }
    var options: UNNotificationPresentationOptions = []
    if #available(iOS 14.0, *) {
      if flag("presentBanner") { options.insert(.banner) }
      if flag("presentList") { options.insert(.list) }
    } else {
      if flag("presentAlert") { options.insert(.alert) }
    }
    if flag("presentSound") { options.insert(.sound) }
    if flag("presentBadge") { options.insert(.badge) }
    completionHandler(options)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let payload = alarmPayload(from: response.notification) {
      fireAlarmLaunch(payload)
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
