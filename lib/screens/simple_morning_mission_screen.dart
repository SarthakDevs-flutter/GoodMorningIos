import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/evening_blessing_content.dart';
import '../data/morning_devotional_content.dart';
import '../data/prayer_only_content.dart';
import '../models/mission_content_mode.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_persistence_service.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_preferences.dart';
import '../services/alarm_sound_service.dart';
import '../services/alarm_store.dart';
import '../services/completion_service.dart';
import '../services/locale_service.dart';
import '../services/native_alarm_service.dart';
import '../services/prayer_preferences_service.dart';
import '../services/streak_service.dart';
import '../services/weather_forecast_service.dart';
import '../services/weather_preferences_service.dart';
import '../utils/speech_match_utils.dart';
import '../widgets/inline_mission_typing_field.dart';

/// 새벽 기도 미션 (MVP).
/// - 요일 테마 + 주차 순환 말씀/기도
/// - 콘텐츠 언어 하나만 표시
/// - 자동 음성 인식 OR 타이핑 선택 — 둘 다 mission strength 동일
/// - 미션 완료 전까지 PopScope로 잠금 (시간 기반 잠금은 alarm_session_service)
enum MissionKind { morning, evening }

class SimpleMorningMissionScreen extends StatefulWidget {
  const SimpleMorningMissionScreen({
    super.key,
    this.alarmId,
    this.onCompleted,
    this.practiceMode = false,
    this.kind = MissionKind.morning,
  });

  final String? alarmId;
  final VoidCallback? onCompleted;
  final bool practiceMode;
  final MissionKind kind;

  /// Warm the shared speech engine before an alarm fires. First-run iOS speech
  /// initialization can take a noticeable beat; doing it from Home makes the
  /// mission's auto-record path attach to the microphone much faster.
  static Future<bool> prewarmSpeechRecognition() =>
      _MissionSpeechRouter.prewarm();

  @override
  State<SimpleMorningMissionScreen> createState() =>
      _SimpleMorningMissionScreenState();
}

enum _MissionMode { record, type }

class _MissionSpeechRouter {
  _MissionSpeechRouter._();

  static final SpeechToText speech = SpeechToText();
  static _SimpleMorningMissionScreenState? _owner;
  static Future<bool>? _initializeFuture;
  static _SimpleMorningMissionScreenState? _listenStartOwner;
  static _SimpleMorningMissionScreenState? _listenActiveOwner;
  static DateTime? _listenSettlesAfter;

  static bool get _isSettling {
    final settlesAfter = _listenSettlesAfter;
    return settlesAfter != null && DateTime.now().isBefore(settlesAfter);
  }

  static _SimpleMorningMissionScreenState? get _callbackOwner =>
      _listenActiveOwner ?? _listenStartOwner ?? _owner;

  static bool blocksListenFor(_SimpleMorningMissionScreenState owner) {
    if (_isSettling) return true;
    if (_listenStartOwner != null && !identical(_listenStartOwner, owner)) {
      return true;
    }
    if (_listenActiveOwner != null && !identical(_listenActiveOwner, owner)) {
      return true;
    }
    return false;
  }

  static void attach(_SimpleMorningMissionScreenState owner) {
    _owner = owner;
  }

  static void detach(_SimpleMorningMissionScreenState owner) {
    if (identical(_owner, owner)) {
      _owner = null;
    }
    if (identical(_listenStartOwner, owner)) {
      _listenStartOwner = null;
    }
    if (identical(_listenActiveOwner, owner)) {
      _listenActiveOwner = null;
      _markSettling();
    }
  }

  static bool tryBeginListen(_SimpleMorningMissionScreenState owner) {
    if (blocksListenFor(owner)) {
      return false;
    }
    _listenSettlesAfter = null;
    _listenStartOwner = owner;
    attach(owner);
    return true;
  }

  static void markListenSubmitted(_SimpleMorningMissionScreenState owner) {
    if (identical(_listenStartOwner, owner)) {
      _listenActiveOwner = owner;
    }
  }

  static void markListening(_SimpleMorningMissionScreenState owner) {
    _listenActiveOwner = owner;
    if (identical(_listenStartOwner, owner)) {
      _listenStartOwner = null;
    }
  }

  static void clearListenStart(
    _SimpleMorningMissionScreenState owner, {
    bool anyOwner = false,
  }) {
    if (anyOwner || identical(_listenStartOwner, owner)) {
      _listenStartOwner = null;
    }
  }

  static void finishListen(
    _SimpleMorningMissionScreenState owner, {
    bool anyOwner = false,
    Duration settle = const Duration(milliseconds: 450),
  }) {
    clearListenStart(owner, anyOwner: anyOwner);
    if (anyOwner || identical(_listenActiveOwner, owner)) {
      _listenActiveOwner = null;
      _markSettling(settle);
    }
  }

  static void _markSettling([
    Duration settle = const Duration(milliseconds: 450),
  ]) {
    _listenSettlesAfter = DateTime.now().add(settle);
  }

  static Future<bool> initializeFor(
    _SimpleMorningMissionScreenState owner,
  ) async {
    attach(owner);
    return prewarm();
  }

  static Future<bool> prewarm() async {
    if (speech.isAvailable) return true;

    final future =
        _initializeFuture ??
        speech.initialize(
          onStatus: (status) => _callbackOwner?._handleSpeechStatus(status),
          onError: (error) => _callbackOwner?._handleSpeechError(error),
          debugLogging: kDebugMode,
        );
    _initializeFuture = future;
    final available = await future;
    if (!available) {
      _initializeFuture = null;
    }
    return available;
  }
}

