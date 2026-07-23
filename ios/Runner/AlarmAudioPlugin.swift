import AVFoundation
import Flutter
import MediaPlayer

/// Loops bundled WAV or iPhone system alert sounds for alarms — loud speaker output.
final class AlarmAudioPlugin: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  private static let defaultAlarmToneName = "god_morning_1"
  private static let allowedBundledSoundNames: Set<String> = [
    "god_morning_1",
    "god_morning_2",
    "god_morning_3",
    "god_morning_4",
    "god_morning_5",
    "god_morning_6",
    "god_morning_7",
    "god_morning_9",
    "god_morning_10",
  ]

  private var audioPlayer: AVAudioPlayer?
  private var volumeView: MPVolumeView?
  private var shouldLoopPlayback = true
  private var currentSoundName: String?
  private var currentSoundExtension: String?
  private var currentSoundLoop = true
  /// Background silent loop — keeps audio session alive so alarm overrides
  /// Silent switch / Do Not Disturb / Airplane mode at fire time (Alarmy trick).
  private var silentPlayer: AVAudioPlayer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "means_of_grace/alarm_audio",
      binaryMessenger: registrar.messenger()
    )
    let instance = AlarmAudioPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      let args = call.arguments as? [String: Any]
      let type = args?["type"] as? String ?? "bundled"
      let loud = args?["loud"] as? Bool ?? true
      if type == "system" {
        let loop = args?["loop"] as? Bool ?? true
        startBundled(name: Self.defaultAlarmToneName, ext: "wav", loud: loud, loop: loop, result: result)
      } else {
        let requestedName = args?["name"] as? String ?? Self.defaultAlarmToneName
        let name = Self.allowedBundledSoundNames.contains(requestedName)
          ? requestedName
          : Self.defaultAlarmToneName
        let ext = args?["ext"] as? String ?? "wav"
        let loop = args?["loop"] as? Bool ?? true
        startBundled(name: name, ext: ext, loud: loud, loop: loop, result: result)
      }
    case "reinforceLoud":
      reinforceLoudOutput()
      result(true)
    case "stop":
      let args = call.arguments as? [String: Any]
      let keepSession = args?["keepSession"] as? Bool ?? false
      stop(keepSession: keepSession, result: result)
    case "isPlaying":
      let playing = audioPlayer?.isPlaying ?? false
      result(playing)
    case "prepareForSpeech":
      do {
        try prepareForSpeech()
        result(true)
      } catch {
        result(
          FlutterError(
            code: "speech_session_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "prepareForPlayback":
      do {
        try activateLoudSession()
        NSLog("[AUDIO] session restored to .playback")
        result(true)
      } catch {
        result(
          FlutterError(
            code: "playback_session_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "armSilentLoop":
      armSilentLoop(result: result)
    case "disarmSilentLoop":
      disarmSilentLoop(result: result)
    case "isSilentLoopArmed":
      result(silentPlayer?.isPlaying ?? false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// DEAD CODE (kept for reference): Dart no longer calls this, but keeping
  /// the implementation makes it easy to fall back if we ever drop the
  /// package dependency.
  private func armSilentLoop(result: @escaping FlutterResult) {
    NSLog("[ARM-NATIVE] start")
    do {
      let session = AVAudioSession.sharedInstance()
      NSLog("[ARM-NATIVE] setCategory(.playback, .mixWithOthers)")
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      NSLog("[ARM-NATIVE] setActive(true)")
      try session.setActive(true, options: [])

      if let player = silentPlayer, player.isPlaying {
        NSLog("[ARM-NATIVE] already playing — return")
        result(true)
        return
      }

      NSLog("[ARM-NATIVE] looking up silent.wav in Bundle.main")
      guard let url = Bundle.main.url(forResource: "silent", withExtension: "wav") else {
        NSLog("[ARM-NATIVE] silent.wav NOT FOUND in bundle")
        result(
          FlutterError(
            code: "missing_silent",
            message: "silent.wav not found in app bundle",
            details: nil
          )
        )
        return
      }
      NSLog("[ARM-NATIVE] silent.wav url=\(url.path)")

      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = 0.0
      player.prepareToPlay()
      let started = player.play()
      NSLog("[ARM-NATIVE] play() returned \(started), isPlaying=\(player.isPlaying)")
      guard started else {
        result(
          FlutterError(
            code: "silent_play_failed",
            message: "silent.wav play() returned false",
            details: nil
          )
        )
        return
      }
      silentPlayer = player
      NSLog("[ARM-NATIVE] success — silentPlayer set, duration=\(player.duration)s")
      result(true)
    } catch {
      NSLog("[ARM-NATIVE] EXCEPTION: \(error.localizedDescription)")
      result(
        FlutterError(
          code: "silent_arm_error",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func disarmSilentLoop(result: @escaping FlutterResult) {
    silentPlayer?.stop()
    silentPlayer = nil
    result(true)
  }

  private func activateLoudSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playback,
      mode: .default,
      options: [.allowBluetoothA2DP]
    )
    try session.setActive(true, options: [])
  }

  /// playAndRecord + defaultToSpeaker forces main speaker at full volume.
  /// 잠금 상태에선 record 계열 활성화가 거부된다(마이크 보호) — 그 실패가
  /// '잠금 뒤 인앱 알람 무음'의 원인이었다(watchdog restarting 연발 실측).
  /// 잠겨 있거나 활성화가 실패하면 순수 재생 세션으로 폴백한다: 재생은
  /// 잠금·무음 스위치와 무관하게 스피커로 울린다(예전 엔진의 방식).
  private func activateLoudestSession() throws {
    let session = AVAudioSession.sharedInstance()
    if UIApplication.shared.isProtectedDataAvailable {
      do {
        try session.setCategory(
          .playAndRecord,
          mode: .default,
          options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetooth]
        )
        try session.setActive(true, options: [])
        try session.overrideOutputAudioPort(.speaker)
        return
      } catch {
        NSLog("[AUDIO] playAndRecord failed — playback fallback: \(error.localizedDescription)")
      }
    }
    try session.setCategory(
      .playback,
      mode: .default,
      options: [.allowBluetoothA2DP]
    )
    do {
      try session.setActive(true, options: [])
    } catch {
      // 알람 알럿·직전 STT가 세션을 쥔 직후엔 활성화가 거부되곤 한다 —
      // 비활성화로 초기화한 뒤 한 번 더(잠금 뒤 audio_error 연발 실측
      // 2026-07-11 07:20: 2초마다 시작 실패 반복 = 실효 무음).
      NSLog("[AUDIO] playback activate failed — reset & retry")
      try? session.setActive(false, options: [.notifyOthersOnDeactivation])
      Thread.sleep(forTimeInterval: 0.15)
      try session.setActive(true, options: [])
    }
  }

  /// Raise hardware volume slider to maximum (biggest practical gain on iPhone).
  private func setSystemVolumeToMaximum() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      if self.volumeView == nil {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 10, height: 10))
        view.alpha = 0.01
        view.isHidden = false
        if let window = Self.keyWindow {
          window.addSubview(view)
        }
        self.volumeView = view
      }

      if let slider = self.volumeView?.subviews.compactMap({ $0 as? UISlider }).first {
        slider.value = 1.0
        slider.sendActions(for: .valueChanged)
      }
    }
  }

  private static var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
  }

  private func reinforceLoudOutput() {
    setSystemVolumeToMaximum()
    if let player = audioPlayer {
      player.volume = 1.0
      guard !player.isPlaying else { return }
      try? activateLoudestSession()
      player.play()
    }
  }

  private func startBundled(
    name: String,
    ext: String,
    loud: Bool,
    loop: Bool,
    result: @escaping FlutterResult
  ) {
    if let player = audioPlayer,
       currentSoundName == name,
       currentSoundExtension == ext,
       currentSoundLoop == loop {
      shouldLoopPlayback = loop
      player.numberOfLoops = loop ? -1 : 0
      player.volume = 1.0
      if loud {
        setSystemVolumeToMaximum()
      }
      if !player.isPlaying {
        if loud {
          try? activateLoudestSession()
        } else {
          try? activateLoudSession()
        }
        player.play()
      }
      result(true)
      return
    }

    stopInternal()
    do {
      if loud {
        try activateLoudestSession()
        setSystemVolumeToMaximum()
      } else {
        try activateLoudSession()
      }

      guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
        result(
          FlutterError(
            code: "missing_sound",
            message: "\(name).\(ext) not found in app bundle",
            details: nil
          )
        )
        return
      }

      let player = try AVAudioPlayer(contentsOf: url)
      player.delegate = self
      shouldLoopPlayback = loop
      player.numberOfLoops = loop ? -1 : 0
      player.volume = 1.0
      player.prepareToPlay()
      guard player.play() else {
        result(
          FlutterError(
            code: "play_failed",
            message: "AVAudioPlayer.play() returned false",
            details: nil
          )
        )
        return
      }
      audioPlayer = player
      currentSoundName = name
      currentSoundExtension = ext
      currentSoundLoop = loop
      if loud {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak player] in
          guard let self, let player, self.audioPlayer === player else { return }
          self.setSystemVolumeToMaximum()
          player.volume = 1.0
        }
      }
      result(true)
    } catch {
      result(
        FlutterError(
          code: "audio_error",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard player === audioPlayer else { return }
    guard shouldLoopPlayback else {
      audioPlayer = nil
      return
    }
    player.currentTime = 0
    player.volume = 1.0
    player.play()
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    guard player === audioPlayer else { return }
    guard shouldLoopPlayback else {
      audioPlayer = nil
      return
    }
    player.currentTime = 0
    player.volume = 1.0
    player.play()
  }

  /// Alarm playback uses speaker-heavy modes; STT needs a record-ready session.
  private func prepareForSpeech() throws {
    stopInternal()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .record,
      mode: .measurement,
      options: [.allowBluetooth]
    )
    try session.setActive(true, options: [.notifyOthersOnDeactivation])
  }

  private func stopInternal() {
    audioPlayer?.stop()
    audioPlayer = nil
    shouldLoopPlayback = true
    currentSoundName = nil
    currentSoundExtension = nil
    currentSoundLoop = true
  }

  private func stop(keepSession: Bool = false, result: FlutterResult?) {
    stopInternal()
    // Don't tear down the session while the silent loop is arming the next wake-up.
    if keepSession || silentPlayer != nil {
      result?(true)
      return
    }
    volumeView?.removeFromSuperview()
    volumeView = nil
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
    result?(true)
  }
}