class _SimpleMorningMissionScreenState extends State<SimpleMorningMissionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _shareChannel = MethodChannel('god_morning/share');
  static const _appStoreLink = 'https://apps.apple.com/app/id6775657705';
  static const _maxSeconds = 45;
  // If the user opens the mission but doesn't finish it within this window,
  // we abandon back to the alarm so it keeps ringing (Amen-only cancel).
  static const _missionTimeoutDuration = Duration(minutes: 1);
  static const _missionActivityRefreshInterval = Duration(seconds: 10);
  static const _missionInactivityGraceDuration = Duration(seconds: 15);

  // Color palette — warm gold accent on cool dark base.
  static const _bgColor = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF1A1A1A);
  static const _divider = Color(0xFF2A2A2A);
  static const _textMuted = Color(0xFF888888);
  static const _textSecondary = Color(0xFFB0B0B0);
  static const _accent = Color(0xFFF0C04F); // warm soft gold for verse ref
  static const _recordRed = Color(0xFFE53935);
  static const _typingMistakeColor = Color(0xFFE53935);

  late DateTime _now;
  Timer? _clockTimer;
  // 추격 '조용 창' 굴림 — 참여가 계속되는 동안(화면 활성+실제 잠금해제)
  // 45초마다 앞 120초 창을 다시 연다. 화면이 잠기면 굴림이 끊겨 남은
  // 추격 꼬리가 저절로 복귀한다(참여=전멸이던 설계의 교체, 2026-07-15).
  Timer? _chaseQuietRollTimer;
  Timer? _recordTimer;
  Timer? _missionTimeoutTimer;
  Timer? _speechRestartTimer;
  Timer? _speechListenWatchdogTimer;
  Timer? _speechInputWatchdogTimer;
  Timer? _missionInactivityTimer;
  Timer? _foregroundAlarmKeepAliveTimer;
  Timer? _missionExitWatchdogArmTimer;
  // Only true after Amen — guards dispose() so abandoning re-arms the alarm.
  bool _completed = false;
  bool _showCompletion = false;
  bool _completionWeatherEnabled = false;
  bool _completionWeatherLoading = false;
  WeatherForecast? _completionWeather;
  WeatherForecastError? _completionWeatherError;
  WeatherTemperatureUnit _completionWeatherUnit =
      WeatherTemperatureUnit.fahrenheit;
  // True after recording/typing starts. If the app leaves after this but before
  // Amen, AlarmKit must ring again; if the app stays foreground, stay quiet.
  bool _missionActionStarted = false;
  DateTime? _lastMissionQuietRefreshAt;
  DateTime? _missionInactivityDeadline;
  int _missionInactivityRemainingSeconds = 0;
  bool _foregroundInactivityRinging = false;
  bool _inactivityAlarmRequiresUserResume = false;
  late final AnimationController _pulse;
  late final TextEditingController _typedController;
  late final FocusNode _typedFocus;
  late final ScrollController _missionScrollController;
  int _missionUserScrollGeneration = 0;
  late final SpeechToText _speech;
  bool _sttAvailable = false;
  bool _speechStartInFlight = false;
  bool _autoRecordingStarted = false;
  bool _autoRecordingInFlight = false;
  int _autoRecordingAttempts = 0;
  Future<void>? _missionForegroundQuietFuture;
  bool _speechAudioPreparedForListen = false;
  bool _speechListening = false;
  bool _speechManuallyPaused = false;
  bool _speechStopRequested = false;
  int _speechListenAttempts = 0;
  int _speechNoInputAttempts = 0;
  // 마이크 오디오 버퍼가 살아있다는 마지막 증거(onSoundLevelChange 수신 시각).
  // 입력 워치독이 '엔진 사망'과 '사용자 침묵/오인식'을 구분하는 근거가 된다.
  DateTime? _lastSpeechSoundLevelAt;
  // 잠금 뒤에서 열려 인앱 알람 루프로 시작한 미션 — 화면을 여는 순간
  // 수동 탭 없이 자동으로 녹음을 시작해야 한다(예전 UX 복원).
  bool _lockedEntryRinging = false;
  String _recognizedText = '';
  String _committedTranscript = '';
  String _lastPartial = '';
  int _speechAttemptVersion = 0;

  int _elapsed = 0;
  bool _isRecording = false;
  bool _recordingDone = false;
  bool _recordingPassed = false;
  _MissionMode _mode = _MissionMode.record;

  late MorningDevotionalItem _devotional;
  late bool _useKoreanContent;
  late String _prayerText;
  late (String, String) _verseText;
  Future<void>? _devotionalLoad;
  MissionContentMode _missionContentMode =
      MissionContentMode.scriptureAndPrayer;
  double _missionPassThreshold =
      PrayerPreferencesService.defaultMissionPassThreshold;

  bool get _isEveningMission => widget.kind == MissionKind.evening;

  AlarmSoundSource? _ownerAlarmSoundSource;
  String? _resolvedAlarmId;
  late Future<void> _ownerAlarmSoundLoadFuture;

  Future<void> _loadOwnerAlarmSound() async {
    if (widget.practiceMode) {
      _ownerAlarmSoundSource = await AlarmSoundPreferences.getSource();
      return;
    }
    if (_isEveningMission) {
      _ownerAlarmSoundSource = await AlarmSoundPreferences.getSource();
      return;
    }
    var alarmId = widget.alarmId;
    if (alarmId == null || alarmId.isEmpty) {
      alarmId = await AlarmSessionService.instance.activeAlarmId();
    }
    if (alarmId != null && alarmId.isNotEmpty) {
      try {
        final alarms = await AlarmStore.loadAlarms();
        final alarm = alarms.firstWhere(
          (a) => a.id == alarmId,
          orElse: () => const MorningAlarm(id: '', hour: 0, minute: 0, weekdays: [], enabled: false),
        );
        if (alarm.id.isNotEmpty && alarm.soundName != null && alarm.soundName!.isNotEmpty) {
          _ownerAlarmSoundSource = AlarmSoundPreferences.sourceForFileName(alarm.soundName);
        }
      } catch (e) {
        debugPrint('Failed to load owner alarm sound in mission screen: $e');
      }
    }
    
    // If still null, try to dynamically resolve it using the same logic as AlarmSoundService
    if (_ownerAlarmSoundSource == null) {
      try {
        final alarms = await AlarmStore.loadAlarms();
        final now = DateTime.now();
        final todayAlarms = alarms.where((a) => a.enabled && a.weekdays.contains(now.weekday)).toList();
        if (todayAlarms.isNotEmpty) {
          MorningAlarm? selectedAlarm;
          if (todayAlarms.length == 1) {
            selectedAlarm = todayAlarms.first;
          } else {
            final nowMinutes = now.hour * 60 + now.minute;
            todayAlarms.sort((a, b) {
              final diffA = (a.minutesOfDay - nowMinutes).abs();
              final diffB = (b.minutesOfDay - nowMinutes).abs();
              return diffA.compareTo(diffB);
            });
            selectedAlarm = todayAlarms.first;
          }
          if (selectedAlarm != null) {
            alarmId = selectedAlarm.id;
            if (selectedAlarm.soundName != null && selectedAlarm.soundName!.isNotEmpty) {
              _ownerAlarmSoundSource = AlarmSoundPreferences.sourceForFileName(selectedAlarm.soundName);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to dynamically resolve owner alarm sound: $e');
      }
    }
    
    _resolvedAlarmId = alarmId;
    if (_resolvedAlarmId != null && _resolvedAlarmId!.isNotEmpty) {
      await AlarmSessionService.instance.activateMorningAlarmSession(alarmId: _resolvedAlarmId);
    }
    _ownerAlarmSoundSource ??= await AlarmSoundPreferences.getSource();
  }

  String get _contentLanguageCode => _devotional.languageCode;

  String get _speechFallbackLocaleId {
    return switch (_contentLanguageCode) {
      'ko' => 'ko_KR',
      'de' => 'de_DE',
      'ru' => 'ru_RU',
      'es' => 'es_ES',
      'pt' => 'pt_BR',
      'zh' => 'zh_CN',
      'ja' => 'ja_JP',
      _ => 'en_US',
    };
  }

  bool get _showScripture => _missionContentMode.includesScripture;

  bool get _showPrayer => _missionContentMode.includesPrayer;

  String get _recordingTargetText {
    final parts = [
      // 시편 표제([다윗의 믹담] 등)는 읽지 않아도 되도록 매칭에서 제외.
      if (_showScripture)
        SpeechMatchUtils.stripUnreadableMarkers(_verseText.$2),
      if (_showPrayer) _prayerText,
    ];
    return parts.join(' ');
  }

  String get _missionDisplayTargetText {
    final parts = [
      if (_showScripture) _verseText.$2,
      if (_showPrayer) _prayerText,
    ];
    return parts.join('\n\n');
  }

  String get _activeTranscript =>
      SpeechMatchUtils.combineTranscript(_committedTranscript, _lastPartial);

  void _resetSpeechTranscriptState() {
    _recognizedText = '';
    _committedTranscript = '';
    _lastPartial = '';
  }

  void _commitLastSpeechPartial() {
    final partial = _lastPartial.trim();
    if (partial.isEmpty) return;
    _committedTranscript = SpeechMatchUtils.appendFinalTranscript(
      _committedTranscript,
      partial,
    );
    _lastPartial = '';
    // 통과선을 넘기는 마지막 텍스트가 onResult가 아니라 이 커밋으로
    // 확정되는 경우(세그먼트 종료·무활동 만료·수동 일시정지)에도 아멘이
    // 켜져야 한다 — 재판정 없이는 '다 읽었는데 아멘이 안 켜짐'.
    if (!_recordingPassed && _recordingMatches) {
      _recordingPassed = true;
    }
  }

  void _clearSpeechStartInFlight({bool anyOwner = false}) {
    _speechStartInFlight = false;
    _MissionSpeechRouter.clearListenStart(this, anyOwner: anyOwner);
  }

  double get _recordingMatchProgress => SpeechMatchUtils.voiceMatchProgress(
    _recordingTargetText,
    _activeTranscript,
  );

  bool get _recordingMatches => SpeechMatchUtils.canAdvanceVoice(
    _recordingTargetText,
    _activeTranscript,
    threshold: _missionPassThreshold,
  );

  // 타이핑 채점은 필드가 정렬하는 그 텍스트(_missionDisplayTargetText)에
  // 문자 정렬 방식으로 — 단어 매처는 공백 없는 타이핑 입력에서 전 언어
  // 0%가 나온다(실사용 회귀).
  double get _typingMatchProgress => SpeechMatchUtils.typedMatchProgress(
    _missionDisplayTargetText,
    _typedController.text,
  );

  bool get _typingDone => SpeechMatchUtils.canAdvanceTyped(
    _missionDisplayTargetText,
    _typedController.text,
    threshold: _missionPassThreshold,
  );

  /// Amen only unlocks after the user actually reads today's verse + prayer.
  /// A silent or unrelated recording finishes the attempt but does not pass.
  bool get _recordingComplete =>
      _recordingPassed || (_recordingDone && _recordingMatches);

  bool get _amenEnabled =>
      _mode == _MissionMode.record ? _recordingComplete : _typingDone;

  @override
  void initState() {
    super.initState();
    if (!widget.practiceMode) {
      unawaited(NativeAlarmService.stopAllActiveSounds());
      unawaited(AlarmSoundService.instance.stop());
      unawaited(NativeAlarmService.clearDeliveredNotifications());
      // ⚠️ 여기서 cancelMorningMissionExitWatchdogs()를 무조건 부르면 안 된다.
      // 그 호출은 '앞으로 120초 동안 울릴 추격을 걷고 꼬리로 밀기'다. 잠금 뒤
      // (사이드 버튼 정지)로 열린 미션에서도 실행되어, 22초 뒤에 와야 할
      // 재울림이 매번 2분 넘게 밀렸다 — 누를 때마다 누적돼 사용자에게는
      // '재시도가 아예 안 온다'로 보인다. 소리 즉시 차단은 위의
      // stopAllActiveSounds()가 이미 담당한다. 조용 창은 아래 postFrame에서
      // '사용자가 실제로 화면을 보는 중(engaged)'일 때만 연다.
      unawaited(
        _isEveningMission
            ? AlarmNotificationService.instance.cancelEveningMainNotification()
            : AlarmNotificationService.instance.cancelMorningMainNotification(),
      );
      if (!_isEveningMission) {
        unawaited(AlarmNotificationService.instance.cancelMorningRingCarpet());
      } else {
        unawaited(AlarmNotificationService.instance.cancelEveningRingCarpet());
      }
    }
    WidgetsBinding.instance.addObserver(this);
    _ownerAlarmSoundLoadFuture = _loadOwnerAlarmSound();
    // 추격 취소는 '화면이 실제로 보인다'는 신호에서만 한다. 앱이 이미
    // 활성인 채 미션이 열리면 라이프사이클 전환 이벤트가 없으므로 여기서
    // 한 번 확인한다. 잠금 뒤(전원 버튼 stop)로 열린 미션은 resumed가
    // 아니라서 추격이 살아남아 계속 울린다 — 그게 의도다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.practiceMode || _completed) return;
      // 즉시 모든 active 알람 소스 정지 (시스템 및 인앱)
      unawaited(NativeAlarmService.stopAllActiveSounds());
      unawaited(AlarmSoundService.instance.stop());

      // lifecycle은 잠금 뒤에서도 resumed라 못 믿는다 — 하드웨어 신호로.
      // 그 신호도 '순간'은 못 믿는다: 전원 버튼을 누르는 손짓에 Face ID가
      // 잠금을 풀면 순간 참이 된다 — 1.5초 뒤에도 유지될 때만 참여로
      // 인정(실측 2026-07-11 07:21/07:51 추격 전멸의 뿌리).
      var engaged = await NativeAlarmService.isDeviceInteractive();
      if (engaged) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (!mounted || _completed) return;
        engaged = await NativeAlarmService.isDeviceInteractive();
      }
      if (engaged) {
        // 미션이 실제로 열렸다 = 이 미션은 진행 중이다. 네이티브 '진행 중'
        // 플래그를 세워야, 사용자가 녹음/타이핑을 시작하지 않고 배경 전환·
        // 강제종료해도 sceneDidEnterBackground/Disconnect 훅이
        // armMissionExitWatchdogsIfNeeded로 30초 추격을 재무장한다(아멘 전까지
        // 알람이 반드시 돌아오도록). 잠금-뒤 분기(아래)는 이미 이 pause를 부른다
        // — 화면-켜짐 분기에만 빠져 있던 비대칭이 '강제종료 후 침묵'의 뿌리.
        // pause는 추격을 울리지 않고 플래그만 세우며, 미션 중 울리면 안 될
        // 경쟁 알람만 정리한다(녹음 시작 경로와 동일, 멱등).
        unawaited(
          _isEveningMission
              ? NativeAlarmService.pauseEveningRetriesForMission()
              : NativeAlarmService.pauseMorningRetriesForMission(
                  alarmId: _resolvedAlarmId,
                ),
        );
        unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
        // 이미 화면에 쌓인 배너는 미션이 뜨는 순간 치운다(예약 무접촉).
        unawaited(NativeAlarmService.clearDeliveredNotifications());
        // 백스톱도 즉시 걷는다 — 자동녹음 quiet(0.7초+)까지 기다리면
        // +45초발이 미션 위로 떨어지는 창이 생긴다.
        unawaited(
          _isEveningMission
              ? AlarmNotificationService.instance
                    .cancelEveningMainNotification()
              : AlarmNotificationService.instance
                    .cancelMorningMainNotification(),
        );
        if (!_isEveningMission) {
          // 화면을 실제로 보며 미션 시작 — 융단 재울림도 여기서 멈춘다.
          unawaited(
            AlarmNotificationService.instance.cancelMorningRingCarpet(),
          );
          // 대신 '죽어야만 들리는' 시리즈를 미리 깐다: 미션 중엔 완전
          // 무음(포그라운드 억제), 강제종료하면 시스템이 배달.
          unawaited(() async {
            await _ownerAlarmSoundLoadFuture;
            final carpetSound = _ownerAlarmSoundSource != null
                ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
                : null;
            await AlarmNotificationService.instance.scheduleMorningAbandonBackstop(
              soundName: carpetSound,
            );
          }());
        } else {
          unawaited(
            AlarmNotificationService.instance.cancelEveningRingCarpet(),
          );
          unawaited(
            AlarmNotificationService.instance.scheduleEveningAbandonBackstop(),
          );
        }
      } else {
        // 잠금 뒤에서 열린 미션 (전원/사이드 버튼을 눌러 화면이 꺼졌거나 잠금 화면 뒤로 전환된 경우)
        // 인앱 알람 소리를 즉시 켜서 사용자 정지 액션을 방해하지 않는다.
        // 대신 시스템 AlarmKit 알람(Stop Echo 및 워치독)이 22초 뒤에 네이티브로 울릴 수 있도록 예약만 안전하게 유지/재무장한다.
        if (!mounted || _completed) return;
        unawaited(() async {
          await _ownerAlarmSoundLoadFuture;
          if (!mounted || _completed) return;
          if (_isEveningMission) {
            await NativeAlarmService.pauseEveningRetriesForMission();
            await NativeAlarmService.resumeEveningRetryAfterMissionAbandoned();
            await AlarmNotificationService.instance.scheduleEveningRingCarpet(
              anchor: DateTime.now(),
            );
          } else {
            await NativeAlarmService.pauseMorningRetriesForMission(
              alarmId: _resolvedAlarmId,
            );
            await NativeAlarmService.resumeMorningRetryAfterMissionAbandoned();
            final carpetSound = _ownerAlarmSoundSource != null
                ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
                : null;
            await AlarmNotificationService.instance.scheduleMorningRingCarpet(
              anchor: DateTime.now(),
              soundName: carpetSound,
            );
          }
        }());
      }
    });
    _now = DateTime.now();
    if (_isEveningMission) {
      _setEveningBlessing();
      _devotionalLoad = Future<void>.value();
    } else {
      _setDevotional(
        MorningDevotionalContent.forDate(
          _now,
          LocaleService.instance.locale.languageCode,
        ),
      );
      _devotionalLoad = _loadPreferredDevotional();
    }
    unawaited(_loadMissionPassThreshold());

    _typedController = TextEditingController()
      ..addListener(_handleTypedControllerChanged);
    _typedFocus = FocusNode();
    _missionScrollController = ScrollController();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _chaseQuietRollTimer =
        Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!mounted || _completed) return;
      if (WidgetsBinding.instance.lifecycleState !=
          AppLifecycleState.resumed) {
        return;
      }
      // 잠금 뒤에서 대기하고 있는 상태(_lockedEntryRinging)이면 120초 창을 연장하지 않는다 (chase 유지)
      if (_lockedEntryRinging) return;
      // 하드웨어 신호로 '실제로 보는 중'일 때만 창을 연장한다 — 잠금 뒤
      // 포그라운드(전원버튼 케이스)에서는 연장하지 않아 추격이 복귀한다.
      if (!await NativeAlarmService.isDeviceInteractive()) return;
      if (!mounted || _completed) return;
      unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // Stop/slide into this screen is now the mission start. We auto-start STT
    // as soon as SpeechToText initializes, so there is no second record button.
    _speech = _MissionSpeechRouter.speech;
    _MissionSpeechRouter.attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initSpeech());
      unawaited(_startAutoRecordingWhenReady());
    });

    // 1-minute timeout: if the user doesn't finish the mission, reset in-place
    // so the alarm rings again — without re-entering this widget (re-entry
    // would re-run initState's Alarm.stop and kill the sound we just started).
    if (!widget.practiceMode) {
      _missionTimeoutTimer = Timer(_missionTimeoutDuration, _onMissionTimeout);
    }
  }

  void _setDevotional(MorningDevotionalItem devotional) {
    _devotional = devotional;
    _useKoreanContent = _devotional.languageCode == 'ko';
    _prayerText = _devotional.prayer;
    _verseText = (_devotional.reference, _devotional.verse);
  }

  void _setEveningBlessing() {
    final code = MorningDevotionalLocalization.normalize(
      LocaleService.instance.locale.languageCode,
    );
    _setDevotional(
      MorningDevotionalItem(
        themeName: EveningBlessingContent.title,
        weekdayLabel: '',
        verse: EveningBlessingContent.prayerFor(code),
        reference: EveningBlessingContent.referenceFor(code),
        prayer: '',
        translation: EveningBlessingContent.translationLabelFor(code),
        languageCode: code,
      ),
    );
    _missionContentMode = MissionContentMode.scriptureOnly;
  }

  Future<void> _loadPreferredDevotional() async {
    if (_isEveningMission) return;
    final plan = await PrayerPreferencesService.getScripturePlan();
    final missionContentMode =
        await PrayerPreferencesService.getMissionContentMode();
    final languageCode = LocaleService.instance.locale.languageCode;
    final devotional = missionContentMode == MissionContentMode.prayerOnly
        ? PrayerOnlyContent.forDate(_now, languageCode)
        : MorningDevotionalContent.forDate(_now, languageCode, plan);
    if (!mounted) return;
    setState(() {
      _setDevotional(devotional);
      _missionContentMode = missionContentMode;
    });
  }

  Future<void> _loadMissionPassThreshold() async {
    final threshold = _isEveningMission
        ? await PrayerPreferencesService.getBlessingPassThreshold()
        : await PrayerPreferencesService.getMissionPassThreshold();
    if (!mounted) return;
    setState(() => _missionPassThreshold = threshold);
  }

  Future<void> _startAutoRecordingWhenReady() async {
    if (_autoRecordingStarted ||
        _autoRecordingInFlight ||
        !mounted ||
        _completed) {
      return;
    }
    // 잠금 뒤에서 울리며 기다리는 중이면 자동 녹음을 시작하지 않는다 —
    // 이 함수의 quiet가 0.7초 만에 인앱 알람 루프를 죽여 '잠금·무음
    // 관통 연속 울림'을 무력화한다. 화면을 열면 resumed 분기가
    // _startRecording으로 이어받는다.
    if (_lockedEntryRinging || _foregroundInactivityRinging) {
      debugPrint('[MISSION] auto-record deferred — alarm ringing state');
      return;
    }
    _autoRecordingInFlight = true;
    _autoRecordingAttempts += 1;

    // AlarmKit stop/slide launches the app while iOS is still settling audio
    // focus. Keep the App Store-tested settle window before SpeechToText
    // attaches its AVAudioEngine input tap; making this too short causes
    // choppy first-pass dictation on device.
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _completed) return;
      // 함수 진입 시점엔 잠금 판정(비동기)이 아직 안 끝났을 수 있다 —
      // 딜레이 후 재확인 없이는 quiet가 방금 켜진 인앱 루프를 죽인다
      // (실측 2026-07-10 20:30:07 — 루프 0.8초 사망의 레이스).
      if (_lockedEntryRinging || _foregroundInactivityRinging) {
        debugPrint('[MISSION] auto-record deferred — alarm ringing state');
        return;
      }

      await _devotionalLoad;
      if (!mounted || _completed) return;

      await _quietNativeAlarmForMissionEntry();
      await AlarmSoundService.instance.prepareForSpeechRecognition();
      _speechAudioPreparedForListen = true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || _completed) return;

      await _initSpeech();
      if (!mounted || _completed) return;

      if (!_sttAvailable) {
        debugPrint('[STT] auto-record waiting for speech availability');
        // 마이크/음성 권한이 없어도 알람은 되돌아와야 한다 — 무활동 창을
        // 무장하지 않으면 이 화면이 떠 있는 한 영구 침묵(아멘-온리 위반).
        _resetMissionInactivityWindow(force: true);
        return;
      }

      await _resetSpeechEngineBeforeAutoRecord();
      if (!mounted || _completed) return;

      await _startRecording();
      if (_isRecording ||
          _speechStartInFlight ||
          _speechListening ||
          _activeTranscript.trim().isNotEmpty) {
        _autoRecordingStarted = true;
      }
    } finally {
      _autoRecordingInFlight = false;
      if (!_autoRecordingStarted &&
          mounted &&
          !_completed &&
          _autoRecordingAttempts < 6) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted && !_completed) {
            unawaited(_startAutoRecordingWhenReady());
          }
        });
      }
    }
  }

  Future<void> _resetSpeechEngineBeforeAutoRecord() async {
    final needsReset =
        _autoRecordingAttempts > 1 ||
        _speech.isListening ||
        _speechListening ||
        _speechStartInFlight ||
        _speechStopRequested ||
        _lastPartial.trim().isNotEmpty;
    if (!needsReset) {
      return;
    }

    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAudioPreparedForListen = false;
    _speechStopRequested = false;
    _speechListening = false;
    try {
      await _speech.cancel();
    } catch (error) {
      debugPrint('[STT] pre-record cancel failed: $error');
    }
    _clearSpeechStartInFlight();
    _MissionSpeechRouter.finishListen(this);
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _quietNativeAlarmForMissionEntry() {
    if (widget.practiceMode || _completed) return Future<void>.value();
    final existing = _missionForegroundQuietFuture;
    if (existing != null) return existing;

    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    _missionActionStarted = true;
    _lastMissionQuietRefreshAt = DateTime.now();
    final future = () async {
      // The system/AlarmKit alert sound is what's actually audible on entry
      // via notification tap, lock screen, notification center, or app icon
      // (unlike the AlarmKit stop-button path, where the OS already silenced
      // it before the app opened). initState fires this same call
      // unawaited for earliest dispatch, but nothing downstream previously
      // confirmed it landed before recording started — awaiting it here is
      // what actually guarantees no audible overlap.
      await NativeAlarmService.stopAllActiveSounds();
      if (_isEveningMission) {
        // 초경량 취소 — 빈 깡통 90발 취소가 STT 시작을 늦추던 낭비 제거.
        unawaited(
          AlarmNotificationService.instance.cancelEveningMainNotification(),
        );
        await NativeAlarmService.pauseEveningRetriesForMission();
      } else {
        unawaited(
          AlarmNotificationService.instance.cancelMorningMainNotification(),
        );
        await NativeAlarmService.pauseMorningRetriesForMission(
          alarmId: _resolvedAlarmId,
        );
      }
      await AlarmSoundService.instance.stop();
    }();
    _missionForegroundQuietFuture = future;
    return future;
  }

  void _onMissionTimeout() {
    if (widget.practiceMode) return;
    if (!mounted || _completed) return;
    if (_missionActionStarted) {
      debugPrint('[MISSION] timeout while active — stay quiet in foreground');
      _missionTimeoutTimer = Timer(_missionTimeoutDuration, _onMissionTimeout);
      return;
    }
    debugPrint('[MISSION] timeout — in-place reset, alarm resumes');
    setState(() {
      _isRecording = false;
      _speechListening = false;
      _recordingDone = false;
      _recordingPassed = false;
      _foregroundInactivityRinging = true;
      _inactivityAlarmRequiresUserResume = true;
      _resetSpeechTranscriptState();
      _elapsed = 0;
      _typedController.clear();
    });
    AlarmSessionService.instance.setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
    unawaited(_startForegroundMissionAlarm());
    _missionTimeoutTimer = Timer(_missionTimeoutDuration, _onMissionTimeout);
  }

  Future<void> _startForegroundMissionAlarm() async {
    // ⚠️ 여기서 전체 취소(cancelMorning/EveningAlarm)를 부르면 미션이
    // 깔아둔 강제종료 대비 시리즈·융단까지 철거된다 — 인앱 울림 중
    // 강제종료가 완전 침묵이 되던 뿌리. 경량 취소만.
    if (_isEveningMission) {
      await AlarmNotificationService.instance.cancelEveningMainNotification();
      if (!mounted || _completed) return;
      await AlarmSoundService.instance.start(sourceOverride: _ownerAlarmSoundSource);
      _startForegroundAlarmKeepAlive();
      return;
    }
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      await AlarmNotificationService.instance.cancelMorningMainNotification();
      await NativeAlarmService.cancelMorningMissionExitWatchdogs();
    } else {
      await _resumeAlarmAfterAbandon();
    }
    if (!mounted || _completed) return;
    await AlarmSoundService.instance.start(sourceOverride: _ownerAlarmSoundSource);
    _startForegroundAlarmKeepAlive();
  }

  /// Silence normal AlarmKit retries while the user is actively recording/typing.
  /// If the app leaves before Amen, native lifecycle hooks re-arm the watchdog.
  Future<void> _silenceAlarmForMissionAction({
    bool allowQuietForegroundAlarm = false,
  }) async {
    if ((_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) &&
        !allowQuietForegroundAlarm) {
      return;
    }
    if (allowQuietForegroundAlarm) {
      _inactivityAlarmRequiresUserResume = false;
    }
    _missionActionStarted = true;
    _lastMissionQuietRefreshAt = DateTime.now();
    if (widget.practiceMode) {
      await AlarmSoundService.instance.stop();
      return;
    }
    unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
    await _extendMissionQuietWindow(stopCurrentSound: true);
    _resetMissionInactivityWindow(
      force: true,
      allowQuietForegroundAlarm: allowQuietForegroundAlarm,
    );
  }

  Future<void> _extendMissionQuietWindow({
    required bool stopCurrentSound,
  }) async {
    if (_isEveningMission) {
      unawaited(
        AlarmNotificationService.instance.cancelEveningMainNotification(),
      );
      await NativeAlarmService.pauseEveningRetriesForMission();
      if (stopCurrentSound) {
        // Silences the actual ringing AlarmKit/system alert, not just the
        // Dart-side loop — without this, recording could start while the
        // system alarm sound is still audibly playing.
        await NativeAlarmService.stopAllActiveSounds();
        await AlarmSoundService.instance.stop();
      }
      return;
    }
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      unawaited(
        AlarmNotificationService.instance.cancelMorningMainNotification(),
      );
      await NativeAlarmService.pauseMorningRetriesForMission(
        alarmId: _resolvedAlarmId,
      );
      if (stopCurrentSound) {
        await NativeAlarmService.stopAllActiveSounds();
        await AlarmSoundService.instance.stop();
      }
      return;
    }
    final resolvedSoundName = _ownerAlarmSoundSource != null
        ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
        : null;
    await AlarmScheduleHelper.rearmMorningLiveAlarmFromNow(
      delay: const Duration(minutes: 1),
      soundName: resolvedSoundName,
    );
    if (stopCurrentSound) {
      await AlarmScheduleHelper.silenceMorningLiveAlarm();
      await AlarmSoundService.instance.stop();
    }
  }

  void _markMissionProgressActivity({
    bool force = false,
    bool allowQuietForegroundAlarm = false,
  }) {
    if (!mounted || _completed || !_missionActionStarted) return;
    if (widget.practiceMode) return;
    // If the foreground inactivity alarm is ringing, only an explicit user
    // action should quiet it. In record mode, late STT/audio callbacks can be
    // caused by the alarm sound itself, so never treat them as progress.
    if ((_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) &&
        _mode == _MissionMode.record &&
        !allowQuietForegroundAlarm) {
      return;
    }
    if (_amenEnabled) {
      _cancelMissionInactivityWindow();
      return;
    }

    _resetMissionInactivityWindow(
      force: force,
      allowQuietForegroundAlarm: allowQuietForegroundAlarm,
    );

    final now = DateTime.now();
    final lastRefresh = _lastMissionQuietRefreshAt;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < _missionActivityRefreshInterval) {
      return;
    }

    _lastMissionQuietRefreshAt = now;
    // Keep AlarmKit normal retries cancelled while STT is active. Calling
    // AlarmSoundService.stop() here can deactivate AVAudioSession and make
    // speech recognition feel choppy.
    unawaited(_extendMissionQuietWindow(stopCurrentSound: false));
  }

  void _resetMissionInactivityWindow({
    bool force = false,
    bool allowQuietForegroundAlarm = false,
  }) {
    if (widget.practiceMode) return;
    if (!mounted || _completed || !_missionActionStarted || _amenEnabled) {
      _cancelMissionInactivityWindow();
      return;
    }
    if ((_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) &&
        !allowQuietForegroundAlarm) {
      if (force) setState(() {});
      return;
    }
    if (allowQuietForegroundAlarm) {
      _inactivityAlarmRequiresUserResume = false;
    }

    _missionInactivityDeadline = DateTime.now().add(
      _missionInactivityGraceDuration,
    );
    _missionInactivityRemainingSeconds =
        _missionInactivityGraceDuration.inSeconds;

    if (_foregroundInactivityRinging) {
      _foregroundInactivityRinging = false;
      _foregroundAlarmKeepAliveTimer?.cancel();
      _foregroundAlarmKeepAliveTimer = null;
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
      unawaited(AlarmSoundService.instance.stop());
      if (_mode == _MissionMode.record && _isRecording) {
        _scheduleSpeechRestart();
      }
    }

    _missionInactivityTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickMissionInactivityWindow(),
    );
    if (force) setState(() {});
  }

  void _cancelMissionInactivityWindow() {
    _missionInactivityTimer?.cancel();
    _missionInactivityTimer = null;
    _missionInactivityDeadline = null;
    _missionInactivityRemainingSeconds = 0;
    if (_foregroundInactivityRinging) {
      _foregroundInactivityRinging = false;
      _foregroundAlarmKeepAliveTimer?.cancel();
      _foregroundAlarmKeepAliveTimer = null;
      unawaited(AlarmSoundService.instance.stop());
    }
  }

  void _tickMissionInactivityWindow() {
    if (!mounted || _completed || !_missionActionStarted || _amenEnabled) {
      _cancelMissionInactivityWindow();
      if (mounted) setState(() {});
      return;
    }

    final deadline = _missionInactivityDeadline;
    if (deadline == null) return;

    final remaining = deadline.difference(DateTime.now()).inSeconds + 1;
    if (remaining <= 0) {
      unawaited(_onMissionInactivityExpired());
      return;
    }

    if (remaining != _missionInactivityRemainingSeconds) {
      setState(() => _missionInactivityRemainingSeconds = remaining);
    }
  }

  Future<void> _onMissionInactivityExpired() async {
    if (widget.practiceMode) return;
    if (!mounted || _completed || !_missionActionStarted || _amenEnabled) {
      _cancelMissionInactivityWindow();
      return;
    }
    if (_foregroundInactivityRinging) return;

    debugPrint('[MISSION] inactive for 15s — foreground alarm resumes');
    _missionInactivityTimer?.cancel();
    _missionInactivityTimer = null;
    _recordTimer?.cancel();
    _recordTimer = null;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAudioPreparedForListen = false;
    _speechAttemptVersion++;
    _missionInactivityRemainingSeconds = 0;
    AlarmSessionService.instance.setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
    setState(() {
      _foregroundInactivityRinging = true;
      _inactivityAlarmRequiresUserResume = true;
      _isRecording = false;
      _speechListening = false;
      _speechManuallyPaused = false;
      _recordingDone = false;
      // cancel()은 최종 결과를 주지 않으므로, 여기서 확정해 두지 않으면
      // 재개 후 새 부분 인식이 이 내용을 교체해 지워 버린다.
      _commitLastSpeechPartial();
      _recognizedText = _activeTranscript;
    });
    if (_speech.isListening) {
      try {
        await _speech.cancel();
      } catch (error) {
        debugPrint('[STT] cancel before inactivity alarm failed: $error');
      }
    }
    _clearSpeechStartInFlight();
    _MissionSpeechRouter.finishListen(this);
    // ⚠️ 경량 취소만 — 전체 취소(cancelMorning/EveningAlarm)는 미션이
    // 깔아둔 강제종료 대비 시리즈·융단까지 철거해, 인앱 울림 중
    // 강제종료가 완전 침묵이 된다(가장 빈번한 재울림 경로).
    if (_isEveningMission) {
      await AlarmNotificationService.instance.cancelEveningMainNotification();
      await NativeAlarmService.pauseEveningRetriesForMission();
    } else if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      await AlarmNotificationService.instance.cancelMorningMainNotification();
      await NativeAlarmService.cancelMorningMissionExitWatchdogs();
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || !_foregroundInactivityRinging || _completed) return;
    await AlarmSoundService.instance.start(sourceOverride: _ownerAlarmSoundSource);
    _startForegroundAlarmKeepAlive();
  }

  void _startForegroundAlarmKeepAlive() {
    _foregroundAlarmKeepAliveTimer?.cancel();
    _foregroundAlarmKeepAliveTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (!mounted || !_foregroundInactivityRinging || _completed) {
          _foregroundAlarmKeepAliveTimer?.cancel();
          _foregroundAlarmKeepAliveTimer = null;
          return;
        }
        unawaited(AlarmSoundService.instance.ensurePlaying(sourceOverride: _ownerAlarmSoundSource));
      },
    );
  }

  Future<void> _resumeMissionActionFromInactivity() async {
    if (_completed) return;
    _resetMissionInactivityWindow(force: true, allowQuietForegroundAlarm: true);
    if (_mode == _MissionMode.record && !_isRecording && !_recordingComplete) {
      await _startRecording(
        preserveTranscript: true,
        allowQuietForegroundAlarm: true,
      );
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _MissionSpeechRouter.initializeFor(this);
      if (!mounted) return;
      setState(() => _sttAvailable = available);
      debugPrint('[STT] initialize available=$available');
      if (_mode == _MissionMode.record && !_completed && _isRecording) {
        unawaited(_startSpeechSegment());
      }
    } catch (e) {
      debugPrint('[STT] initialize threw: $e');
      if (mounted) setState(() => _sttAvailable = false);
    }
  }

  void _handleSpeechStatus(String status) {
    debugPrint('[STT] status=$status');
    if (!mounted) return;
    if (status == 'listening' || status == 'done' || status == 'notListening') {
      _clearSpeechStartInFlight(anyOwner: true);
    }
    if (status == 'listening') {
      _MissionSpeechRouter.markListening(this);
      _speechStopRequested = false;
    }
    if (status == 'done' || status == 'notListening') {
      _MissionSpeechRouter.finishListen(this);
      _speechStopRequested = false;
    }
    setState(() => _speechListening = status == 'listening');
    if (status == 'listening') {
      _autoRecordingStarted = true;
      _speechListenAttempts = 0;
      _speechListenWatchdogTimer?.cancel();
      _speechListenWatchdogTimer = null;
    }
    if (!_foregroundInactivityRinging &&
        (status == 'done' || status == 'notListening') &&
        _isRecording) {
      if (_lastPartial.trim().isNotEmpty) {
        setState(() {
          _commitLastSpeechPartial();
          _recognizedText = _activeTranscript;
        });
      }
      _scheduleSpeechRestart();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint('[STT] error=$error');
    _clearSpeechStartInFlight(anyOwner: true);
    _MissionSpeechRouter.finishListen(
      this,
      anyOwner: true,
      settle: const Duration(milliseconds: 650),
    );
    _speechStopRequested = false;
    _scheduleSpeechRestart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _MissionSpeechRouter.detach(this);
    _clockTimer?.cancel();
    _chaseQuietRollTimer?.cancel();
    _recordTimer?.cancel();
    _missionTimeoutTimer?.cancel();
    _speechRestartTimer?.cancel();
    _speechListenWatchdogTimer?.cancel();
    _speechInputWatchdogTimer?.cancel();
    _missionInactivityTimer?.cancel();
    _foregroundAlarmKeepAliveTimer?.cancel();
    _missionExitWatchdogArmTimer?.cancel();
    if (_speech.isListening) {
      unawaited(
        _speech.cancel().whenComplete(() {
          _MissionSpeechRouter.finishListen(this);
        }),
      );
    }
    _speechListening = false;
    _pulse.dispose();
    _typedController.dispose();
    _typedFocus.dispose();
    _missionScrollController.dispose();

    // Abandon path: user closed the mission without completing it. Bring the
    // alarm back so noah can't dismiss it without finishing. Amen path skips
    // this because _completed is true.
    if (!_completed && !widget.practiceMode) {
      debugPrint('[MISSION] abandoned — rearm live alarm after mission exit');
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.ringing,
      );
      unawaited(_resumeAlarmAfterAbandon());
      unawaited(_resumeInAppAlarmSoundIfNeeded());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.practiceMode) return;
    if (_completed) return;
    // '떠나기'(백그라운드/강제종료)는 미션이 아직 시작 전이어도 재무장해야
    // 한다 — 아멘 전까지 알람은 반드시 돌아와야 하므로, 사용자가 인트로만
    // 보다 강제종료해도 침묵하면 안 된다. 반면 복귀(resumed) 인수인계는
    // 미션이 실제로 시작됐거나 잠금-뒤 울림 대기 중일 때만 의미가 있다.
    final leavingForeground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    // 잠금 뒤 울림 대기(_foregroundInactivityRinging)는 자동녹음이 아직
    // 시작 전이라 _missionActionStarted=false — 여기서 걸러버리면 화면을
    // 열어도 녹음 인수인계가 영영 못 돈다(잠금 진입 데드엔드).
    if (!leavingForeground &&
        !_missionActionStarted &&
        !_foregroundInactivityRinging) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_foregroundInactivityRinging) {
        if (_lockedEntryRinging) {
          // 잠금 뒤에서 울리며 기다리던 미션 — 화면을 연 것이 곧 참여.
          // 수동 탭 없이 바로 자동 녹음으로 이어간다(예전 UX).
          unawaited(() async {
            if (!await NativeAlarmService.isDeviceInteractive()) return;
            // 지속 판정 — 전원 손짓의 순간 해제에 인수인계하지 않는다.
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            if (!mounted || _completed) return;
            if (!await NativeAlarmService.isDeviceInteractive()) return;
            _lockedEntryRinging = false;
            _foregroundAlarmKeepAliveTimer?.cancel();
            _foregroundAlarmKeepAliveTimer = null;
            setState(() {
              _foregroundInactivityRinging = false;
              _inactivityAlarmRequiresUserResume = false;
            });
            // 잠금 뒤에서 기다리는 동안 쌓인 배너 청소(표시 전용 — 예약 무접촉).
            unawaited(NativeAlarmService.clearDeliveredNotifications());
            await AlarmSoundService.instance.stop();
            await _startRecording(allowQuietForegroundAlarm: true);
          }());
          return;
        }
        debugPrint(
          '[MISSION] resumed while inactivity alarm rings — keep it on',
        );
        AlarmSessionService.instance.setLiveAlarmUiPhase(
          LiveAlarmUiPhase.ringing,
        );
        if (_isEveningMission) {
          unawaited(
            AlarmNotificationService.instance.cancelEveningMainNotification(),
          );
          unawaited(NativeAlarmService.pauseEveningRetriesForMission());
          unawaited(() async {
            if (await NativeAlarmService.isDeviceInteractive()) {
              await NativeAlarmService.cancelMorningMissionExitWatchdogs();
              await NativeAlarmService.clearDeliveredNotifications();
              await AlarmNotificationService.instance
                  .cancelEveningRingCarpet();
              await AlarmNotificationService.instance
                  .scheduleEveningAbandonBackstop();
            }
          }());
        } else {
          unawaited(
            AlarmNotificationService.instance.cancelMorningMainNotification(),
          );
          unawaited(() async {
            if (await NativeAlarmService.isDeviceInteractive()) {
              await AlarmNotificationService.instance
                  .cancelMorningRingCarpet();
              await NativeAlarmService.cancelMorningMissionExitWatchdogs();
              await NativeAlarmService.clearDeliveredNotifications();
              final carpetSound = _ownerAlarmSoundSource != null
                  ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
                  : null;
              await AlarmNotificationService.instance
                  .scheduleMorningAbandonBackstop(soundName: carpetSound);
            }
          }());
        }
        // ensurePlaying은 이탈 시 stop이 내린 _wantPlaying=false에 막혀
        // 아무것도 못 살린다 — 복귀했는데 '울리는 중' UI만 있고 무음이던
        // 결함. start()는 이미 울리는 중이면 그대로 두고, 꺼졌으면 살린다.
        unawaited(AlarmSoundService.instance.start(sourceOverride: _ownerAlarmSoundSource));
        return;
      }
      debugPrint('[MISSION] resumed during mission — keep AlarmKit quiet');
      _missionExitWatchdogArmTimer?.cancel();
      _missionExitWatchdogArmTimer = null;
      // 화면을 '실제로' 봤을 때만(하드웨어 신호) 융단·추격을 멈춘다 —
      // resumed는 잠금 뒤에서도 오므로 그대로 믿으면 침묵 사고가 된다.
      unawaited(() async {
        if (!await NativeAlarmService.isDeviceInteractive()) return;
        await NativeAlarmService.cancelMorningMissionExitWatchdogs();
        await NativeAlarmService.clearDeliveredNotifications();
        if (!_isEveningMission) {
          await AlarmNotificationService.instance.cancelMorningRingCarpet();
          // 강제종료 대비 무음 시리즈 재무장(미션 중엔 안 들린다).
          final carpetSound = _ownerAlarmSoundSource != null
              ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
              : null;
          await AlarmNotificationService.instance
              .scheduleMorningAbandonBackstop(soundName: carpetSound);
        } else {
          await AlarmNotificationService.instance.cancelEveningRingCarpet();
          await AlarmNotificationService.instance
              .scheduleEveningAbandonBackstop();
        }
      }());
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
      unawaited(_silenceAlarmForMissionAction());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      debugPrint(
        '[MISSION] app may have left during mission — delay AlarmKit watchdog',
      );
      _missionInactivityTimer?.cancel();
      _missionInactivityTimer = null;
      unawaited(AlarmSoundService.instance.stop());
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.ringing,
      );
      // 강제종료(detached)는 프로세스가 곧 죽어 5초 타이머가 돌 시간이 없다 —
      // 여기서 즉시 재무장한다. 미완료 미션이면 무조건(녹음 시작 여부 무관):
      // 아멘 전까지 알람은 돌아와야 한다. (네이티브 sceneDidDisconnect 훅도
      // 30초 추격을 무장하지만, Dart 측 즉시 호출이 알림 백스톱까지 확실히
      // 건다 — 이중 안전망.)
      if (state == AppLifecycleState.detached) {
        debugPrint('[MISSION] detached (force-quit) — re-arm immediately');
        unawaited(_resumeAlarmAfterAbandon());
        return;
      }
      _missionExitWatchdogArmTimer?.cancel();
      _missionExitWatchdogArmTimer = Timer(const Duration(seconds: 5), () {
        // 5초 뒤에도 백그라운드에 머물면(순간 blip이 아니면) 재무장한다.
        // 녹음 시작 전이라도(_missionActionStarted=false) 미완료 미션이면
        // 반드시 — 인트로만 보다 배경 전환해도 침묵하면 안 된다.
        if (!mounted || _completed) {
          return;
        }
        debugPrint('[MISSION] app stayed away — re-arm AlarmKit watchdog');
        unawaited(_resumeAlarmAfterAbandon());
      });
    }
  }

  Future<void> _resumeAlarmAfterAbandon() async {
    if (_isEveningMission) {
      await NativeAlarmService.resumeEveningRetryAfterMissionAbandoned();
      return;
    }
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      await NativeAlarmService.resumeMorningRetryAfterMissionAbandoned();
      return;
    }
    final resolvedSoundName = _ownerAlarmSoundSource != null
        ? AlarmSoundPreferences.fileNameFor(_ownerAlarmSoundSource!)
        : null;
    await AlarmScheduleHelper.rearmMorningLiveAlarmFromNow(
      delay: const Duration(seconds: 10),
      soundName: resolvedSoundName,
    );
  }

  Future<void> _resumeInAppAlarmSoundIfNeeded() async {
    if (_isEveningMission) {
      debugPrint(
        '[MISSION] AlarmKit evening retry ladder owns sound; skip in-app alarm loop',
      );
      return;
    }
    if (await AlarmScheduleHelper.usesAlarmKitForMorning()) {
      debugPrint(
        '[MISSION] AlarmKit retry ladder owns sound; skip in-app alarm loop',
      );
      return;
    }
    await AlarmSoundService.instance.start(sourceOverride: _ownerAlarmSoundSource);
  }

  Future<void> _startRecording({
    bool preserveTranscript = false,
    bool allowQuietForegroundAlarm = false,
  }) async {
    if (_isRecording || _recordingComplete) return;
    if ((_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) &&
        !allowQuietForegroundAlarm) {
      return;
    }
    // Silence current AlarmKit retry sounds before attaching STT. Native
    // re-arms a mission watchdog if the app leaves before Amen.
    if (!widget.practiceMode) {
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
    }
    await _silenceAlarmForMissionAction(
      allowQuietForegroundAlarm: allowQuietForegroundAlarm,
    );
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _speechManuallyPaused = false;
      _elapsed = 0;
      if (!preserveTranscript) {
        _speechAttemptVersion++;
        _resetSpeechTranscriptState();
        _recordingPassed = false;
        _speechNoInputAttempts = 0;
      }
      _speechListening = false;
      _recordingDone = false;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += 1);
      if (_elapsed >= _maxSeconds) _finishRecording();
    });

    // STT runs in parallel with the timer. The timer only ends an attempt;
    // Amen is gated by SpeechMatchUtils against today's verse + prayer.
    unawaited(_startSpeechSegment());
  }

  Future<void> _startSpeechSegment() async {
    // 새 listen 세션의 부분 인식은 빈 상태에서 시작한다. 이전 세션이 최종
    // 결과 없이 끝났다면(취소·워치독 등) 남은 부분 인식을 먼저 확정해서
    // 교체로 사라지지 않게 한다. 세션이 아직 살아 있으면(onError 후 재시작
    // 타이머 등) 진행 중 부분 인식이므로 확정하지 않는다.
    if (!_speech.isListening && _lastPartial.trim().isNotEmpty) {
      _commitLastSpeechPartial();
      if (mounted) {
        setState(() => _recognizedText = _activeTranscript);
      }
    }
    if (!_sttAvailable ||
        _speechStartInFlight ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _foregroundInactivityRinging ||
        _speechManuallyPaused ||
        _speech.isListening) {
      return;
    }
    if (_MissionSpeechRouter.blocksListenFor(this)) {
      debugPrint('[STT] listen delayed: global speech engine busy');
      _scheduleSpeechRestart();
      return;
    }

    final attemptVersion = _speechAttemptVersion;
    if (!_MissionSpeechRouter.tryBeginListen(this)) {
      debugPrint('[STT] listen skipped: global speech engine busy');
      _scheduleSpeechRestart();
      return;
    }
    _speechStartInFlight = true;
    var listenSubmitted = false;
    try {
      final localeId = await SpeechMatchUtils.resolveLocaleId(
        fetchLocales: _speech.locales,
        text: _recordingTargetText,
        appLang: _contentLanguageCode,
        fallback: _speechFallbackLocaleId,
      );
      if (!mounted ||
          attemptVersion != _speechAttemptVersion ||
          !_isRecording ||
          _completed ||
          _recordingComplete ||
          _speechManuallyPaused) {
        return;
      }
      if (_speechAudioPreparedForListen) {
        _speechAudioPreparedForListen = false;
      } else {
        await AlarmSoundService.instance.prepareForSpeechRecognition();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted ||
          attemptVersion != _speechAttemptVersion ||
          !_isRecording ||
          _completed ||
          _recordingComplete ||
          _speechManuallyPaused) {
        return;
      }
      _speechStopRequested = false;
      // 직전 세션의 사운드레벨 잔상이 새 세션의 생존 판정을 가리지 않게 초기화.
      _lastSpeechSoundLevelAt = null;
      _MissionSpeechRouter.markListenSubmitted(this);
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: false,
          listenFor: SpeechMatchUtils.listenFor,
          pauseFor: SpeechMatchUtils.pauseFor,
          localeId: localeId,
        ),
        onSoundLevelChange: (level) {
          // Do not reset the 15s inactivity alarm from raw microphone volume.
          // Breath, room noise, or the alarm itself can move this level without
          // the user actually reading. Only recognized text below should
          // extend the quiet window. This timestamp only proves the audio
          // engine is alive, so the input watchdog stops killing live sessions.
          _lastSpeechSoundLevelAt = DateTime.now();
        },
        onResult: (result) {
          if (attemptVersion != _speechAttemptVersion) return;
          debugPrint('[STT] ${result.recognizedWords}');
          if (!mounted) return;
          if (_foregroundInactivityRinging && _mode == _MissionMode.record) {
            return;
          }
          final beforeProgress = _recordingMatchProgress;
          final beforeTranscript = _activeTranscript;
          if (result.finalResult) {
            final finalWords = result.recognizedWords.trim().isEmpty
                ? _lastPartial
                : result.recognizedWords;
            _committedTranscript = SpeechMatchUtils.appendFinalTranscript(
              _committedTranscript,
              finalWords,
            );
            _lastPartial = '';
          } else {
            final nextPartial = result.recognizedWords.trim();
            if (nextPartial.isNotEmpty) {
              // Android 전용: Android STT는 발화 사이에 부분 결과가 리셋되어
              // 교체 전 커밋이 필요하다. iOS는 부분 결과가 누적·수정되는
              // 방식이라 여기서 커밋하면 같은 단어가 중복된다(2026-06-25
              // 수정을 iOS에서 유지).
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android &&
                  SpeechMatchUtils.shouldCommitPartialBeforeReplacing(
                    _lastPartial,
                    nextPartial,
                  )) {
                _commitLastSpeechPartial();
              }
              _lastPartial = nextPartial;
            }
          }
          setState(() => _recognizedText = _activeTranscript);
          final afterProgress = _recordingMatchProgress;
          // 인식이 목표 구절과 어긋나도 '새 단어가 들렸다'면 사용자는 읽는 중.
          // 일치 진도만 활동으로 치면, 오인식 15초 만에 무활동 알람이 낭독
          // 도중 울린다(미션 중 재울림+받아쓰기 유실 보고의 원인). 소리 크기와
          // 달리 인식 텍스트는 실제 발화 없이는 늘 수 없어 안전하다.
          final heardNewText = _activeTranscript.trim().isNotEmpty &&
              _activeTranscript != beforeTranscript;
          if (!_foregroundInactivityRinging &&
              (afterProgress > beforeProgress ||
                  _recordingMatches ||
                  heardNewText)) {
            _speechNoInputAttempts = 0;
            _speechInputWatchdogTimer?.cancel();
            _speechInputWatchdogTimer = null;
            _markMissionProgressActivity(force: true);
          }
          if (_recordingMatches) {
            _recordingPassed = true;
            _finishRecording();
          }
        },
      );
      listenSubmitted = true;
      debugPrint('[STT] listen started locale=$localeId');
      _armSpeechListenWatchdog(attemptVersion);
      _armSpeechInputWatchdog(attemptVersion);
    } catch (e) {
      debugPrint('[STT] listen threw: $e');
      _clearSpeechStartInFlight();
      _scheduleSpeechRestart();
    } finally {
      // speech_to_text.listen can return before iOS AVAudioEngine has fully
      // reached its listening status. Keep the in-flight guard up until a
      // status/error/watchdog clears it, otherwise a watchdog/retry can start a
      // second AVAudioEngine and crash with SIGABRT.
      if (!listenSubmitted) {
        _clearSpeechStartInFlight();
      }
    }
  }

  Future<void> _restartRecordingAttempt() async {
    if (!mounted || _completed) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAttemptVersion++;
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _clearSpeechStartInFlight();
    _MissionSpeechRouter.finishListen(this);
    if (!mounted || _completed) return;
    setState(() {
      _mode = _MissionMode.record;
      _isRecording = false;
      _recordingDone = false;
      _recordingPassed = false;
      _speechListening = false;
      _speechManuallyPaused = false;
      _resetSpeechTranscriptState();
      _elapsed = 0;
    });
    await _startRecording();
  }

  Future<void> _pauseSpeechManually() async {
    if (!mounted ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _speechManuallyPaused) {
      return;
    }

    _recordTimer?.cancel();
    _recordTimer = null;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAudioPreparedForListen = false;
    _speechAttemptVersion++;

    if (mounted) {
      setState(() {
        _speechManuallyPaused = true;
        _speechListening = false;
        _commitLastSpeechPartial();
        _recognizedText = _activeTranscript;
      });
    }

    try {
      if (_speech.isListening) {
        _speechStopRequested = true;
        await _speech.cancel();
      }
    } catch (error) {
      debugPrint('[STT] manual pause cancel failed: $error');
    } finally {
      _speechStopRequested = false;
      _clearSpeechStartInFlight(anyOwner: true);
      _MissionSpeechRouter.finishListen(
        this,
        anyOwner: true,
        settle: const Duration(milliseconds: 650),
      );
    }
  }

  Future<void> _resumeSpeechManually() async {
    if (!mounted ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        !_speechManuallyPaused) {
      return;
    }

    setState(() => _speechManuallyPaused = false);
    _resetMissionInactivityWindow(force: true);
    _recordTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += 1);
      if (_elapsed >= _maxSeconds) _finishRecording();
    });
    if (!_sttAvailable) {
      await _initSpeech();
    }
    if (!mounted || _completed || _recordingComplete) return;
    unawaited(_startSpeechSegment());
  }

  void _scheduleSpeechRestart() {
    if (!mounted ||
        !_sttAvailable ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _foregroundInactivityRinging ||
        _speechManuallyPaused) {
      return;
    }
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted ||
          !_isRecording ||
          _completed ||
          _recordingComplete ||
          _foregroundInactivityRinging ||
          _speechManuallyPaused) {
        return;
      }
      unawaited(_startSpeechSegment());
    });
  }

  void _armSpeechListenWatchdog(int attemptVersion) {
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted ||
          attemptVersion != _speechAttemptVersion ||
          !_isRecording ||
          _completed ||
          _recordingComplete ||
          _foregroundInactivityRinging ||
          _speechManuallyPaused ||
          _speech.isListening ||
          _speechListening) {
        return;
      }

      if (_speechListenAttempts >= 5) {
        debugPrint('[STT] listen watchdog gave up');
        return;
      }
      _speechListenAttempts++;
      debugPrint('[STT] listen watchdog retry #$_speechListenAttempts');
      unawaited(_recoverSpeechListenStart(attemptVersion));
    });
  }

  void _armSpeechInputWatchdog(int attemptVersion) {
    _speechInputWatchdogTimer?.cancel();
    final delay = _speechNoInputAttempts == 0
        ? const Duration(milliseconds: 4500)
        : const Duration(milliseconds: 3200);
    _speechInputWatchdogTimer = Timer(delay, () {
      if (!mounted ||
          attemptVersion != _speechAttemptVersion ||
          !_isRecording ||
          _completed ||
          _recordingComplete ||
          _foregroundInactivityRinging ||
          _speechManuallyPaused ||
          _recordingMatchProgress > 0.02) {
        return;
      }

      // 이 워치독의 목적은 '죽은 오디오 엔진' 복구뿐이다. 인식 텍스트가
      // 하나라도 있거나(엔진이 듣고 있음) 사운드레벨 콜백이 방금까지
      // 왔다면(버퍼 수신 중) 세션은 살아 있다 — 재시작하면 취소~재기동
      // 공백(~2초) 동안 사용자의 말이 유실된다. 목표 구절과 2% 일치를
      // 못 채웠다고 살아있는 세션을 죽이던 것이 '느리고 못 받아쓰는'
      // 증상의 원인이었다. 살아있으면 재무장만 하고 지켜본다.
      final soundLevelAt = _lastSpeechSoundLevelAt;
      final engineAlive = _activeTranscript.trim().isNotEmpty ||
          (soundLevelAt != null &&
              DateTime.now().difference(soundLevelAt) < delay);
      if (engineAlive) {
        _armSpeechInputWatchdog(attemptVersion);
        return;
      }

      if (_speechNoInputAttempts >= 4) {
        debugPrint('[STT] input watchdog gave up');
        return;
      }
      _speechNoInputAttempts++;
      debugPrint(
        '[STT] input watchdog retry #$_speechNoInputAttempts '
        'isListening=${_speech.isListening} status=$_speechListening',
      );
      unawaited(_recoverSpeechListenStart(attemptVersion));
    });
  }

  Future<void> _recoverSpeechListenStart(int attemptVersion) async {
    if (!mounted ||
        attemptVersion != _speechAttemptVersion ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _foregroundInactivityRinging ||
        _speechManuallyPaused) {
      return;
    }

    _speechAttemptVersion++;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    try {
      await _speech.cancel();
    } catch (error) {
      debugPrint('[STT] watchdog cancel failed: $error');
    }
    _clearSpeechStartInFlight();
    _MissionSpeechRouter.finishListen(
      this,
      settle: const Duration(milliseconds: 650),
    );
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _foregroundInactivityRinging ||
        _speechManuallyPaused) {
      return;
    }

    await AlarmSoundService.instance.prepareForSpeechRecognition();
    await _initSpeech();
    if (!mounted ||
        !_isRecording ||
        _completed ||
        _recordingComplete ||
        _foregroundInactivityRinging ||
        _speechManuallyPaused) {
      return;
    }
    unawaited(_startSpeechSegment());
  }

  void _finishRecording({bool fromSpeechStatus = false}) {
    if (!mounted) return;
    _recordTimer?.cancel();
    _speechRestartTimer?.cancel();
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAudioPreparedForListen = false;
    if (!fromSpeechStatus && _speech.isListening) {
      _speechStopRequested = true;
      unawaited(
        _speech.stop().whenComplete(() {
          _MissionSpeechRouter.finishListen(this);
          _speechStopRequested = false;
        }),
      );
    }
    _clearSpeechStartInFlight();
    setState(() {
      _isRecording = false;
      _speechListening = false;
      _speechManuallyPaused = false;
      if (_recordingMatches) {
        _recordingPassed = true;
      }
      // _recordingDone marks a finished attempt. _recordingComplete decides
      // whether it actually unlocks Amen based on STT text match.
      _recordingDone = true;
    });
    if (_recordingComplete) {
      _cancelMissionInactivityWindow();
    }
  }

  Future<void> _settleSpeechBeforeCompletion() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    _speechRestartTimer?.cancel();
    _speechRestartTimer = null;
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = null;
    _speechInputWatchdogTimer?.cancel();
    _speechInputWatchdogTimer = null;
    _speechAudioPreparedForListen = false;
    _speechAttemptVersion++;

    _commitLastSpeechPartial();
    _recognizedText = _activeTranscript;

    final shouldWaitForSpeech =
        _speech.isListening ||
        _speechListening ||
        _speechStartInFlight ||
        _speechStopRequested;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (error) {
      debugPrint('[STT] stop before completion failed: $error');
    }
    _MissionSpeechRouter.finishListen(this);
    if (shouldWaitForSpeech) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    try {
      await _speech.cancel();
    } catch (error) {
      debugPrint('[STT] cancel before completion failed: $error');
    }

    _clearSpeechStartInFlight();
    _MissionSpeechRouter.finishListen(this);
    _speechStopRequested = false;
    _speechListening = false;
    _speechManuallyPaused = false;
    _isRecording = false;
  }

  void _carrySpeechProgressToTypedInput() {
    final transcript = _activeTranscript.trim();
    if (transcript.isEmpty) return;

    final transcriptProgress = SpeechMatchUtils.voiceMatchProgress(
      _recordingTargetText,
      transcript,
    );
    final typedProgress = _typingMatchProgress;
    if (transcriptProgress <= typedProgress) return;

    // 말한 진행률만큼 대상의 '입력 가능 문자' 접두로 시드 — 필드 강조와
    // 문자 정렬 채점이 그 지점부터 그대로 이어진다(날 것의 STT 문장을
    // 넣으면 정렬이 어긋나 진행률이 무너진다).
    final seeded = SpeechMatchUtils.typedSeedForProgress(
      _missionDisplayTargetText,
      transcriptProgress,
    );
    _typedController.value = TextEditingValue(
      text: seeded,
      selection: TextSelection.collapsed(offset: seeded.length),
    );
  }

  void _carryTypedProgressToSpeechInput() {
    final typedProgress = _typingMatchProgress;
    if (typedProgress <= 0) return;

    final transcriptProgress = SpeechMatchUtils.voiceMatchProgress(
      _recordingTargetText,
      _activeTranscript,
    );
    if (typedProgress < transcriptProgress) return;

    // 맞힌 분량에 해당하는 원문 접두(공백·부호 포함)로 넘긴다 — 공백 없는
    // 타이핑 원문을 그대로 넣으면 단어 매처가 한 토큰으로 보고 0%가 된다.
    final carried = SpeechMatchUtils.typedProgressTargetPrefix(
      _missionDisplayTargetText,
      _typedController.text,
    );
    if (carried.isEmpty) return;
    _committedTranscript = carried;
    _lastPartial = '';
    _recognizedText = carried;
  }

  void _switchMode(_MissionMode mode) {
    if (_mode == mode) return;
    if (mode == _MissionMode.type) {
      final lockedOffset = _currentMissionScrollOffset();
      _carrySpeechProgressToTypedInput();
      _recordTimer?.cancel();
      _recordTimer = null;
      _speechRestartTimer?.cancel();
      _speechRestartTimer = null;
      _speechListenWatchdogTimer?.cancel();
      _speechListenWatchdogTimer = null;
      _speechInputWatchdogTimer?.cancel();
      _speechInputWatchdogTimer = null;
      _speechAudioPreparedForListen = false;
      if (_speech.isListening) {
        _speechStopRequested = true;
        unawaited(
          _speech.stop().whenComplete(() {
            _MissionSpeechRouter.finishListen(this);
            _speechStopRequested = false;
          }),
        );
      }
      _clearSpeechStartInFlight();
      // Typing tap = user starting the actual mission action — same quiet
      // foreground behavior as _startRecording.
      setState(() {
        _mode = mode;
        _isRecording = false;
        _speechListening = false;
        _speechManuallyPaused = false;
      });
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
      unawaited(_silenceAlarmForMissionAction());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mode != _MissionMode.type) return;
        _typedFocus.requestFocus();
        if (lockedOffset != null) {
          _restoreMissionScrollOffset(lockedOffset);
        }
      });
    } else {
      _carryTypedProgressToSpeechInput();
      setState(() => _mode = mode);
      _typedFocus.unfocus();
      unawaited(_startRecording(preserveTranscript: true));
    }
  }

  Future<void> _onAmen() async {
    if (_completed) return; // 더블탭이 완료 처리를 2회 실행하는 것 방지
    // Mark BEFORE the async call so a racing dispose() takes the completed path.
    _completed = true;
    _missionActionStarted = false;
    _inactivityAlarmRequiresUserResume = false;
    _missionTimeoutTimer?.cancel();
    _missionExitWatchdogArmTimer?.cancel();
    _missionExitWatchdogArmTimer = null;
    _cancelMissionInactivityWindow();
    await _settleSpeechBeforeCompletion();

    if (widget.practiceMode) {
      await AlarmSoundService.instance.stop();
      if (!mounted) return;
      setState(() => _showCompletion = true);
      if (!_isEveningMission) {
        unawaited(_loadCompletionWeather());
      }
      return;
    }

    if (_isEveningMission) {
      await CompletionService.instance.record(
        type: CompletionType.evening,
        prayerRead: true,
        verseRead: true,
      );
      await AlarmPersistenceService.onEveningCompleted();
      if (!mounted) return;
      setState(() => _showCompletion = true);
      return;
    }

    // Android Activity onStop/onDestroy can run during the completion route
    // transition. Stamp native completion before that window can schedule an
    // abandoned-mission retry.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final alarmId = await AlarmSessionService.instance.activeAlarmId();
      await NativeAlarmService.markMorningMissionCompleted(alarmId: alarmId);
      await NativeAlarmService.cancelMorningMissionExitWatchdogs();
    }

    // onMorningCompleted is the ONLY place that cancels the alarm + burst.
    await AlarmPersistenceService.onMorningCompleted(alarmId: _resolvedAlarmId);
    await StreakService.onNormalMorningCompletion();
    if (!mounted) return;
    setState(() => _showCompletion = true);
    unawaited(_loadCompletionWeather());
  }

  Future<void> _finishCompletion() async {
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted();
      return;
    }

    final navigator = Navigator.of(context);
    if (widget.practiceMode) {
      navigator.pop();
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _shareGodMorning() async {
    final text = _buildGodMorningShareText();

    try {
      await _shareChannel.invokeMethod<bool>('shareText', {'text': text});
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localized(ko: '오늘 나눔 내용을 복사했어요.', en: 'Today’s share copied.'),
          ),
        ),
      );
    }
  }

  String _buildGodMorningShareText() {
    final lines = <String>[
      _localizedByContentLanguage(
        ko: '오늘의 God Morning',
        en: 'Today’s God Morning',
        de: 'God Morning heute',
        ru: 'God Morning сегодня',
        es: 'God Morning de hoy',
      ),
      '',
    ];

    if (_showScripture) {
      lines.addAll([
        _localizedByContentLanguage(
          ko: '오늘의 말씀',
          en: 'Today’s Scripture',
          de: 'Heutiger Bibeltext',
          ru: 'Сегодняшнее Писание',
          es: 'Escritura de hoy',
        ),
        _verseText.$1,
        '"${_verseText.$2}"',
        '',
      ]);
    }

    if (_showPrayer) {
      lines.addAll([
        _localizedByContentLanguage(
          ko: '오늘의 기도',
          en: 'Today’s Prayer',
          de: 'Heutiges Gebet',
          ru: 'Сегодняшняя молитва',
          es: 'Oración de hoy',
        ),
        _prayerText,
        '',
      ]);
    }

    lines.addAll([
      _localizedByContentLanguage(
        ko: '말씀과 기도로 아침을 시작하는 기도 알람, God Morning',
        en: 'Start your morning with Scripture, prayer, and a stronger alarm.',
        de: 'Beginne deinen Morgen mit Bibeltext, Gebet und einem stärkeren Wecker.',
        ru: 'Начните утро с Писания, молитвы и сильного будильника.',
        es: 'Comienza la mañana con Escritura, oración y una alarma más fuerte.',
      ),
      'God Morning',
      _appStoreLink,
    ]);

    return lines.join('\n').trim();
  }

  Future<void> _copyGodMorningLink() async {
    await Clipboard.setData(const ClipboardData(text: _appStoreLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localized(ko: '앱 링크를 복사했어요.', en: 'App link copied.')),
      ),
    );
  }

  Future<void> _loadCompletionWeather() async {
    if (kIsWeb) return;
    final enabled = await WeatherPreferencesService.isEnabled();
    final unit = await WeatherPreferencesService.getTemperatureUnit();
    final cached = enabled
        ? await WeatherForecastService.getCachedForecast(unit: unit)
        : null;

    if (!mounted || !_showCompletion) return;
    setState(() {
      _completionWeatherEnabled = enabled;
      _completionWeatherUnit = unit;
      _completionWeather = cached;
      _completionWeatherLoading = enabled && cached == null;
      _completionWeatherError = null;
    });

    if (!enabled) return;

    try {
      final forecast = await WeatherForecastService.getLocalForecast(
        unit: unit,
      );
      if (!mounted || !_showCompletion) return;
      setState(() {
        _completionWeather = forecast;
        _completionWeatherLoading = false;
        _completionWeatherError = null;
      });
    } on WeatherForecastException catch (error) {
      if (!mounted || !_showCompletion) return;
      setState(() {
        _completionWeatherLoading = false;
        _completionWeatherError = error.error;
      });
    } catch (_) {
      if (!mounted || !_showCompletion) return;
      setState(() {
        _completionWeatherLoading = false;
        _completionWeatherError = WeatherForecastError.network;
      });
    }
  }

  String _clockText() {
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Scale by device width so the layout fits a SE-class screen yet feels
  /// generous on a Pro Max. Mid-size phones use 1.0.
  double _scale(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 0.88;
    if (w > 420) return 1.12;
    return 1.0;
  }

  void _handleTypedControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  double? _currentMissionScrollOffset() {
    if (!_missionScrollController.hasClients) return null;
    return _missionScrollController.offset;
  }

  void _restoreMissionScrollOffset(double offset) {
    final generation = _missionUserScrollGeneration;
    void restore() {
      if (!mounted || _mode != _MissionMode.type) return;
      if (generation != _missionUserScrollGeneration) return;
      if (!_missionScrollController.hasClients) return;
      final position = _missionScrollController.position;
      final target = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        _missionScrollController.jumpTo(target.toDouble());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restore();
      Future<void>.delayed(const Duration(milliseconds: 40), restore);
      Future<void>.delayed(const Duration(milliseconds: 120), restore);
    });
  }

  bool _handleMissionScrollNotification(ScrollNotification notification) {
    if (_mode == _MissionMode.type &&
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _missionUserScrollGeneration++;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return PopScope(
      canPop: widget.practiceMode,
      child: Scaffold(
        backgroundColor: _bgColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: _showCompletion
              ? _completionView(s)
              : NotificationListener<ScrollNotification>(
                  onNotification: _handleMissionScrollNotification,
                  child: SingleChildScrollView(
                    controller: _missionScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: EdgeInsets.fromLTRB(22, 12 * s, 22, 24),
                    child: Column(
                      children: [
                        if (widget.practiceMode) ...[
                          _practiceHeader(s),
                          SizedBox(height: 12 * s),
                        ],
                        _clockHeader(s),
                        SizedBox(height: 22 * s),
                        _missionTextBlock(s),
                        SizedBox(height: 24 * s),
                        _modeToggle(s),
                        SizedBox(height: 18 * s),
                        _modeBody(s),
                        SizedBox(height: 10 * s),
                        _missionInactivityNotice(s),
                      ],
                    ),
                  ),
                ),
        ),
        // 아멘은 스크롤 위치와 무관하게 항상 하단에 보인다(저장 버튼과 동일
        // 원칙) — 스크롤 아래 숨어 있으면 누르지 못하는 사용자가 생긴다.
        // 단 타이핑 모드는 예외: 하단 바는 키보드 뒤에 가려지므로 본문
        // 안(입력 필드 아래)의 아멘 버튼이 대신한다.
        bottomNavigationBar: _showCompletion || _mode == _MissionMode.type
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 10 * s, 22, 12),
                  child: _amenButton(s),
                ),
              ),
      ),
    );
  }

  Widget _completionView(double s) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 26 * s, 24, 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.vertical -
              54,
        ),
        child: Column(
          children: [
            SizedBox(height: 18 * s),
            Container(
              width: 74 * s,
              height: 74 * s,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withValues(alpha: 0.35)),
              ),
              child: Icon(
                _isEveningMission
                    ? Icons.nightlight_round
                    : Icons.wb_sunny_outlined,
                color: _accent,
                size: 34 * s,
              ),
            ),
            SizedBox(height: 28 * s),
            Text(
              _isEveningMission
                  ? _localized(ko: '자녀를 축복했어요', en: 'Blessing complete')
                  : _localized(ko: '하나님과 동행하는 하루', en: 'Walk with God today'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30 * s,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 10 * s),
            Text(
              _isEveningMission
                  ? _localized(
                      ko: '오늘 밤도 은혜 안에서 맡깁니다.',
                      en: 'Entrust this night to grace.',
                    )
                  : _localized(
                      ko: '오늘도 은혜 안에서 시작합니다.',
                      en: 'Begin this day in grace.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textMuted,
                fontSize: 14 * s,
                height: 1.4,
              ),
            ),
            if (!_isEveningMission) ...[
              SizedBox(height: 26 * s),
              _completionWeatherCard(s),
            ],
            SizedBox(height: 26 * s),
            SizedBox(
              width: double.infinity,
              height: 56 * s,
              child: ElevatedButton(
                onPressed: _finishCompletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _bgColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: TextStyle(
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  _isEveningMission
                      ? _localized(ko: '완료', en: 'Done')
                      : _localized(ko: '하루 시작하기', en: 'Start the day'),
                ),
              ),
            ),
            if (!_isEveningMission) ...[
              SizedBox(height: 14 * s),
              _completionShareActions(s),
            ],
            if (widget.practiceMode) ...[
              SizedBox(height: 12 * s),
              Text(
                _localized(
                  ko: '연습 완료. 실제 알람은 변경되지 않았어요.',
                  en: 'Practice complete. Your real alarm was not changed.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12 * s),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _completionShareActions(double s) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48 * s,
            child: OutlinedButton.icon(
              onPressed: _shareGodMorning,
              icon: Icon(Icons.ios_share, size: 19 * s),
              label: Text(_localized(ko: '오늘 말씀·기도 나누기', en: 'Share today')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: _accent.withValues(alpha: 0.55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: TextStyle(
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          InkWell(
            onTap: _copyGodMorningLink,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 6 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, color: _accent, size: 16 * s),
                  SizedBox(width: 6 * s),
                  Flexible(
                    child: Text(
                      _appStoreLink,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12 * s,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionWeatherCard(double s) {
    final data = _completionWeather;
    final today = data?.today;
    final hasWeather = _completionWeatherEnabled && data != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18 * s),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasWeather
                    ? _completionWeatherIcon(data.currentWeatherCode)
                    : Icons.cloud_outlined,
                color: _accent,
                size: 24 * s,
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  _localized(ko: '오늘 날씨', en: "Today's weather"),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * s),
          if (!_completionWeatherEnabled) ...[
            Text(
              _localized(
                ko: '지역 날씨를 켜면 오늘 예보가 여기에 표시됩니다.',
                en: 'Turn on local weather to see today here.',
              ),
              style: TextStyle(
                color: _textMuted,
                fontSize: 13 * s,
                height: 1.4,
              ),
            ),
          ] else if (_completionWeatherLoading) ...[
            Row(
              children: [
                SizedBox(
                  width: 18 * s,
                  height: 18 * s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
                SizedBox(width: 10 * s),
                Text(
                  _localized(ko: '날씨를 불러오는 중...', en: 'Loading forecast...'),
                  style: TextStyle(color: _textMuted, fontSize: 13 * s),
                ),
              ],
            ),
          ] else if (_completionWeatherError != null || data == null) ...[
            Text(
              _completionWeatherErrorText(_completionWeatherError),
              style: TextStyle(
                color: _textMuted,
                fontSize: 13 * s,
                height: 1.4,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _completionTemperature(data.currentTemperature),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42 * s,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(width: 14 * s),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 4 * s),
                    child: Text(
                      _completionWeatherCondition(data.currentWeatherCode),
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14 * s,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * s),
            Text(
              [
                _localized(
                  ko: '체감 ${_completionTemperature(data.currentApparentTemperature)}',
                  en: 'Feels ${_completionTemperature(data.currentApparentTemperature)}',
                ),
                _localized(
                  ko: '바람 ${data.currentWindSpeed.round()} ${_completionWeatherUnit.windSpeedLabel}',
                  en: 'Wind ${data.currentWindSpeed.round()} ${_completionWeatherUnit.windSpeedLabel}',
                ),
              ].join(' · '),
              style: TextStyle(
                color: _textMuted,
                fontSize: 12 * s,
                height: 1.4,
              ),
            ),
            if (today != null) ...[
              SizedBox(height: 8 * s),
              Text(
                _localized(
                  ko: '최고 ${_completionTemperature(today.highTemperature)}  최저 ${_completionTemperature(today.lowTemperature)} · 비 ${today.precipitationProbability}%',
                  en: 'H ${_completionTemperature(today.highTemperature)}  L ${_completionTemperature(today.lowTemperature)} · Rain ${today.precipitationProbability}%',
                ),
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12 * s,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _clockHeader(double s) {
    return Text(
      _clockText(),
      style: TextStyle(
        color: Colors.white,
        fontSize: 44 * s,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
      ),
    );
  }

  Widget _practiceHeader(double s) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEveningMission
                    ? _localized(ko: '자녀축복 미리보기', en: 'Blessing preview')
                    : _localized(ko: '미션 연습', en: 'Practice mission'),
                style: TextStyle(
                  color: _accent,
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 3 * s),
              Text(
                _isEveningMission
                    ? _localized(
                        ko: '실제 저녁 알람과 완료 기록은 바뀌지 않아요.',
                        en: 'No real evening alarm or completion record will be changed.',
                      )
                    : _localized(
                        ko: '알람, 재울림, 연속 기록은 바뀌지 않아요.',
                        en: 'No alarm, retry, or streak will be changed.',
                      ),
                style: TextStyle(color: _textMuted, fontSize: 12 * s),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
          color: _textSecondary,
          tooltip: _localized(ko: '닫기', en: 'Close'),
        ),
      ],
    );
  }

  Widget _missionTextBlock(double s) {
    if (_mode == _MissionMode.type) {
      return Column(
        children: [
          if (_showScripture)
            Text(
              _verseText.$1,
              style: TextStyle(
                color: _accent,
                fontSize: 13 * s,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (_showScripture) SizedBox(height: 10 * s),
          InlineMissionTypingField(
            controller: _typedController,
            focusNode: _typedFocus,
            targetText: _missionDisplayTargetText,
            hintText: _typingPlaceholder(),
            textColor: Colors.white,
            mutedTextColor: _textMuted,
            cursorColor: _accent,
            errorColor: _typingMistakeColor,
            backgroundColor: _surface,
            borderColor: _divider,
            scale: s,
            onChanged: (_) {
              _markMissionProgressActivity(
                force: true,
                allowQuietForegroundAlarm: true,
              );
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_showScripture) _verseBlock(s),
        if (_showScripture && _showPrayer) ...[
          SizedBox(height: 18 * s),
          Container(height: 1, color: _divider),
          SizedBox(height: 18 * s),
        ],
        if (_showPrayer) _prayerBlock(s),
      ],
    );
  }

  Widget _prayerBlock(double s) {
    return Column(
      children: [
        Text(
          _prayerText,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 21 * s, height: 1.45),
        ),
      ],
    );
  }

  Widget _verseBlock(double s) {
    return Column(
      children: [
        Text(
          _verseText.$1,
          style: TextStyle(
            color: _accent,
            fontSize: 13 * s,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8 * s),
        Text(
          '"${_verseText.$2}"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18 * s, height: 1.5),
        ),
      ],
    );
  }

  Widget _modeToggle(double s) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab(
            s,
            _MissionMode.record,
            Icons.mic,
            _localized(ko: '음성', en: 'Voice'),
          ),
          _modeTab(
            s,
            _MissionMode.type,
            Icons.keyboard,
            _localized(ko: '타이핑', en: 'Type'),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(double s, _MissionMode mode, IconData icon, String label) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 12 * s),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18 * s,
                color: selected ? _bgColor : _textSecondary,
              ),
              SizedBox(width: 8 * s),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _bgColor : _textSecondary,
                  fontSize: 15 * s,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeBody(double s) {
    return _mode == _MissionMode.record ? _recordBody(s) : _typingBody(s);
  }

  Widget _missionInactivityNotice(double s) {
    final visible =
        !widget.practiceMode &&
        _missionActionStarted &&
        !_completed &&
        !_amenEnabled;
    final text = _foregroundInactivityRinging
        ? (_mode == _MissionMode.record
              ? _localized(
                  ko: '알람을 멈추고 다시 읽으려면 마이크를 탭하세요',
                  en: 'Tap the mic to quiet the alarm and read again',
                )
              : _localized(
                  ko: '한 글자라도 입력하면 알람이 멈춰요',
                  en: 'Type any character to quiet the alarm',
                ))
        : _localized(
            ko: '멈추면 ${_missionInactivityRemainingSeconds}s 뒤 다시 울려요',
            en: 'If you stop, alarm returns in ${_missionInactivityRemainingSeconds}s',
          );

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 18 * s),
        child: Text(
          visible ? text : '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _foregroundInactivityRinging ? _recordRed : _textMuted,
            fontSize: 12 * s,
            height: 1.25,
            fontWeight: _foregroundInactivityRinging
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _recordBody(double s) {
    final transcript = _activeTranscript.trim();
    final hasTranscript = transcript.isNotEmpty;

    return Column(
      children: [
        _listeningIndicator(s),
        SizedBox(height: 12 * s),
        Text(
          _recordLabel(),
          style: TextStyle(color: _textSecondary, fontSize: 14 * s),
        ),
        SizedBox(height: 14 * s),
        AnimatedOpacity(
          opacity: hasTranscript ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 220),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 64 * s),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12 * s),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _divider),
            ),
            child: Text(
              hasTranscript ? transcript : _voiceTranscriptHint(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasTranscript ? Colors.white : _textMuted,
                fontSize: hasTranscript ? 22 * s : 15 * s,
                height: 1.35,
                fontWeight: hasTranscript ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        SizedBox(height: 8 * s),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _completed
                ? null
                : () => unawaited(_restartRecordingAttempt()),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(Icons.refresh, size: 16 * s),
            label: Text(
              _localized(ko: '지우고 다시 읽기', en: 'Clear and reread'),
              style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listeningIndicator(double s) {
    final isComplete = _recordingComplete;
    final progress = isComplete ? 1.0 : _recordingMatchProgress.clamp(0.0, 1.0);
    final size = 88.0 * s;
    final onTap = _recordButtonTapHandler();

    return Semantics(
      button: onTap != null,
      label: _recordButtonAccessibilityLabel(),
      child: ScaleTransition(
        scale: _isRecording && !_speechManuallyPaused
            ? Tween<double>(begin: 1.0, end: 1.06).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              )
            : const AlwaysStoppedAnimation(1.0),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: onTap == null ? 0.02 : 0.06,
                      ),
                      border: Border.all(
                        color: onTap == null
                            ? _divider
                            : Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: onTap == null
                          ? null
                          : [
                              BoxShadow(
                                color: (isComplete ? _accent : _recordRed)
                                    .withValues(alpha: 0.20),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                  ),
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: _divider,
                      valueColor: AlwaysStoppedAnimation(
                        isComplete ? _accent : _recordRed,
                      ),
                    ),
                  ),
                  Container(
                    width: size * 0.83,
                    height: size * 0.83,
                    decoration: BoxDecoration(
                      color: isComplete ? _surface : _recordRed,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isComplete
                            ? Icons.check
                            : (_speechManuallyPaused
                                  ? Icons.mic_off
                                  : (_isRecording
                                        ? Icons.graphic_eq
                                        : Icons.mic_none)),
                        color: Colors.white,
                        size: 34 * s,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _recordButtonTapHandler() {
    if (_completed || _recordingComplete) return null;
    return () => unawaited(_handleRecordButtonTap());
  }

  Future<void> _handleRecordButtonTap() async {
    if (!mounted || _completed || _recordingComplete) return;
    if (_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) {
      await _resumeMissionActionFromInactivity();
      return;
    }
    if (_isRecording) {
      if (_speechManuallyPaused) {
        await _resumeSpeechManually();
        return;
      }
      await _pauseSpeechManually();
      return;
    }
    // 45초 시도 종료·워치독 포기 후의 탭은 '이어 읽기' — 진행률 삭제는
    // '지우고 다시 읽기' 버튼만 한다(탭이 70% 진행률을 날리던 함정 수리).
    if (_recordingDone && _activeTranscript.trim().isNotEmpty) {
      await _startRecording(
        preserveTranscript: true,
        allowQuietForegroundAlarm: true,
      );
      return;
    }
    await _restartRecordingAttempt();
  }

  String _recordButtonAccessibilityLabel() {
    if (_recordingComplete) {
      return _localized(ko: '녹음 완료', en: 'Recording complete');
    }
    if (_foregroundInactivityRinging || _inactivityAlarmRequiresUserResume) {
      return _localized(
        ko: '탭해서 알람을 멈추고 이어 읽기',
        en: 'Tap to quiet the alarm and continue reading',
      );
    }
    if (_isRecording) {
      if (_speechManuallyPaused) {
        return _localized(ko: '녹음 일시정지됨', en: 'Recording paused');
      }
      return _localized(ko: '녹음 중', en: 'Recording');
    }
    return _localized(ko: '탭해서 녹음 시작', en: 'Tap to start recording');
  }

  String _recordLabel() {
    if (_foregroundInactivityRinging) {
      return _localized(
        ko: '멈춰 있어서 알람이 다시 울렸어요',
        en: 'The alarm returned because progress stopped.',
      );
    }
    if (_recordingComplete) {
      return '${_missionConfirmedText()} ✓';
    }
    if (_recordingDone && _recognizedText.trim().isEmpty) {
      if (widget.practiceMode) {
        return _localized(
          ko: '인식된 말씀이 없어요. 지우고 다시 읽어보세요',
          en: 'No words recognized. Clear and read again.',
        );
      }
      return _localized(
        ko: '인식된 말씀이 없어요. 다시 울리면 읽어 주세요',
        en: 'No words recognized. Read when the alarm returns.',
      );
    }
    if (_recordingDone) {
      final percent = (_recordingMatchProgress * 100).round();
      if (widget.practiceMode) {
        return _localized(
          ko: '아직 부족해요 ($percent%). 지우고 다시 읽어보세요',
          en: 'Not enough yet ($percent%). Clear and read again.',
        );
      }
      return _localized(
        ko: '아직 부족해요 ($percent%). 다시 울리면 이어서 읽어 주세요',
        en: 'Not enough yet ($percent%). Continue when the alarm returns.',
      );
    }
    if (_isRecording) {
      if (_speechManuallyPaused) {
        return _localized(
          ko: '일시정지됨 — 마이크를 눌러 계속 읽기',
          en: 'Paused — tap the mic to continue',
        );
      }
      if (!_sttAvailable) {
        return _localized(
          ko: '음성 인식을 사용할 수 없어요. 타이핑으로 진행해 주세요',
          en: 'Voice is unavailable. Use Type to continue.',
        );
      }
      if (!_speechListening && _recognizedText.trim().isEmpty) {
        return _localized(
          ko: '음성 인식 연결 중... 잠시 후 읽어 주세요',
          en: 'Connecting voice... read in a moment',
        );
      }
      final percent = (_recordingMatchProgress * 100).round();
      if (_recognizedText.trim().isEmpty) {
        return _localized(
          ko: '자동으로 듣는 중... 읽어 주세요',
          en: 'Listening automatically... read aloud',
        );
      }
      return _localized(
        ko: '자동으로 듣는 중... $percent%',
        en: 'Listening automatically... $percent%',
      );
    }
    return _sttAvailable
        ? _localized(ko: '음성 인식을 준비 중...', en: 'Preparing voice...')
        : _localized(
            ko: '마이크/음성 인식 권한을 확인해 주세요',
            en: 'Check microphone and speech permissions.',
          );
  }

  String _missionConfirmedText() {
    if (_isEveningMission) {
      return _localized(ko: '축복기도 확인 완료', en: 'Blessing prayer confirmed');
    }
    return switch (_missionContentMode) {
      MissionContentMode.scriptureAndPrayer => _localized(
        ko: '말씀과 기도 확인 완료',
        en: 'Word and prayer confirmed',
      ),
      MissionContentMode.scriptureOnly => _localized(
        ko: '말씀 확인 완료',
        en: 'Scripture confirmed',
      ),
      MissionContentMode.prayerOnly => _localized(
        ko: '기도 확인 완료',
        en: 'Prayer confirmed',
      ),
    };
  }

  String _typingPlaceholder() {
    if (_isEveningMission) {
      return _localized(
        ko: '축복기도를 직접 적어보세요',
        en: 'Type the blessing prayer here',
      );
    }
    return switch (_missionContentMode) {
      MissionContentMode.scriptureAndPrayer => _localized(
        ko: '말씀과 기도를 직접 적어보세요',
        en: 'Type the Word and prayer here',
      ),
      MissionContentMode.scriptureOnly => _localized(
        ko: '말씀을 직접 적어보세요',
        en: 'Type the Scripture here',
      ),
      MissionContentMode.prayerOnly => _localized(
        ko: '기도를 직접 적어보세요',
        en: 'Type the prayer here',
      ),
    };
  }

  String _typingInstruction() {
    if (_isEveningMission) {
      return _localized(
        ko: '축복기도를 그대로 입력해 주세요',
        en: 'Type the blessing prayer as shown',
      );
    }
    return switch (_missionContentMode) {
      MissionContentMode.scriptureAndPrayer => _localized(
        ko: '말씀과 기도를 그대로 입력해 주세요',
        en: 'Type the Word and prayer as shown',
      ),
      MissionContentMode.scriptureOnly => _localized(
        ko: '말씀을 그대로 입력해 주세요',
        en: 'Type the Scripture as shown',
      ),
      MissionContentMode.prayerOnly => _localized(
        ko: '기도를 그대로 입력해 주세요',
        en: 'Type the prayer as shown',
      ),
    };
  }

  String _voiceTranscriptHint() {
    if (!_sttAvailable) {
      return _localized(
        ko: '마이크/음성 인식 권한을 확인해 주세요',
        en: 'Check microphone and speech permissions.',
      );
    }
    return _localized(
      ko: '읽으면 여기에 받아써져요',
      en: 'Speak aloud and your words will appear here.',
    );
  }

  String _localized({required String ko, required String en}) {
    return _useKoreanContent ? ko : en;
  }

  String _localizedByContentLanguage({
    required String ko,
    required String en,
    required String de,
    required String ru,
    required String es,
  }) {
    return switch (_contentLanguageCode) {
      'ko' => ko,
      'de' => de,
      'ru' => ru,
      'es' => es,
      _ => en,
    };
  }

  String _completionTemperature(double value) {
    return '${value.round()}${_completionWeatherUnit.symbol}';
  }

  String _completionWeatherErrorText(WeatherForecastError? error) {
    if (error == WeatherForecastError.denied ||
        error == WeatherForecastError.deniedForever) {
      return _localized(
        ko: '날씨를 보려면 위치 권한이 필요합니다.',
        en: 'Location permission is needed for weather.',
      );
    }
    if (error == WeatherForecastError.locationServicesDisabled) {
      return _localized(
        ko: '날씨를 보려면 위치 서비스를 켜 주세요.',
        en: 'Turn on Location Services to show weather.',
      );
    }
    return _localized(
      ko: '지금은 날씨를 불러올 수 없습니다.',
      en: 'Weather is unavailable right now.',
    );
  }

  IconData _completionWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
    if (code == 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.foggy;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_outlined;
    }
    if (code >= 71 && code <= 77) return Icons.ac_unit_outlined;
    if (code >= 85 && code <= 86) return Icons.cloudy_snowing;
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_queue;
  }

  String _completionWeatherCondition(int code) {
    if (code == 0) return _localized(ko: '맑음', en: 'Clear');
    if (code == 1 || code == 2) {
      return _localized(ko: '구름 조금', en: 'Partly cloudy');
    }
    if (code == 3) return _localized(ko: '흐림', en: 'Cloudy');
    if (code == 45 || code == 48) return _localized(ko: '안개', en: 'Fog');
    if (code >= 51 && code <= 67) return _localized(ko: '이슬비', en: 'Drizzle');
    if (code >= 71 && code <= 77) return _localized(ko: '눈', en: 'Snow');
    if (code >= 80 && code <= 82) {
      return _localized(ko: '소나기', en: 'Rain showers');
    }
    if (code >= 85 && code <= 86) {
      return _localized(ko: '눈 소나기', en: 'Snow showers');
    }
    if (code >= 95) return _localized(ko: '뇌우', en: 'Thunderstorm');
    return _localized(ko: '날씨', en: 'Weather');
  }

  Widget _typingBody(double s) {
    final progress = _typingMatchProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final targetPercent = (_missionPassThreshold * 100).round();
    final counterColor = _typingDone ? _accent : _textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _typingDone ? _missionConfirmedText() : _typingInstruction(),
              style: TextStyle(color: counterColor, fontSize: 13 * s),
            ),
            Text(
              '$percent% / $targetPercent%',
              style: TextStyle(color: counterColor, fontSize: 13 * s),
            ),
          ],
        ),
        SizedBox(height: 6 * s),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: _divider,
            valueColor: AlwaysStoppedAnimation(
              _typingDone ? _accent : _textSecondary,
            ),
          ),
        ),
        SizedBox(height: 8 * s),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _completed || _typedController.text.isEmpty
                ? null
                : () {
                    _typedController.clear();
                    _typedFocus.requestFocus();
                  },
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(Icons.refresh, size: 16 * s),
            label: Text(
              _localized(ko: '지우고 다시 쓰기', en: 'Clear and type again'),
              style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // 아멘은 본문 안에도 둔다 — 하단 고정 바(bottomNavigationBar)는
        // 키보드가 올라오면 그 '뒤'에 가려져 타이핑 중에는 보이지 않는다.
        SizedBox(height: 10 * s),
        _amenButton(s),
      ],
    );
  }

  Widget _amenButton(double s) {
    final enabled = _amenEnabled;
    return SizedBox(
      width: double.infinity,
      height: 58 * s,
      child: ElevatedButton(
        onPressed: enabled ? _onAmen : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.white : _surface,
          foregroundColor: enabled ? _bgColor : const Color(0xFF666666),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w600),
        ),
        child: Text(_localized(ko: '아멘', en: 'Amen')),
      ),
    );
  }
}
