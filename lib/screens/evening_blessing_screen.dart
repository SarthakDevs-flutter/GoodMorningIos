import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/evening_blessing_content.dart';
import '../l10n/app_localizations.dart';
import '../models/prayer_intensity.dart';
import '../services/alarm_persistence_service.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/app_launch_state.dart';
import '../services/completion_service.dart';
import '../services/locale_service.dart';
import '../services/native_alarm_service.dart';
import '../theme/app_theme.dart';
import '../services/prayer_preferences_service.dart';
import '../utils/speech_match_utils.dart';
import '../widgets/live_speech_transcript_panel.dart';
import '../widgets/prayer_step_nav_bar.dart';

enum EveningAppState { ringing, listening, success }

enum _PrayerInputMode { voice, keyboard }

/// 저녁 자녀 축복기도 알람 (아침 알람과 동일한 듣기 UX)
class EveningBlessingScreen extends StatefulWidget {
  const EveningBlessingScreen({
    super.key,
    required this.alarmHour,
    required this.alarmMinute,
    this.isLiveAlarm = false,
    this.onCompleted,
  });

  final int alarmHour;
  final int alarmMinute;
  final bool isLiveAlarm;
  final VoidCallback? onCompleted;

  @override
  State<EveningBlessingScreen> createState() => _EveningBlessingScreenState();
}

class _EveningBlessingScreenState extends State<EveningBlessingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _recordRed = Color(0xFFE53935);
  static const _textMuted = Color(0xFF888888);
  static const _missionActivityRefreshInterval = Duration(seconds: 10);
  static const _missionInactivityGraceDuration = Duration(seconds: 15);

  EveningAppState _state = EveningAppState.ringing;

  late stt.SpeechToText _speech;
  Future<void>? _speechInitFuture;
  bool _sttAvailable = false;
  String _recognizedText = '';
  String? _localeId;
  Timer? _ringingSoundWatchdog;
  String _stepTranscript = '';
  String _lastPartial = '';
  bool _resumingSpeech = false;
  bool _advancingStep = false;
  bool _speechListening = false;
  bool _speechStartInFlight = false;
  bool _listeningFlowStarted = false;
  bool _missionActionStarted = false;
  DateTime? _lastMissionQuietRefreshAt;
  DateTime? _missionInactivityDeadline;
  int _missionInactivityRemainingSeconds = 0;
  bool _foregroundInactivityRinging = false;
  Timer? _missionInactivityTimer;
  Timer? _foregroundAlarmWatchdogTimer;
  Timer? _speechResumeTimer;
  Timer? _speechListenWatchdogTimer;
  int _speechListenAttempts = 0;
  static const _stepCount = 1;
  int _stepIndex = 0;
  int _furthestStepIndex = 0;
  late PageController _stepPageController;
  final Map<int, String> _typedTextByStep = {};
  _PrayerInputMode _inputMode = _PrayerInputMode.voice;
  late TextEditingController _typedInputController;
  late FocusNode _typingFocusNode;
  PrayerIntensity _intensity = PrayerIntensity.normal;

  late AnimationController _pulseController;

  // 앱 언어의 아론의 축복 본문(민수기 6:24-26, 공개도메인 번역본).
  String _stepTextAt(int index) => EveningBlessingContent.prayerFor(
    LocaleService.instance.locale.languageCode,
  );

  String get _blessingReference => EveningBlessingContent.referenceFor(
    LocaleService.instance.locale.languageCode,
  );

  String get _currentStepText => _stepTextAt(_stepIndex);

  String _stepLabelAt(int index, AppLocalizations l10n) =>
      l10n.stepAaronBlessing;

  String _stepProgressLabel(AppLocalizations l10n) => l10n.stepOfTotal(
    _stepIndex + 1,
    _stepCount,
    _stepLabelAt(_stepIndex, l10n),
  );

  bool get _isLastStep => _stepIndex >= _stepCount - 1;

  String get _timeLabel =>
      AlarmPreferences.formatTime(widget.alarmHour, widget.alarmMinute);

  bool get _isLockedLiveAlarm => widget.isLiveAlarm;

  bool get _shouldRingAlarm => _state == EveningAppState.ringing;

  bool get _canAdvanceCurrentStep => SpeechMatchUtils.canAdvance(
    _currentStepText,
    _activeTranscript,
    threshold: _intensity.matchThreshold,
  );

  double get _typingMatchProgress => SpeechMatchUtils.matchProgress(
    _currentStepText,
    _typedInputController.text,
  );

  bool get _typingDone => SpeechMatchUtils.canAdvance(
    _currentStepText,
    _typedInputController.text,
    threshold: _intensity.matchThreshold,
  );

  Future<void> _loadIntensity() async {
    final intensity = await PrayerPreferencesService.getIntensity();
    if (mounted) setState(() => _intensity = intensity);
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLiveAlarm) {
      unawaited(NativeAlarmService.stopAllActiveSounds());
      unawaited(AlarmSoundService.instance.stop());
      unawaited(NativeAlarmService.clearDeliveredNotifications());
      unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
      unawaited(AlarmNotificationService.instance.cancelEveningMainNotification());
      unawaited(AlarmNotificationService.instance.cancelEveningRingCarpet());
    }
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _stepPageController = PageController();
    _typedInputController = TextEditingController();
    _typingFocusNode = FocusNode();
    _typedInputController.addListener(_onTypedInputChanged);
    unawaited(_loadIntensity());
    if (widget.isLiveAlarm) {
      _state = EveningAppState.listening;
      AlarmSessionService.instance.setBlockingUiVisible(true);
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_scheduleLiveAlarmFlow());
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_shouldRingAlarm) _syncAlarmSound();
      });
    }
    _ringingSoundWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_shouldRingAlarm) {
        AlarmSoundService.instance.ensurePlaying();
      }
    });
  }

  Future<void> _scheduleLiveAlarmFlow() async {
    if (!AppLaunchState.bootComplete) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted || !widget.isLiveAlarm) return;
    await _beginLiveAlarmFlow();
  }

  Future<void> _beginLiveAlarmFlow() async {
    if (!widget.isLiveAlarm || !mounted) return;

    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    unawaited(NativeAlarmService.pauseEveningRetriesForMission());
    unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
    await AlarmSoundService.instance.stop();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_isLockedLiveAlarm || _state == EveningAppState.success) {
      return;
    }
    await _startListening(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLockedLiveAlarm || _state == EveningAppState.success) return;

    if (state == AppLifecycleState.resumed) {
      if (_missionActionStarted) {
        _markMissionProgressActivity(force: true);
      } else if (_state == EveningAppState.ringing) {
        _syncAlarmSound();
      }
      return;
    }

    if (_missionActionStarted &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state == AppLifecycleState.hidden)) {
      _missionInactivityTimer?.cancel();
      _missionInactivityTimer = null;
      _foregroundInactivityRinging = false;
      unawaited(AlarmSoundService.instance.stop());
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.ringing,
      );
      unawaited(NativeAlarmService.resumeEveningRetryAfterMissionAbandoned());
    }
  }

  Future<void> _syncAlarmSound() async {
    if (_shouldRingAlarm) {
      await AlarmSoundService.instance.start();
    } else {
      await AlarmSoundService.instance.stop();
    }
  }

  Future<void> _initSpeech() async {
    try {
      final permitted = await _speech.hasPermission;
      debugPrint('[EVENING STT] hasPermission=$permitted');

      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('[EVENING STT] error=$error');
          if (mounted) _showError(error.errorMsg);
          _scheduleSpeechResume();
        },
        debugLogging: kDebugMode,
      );

      if (!mounted) return;
      setState(() => _sttAvailable = available);
      debugPrint('[EVENING STT] initialize available=$available');

      if (!available) {
        debugPrint('[EVENING STT] initialize failed — check Settings');
        _speechInitFuture = null;
        return;
      }

      final locales = await _speech.locales();
      final lang = LocaleService.instance.locale.languageCode;
      final prefix = SpeechMatchUtils.speechLocalePrefix('', appLang: lang);
      final matched = locales.where((l) => l.localeId.startsWith(prefix));
      if (!mounted) return;
      setState(() {
        _localeId = matched.isNotEmpty
            ? matched.first.localeId
            : (locales.isNotEmpty ? locales.first.localeId : 'en_US');
      });
    } catch (e) {
      debugPrint('[EVENING STT] initialize threw: $e');
      if (mounted) setState(() => _sttAvailable = false);
      _speechInitFuture = null;
    }
  }

  Future<void> _ensureSpeechInitialized({bool force = false}) {
    if (_sttAvailable && !force) return Future<void>.value();
    if (force) {
      _speechInitFuture = null;
      _sttAvailable = false;
    }
    return _speechInitFuture ??= _initSpeech();
  }

  Future<String> _resolveSpeechLocale(String text) async {
    if (!_sttAvailable) await _ensureSpeechInitialized();
    return SpeechMatchUtils.resolveLocaleId(
      fetchLocales: _speech.locales,
      text: text,
      appLang: LocaleService.instance.locale.languageCode,
    );
  }

  void _onSpeechStatus(String status) {
    debugPrint('[EVENING STT] status=$status');
    if (mounted) {
      setState(() => _speechListening = status == 'listening');
    }
    if (_state != EveningAppState.listening ||
        _advancingStep ||
        _foregroundInactivityRinging ||
        _inputMode != _PrayerInputMode.voice) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      _scheduleSpeechResume();
    }
  }

  void _scheduleSpeechResume({
    Duration delay = const Duration(milliseconds: 500),
    bool forceInit = false,
  }) {
    if (_state != EveningAppState.listening ||
        _advancingStep ||
        _resumingSpeech ||
        _foregroundInactivityRinging ||
        _inputMode != _PrayerInputMode.voice) {
      return;
    }
    _speechResumeTimer?.cancel();
    _speechResumeTimer = Timer(delay, () async {
      if (!mounted ||
          _state != EveningAppState.listening ||
          _advancingStep ||
          _foregroundInactivityRinging) {
        return;
      }
      if (_speech.isListening) return;
      _resumingSpeech = true;
      try {
        await _beginListeningSession(forceInit: forceInit);
      } finally {
        _resumingSpeech = false;
      }
    });
  }

  void _resetStepTranscript() {
    _stepTranscript = '';
    _lastPartial = '';
  }

  void _onTypedInputChanged() {
    if (_inputMode != _PrayerInputMode.keyboard || !mounted) return;
    setState(() => _recognizedText = _typedInputController.text);
    if (_typedInputController.text.trim().isNotEmpty) {
      _markMissionActionStarted();
      _markMissionProgressActivity(force: true);
    }
  }

  String get _activeTranscript {
    if (_inputMode == _PrayerInputMode.keyboard) {
      return _typedInputController.text;
    }
    return SpeechMatchUtils.combineTranscript(_stepTranscript, _lastPartial);
  }

  void _applySpeechResult(SpeechRecognitionResult result) {
    if (_foregroundInactivityRinging) {
      return;
    }
    final beforeProgress = SpeechMatchUtils.matchProgress(
      _currentStepText,
      _activeTranscript,
    );
    if (result.finalResult) {
      _stepTranscript = SpeechMatchUtils.appendFinalTranscript(
        _stepTranscript,
        result.recognizedWords,
      );
      _lastPartial = '';
    } else {
      _lastPartial = result.recognizedWords;
    }
    debugPrint('[EVENING STT] ${result.recognizedWords}');
    setState(() => _recognizedText = _activeTranscript);
    final afterProgress = SpeechMatchUtils.matchProgress(
      _currentStepText,
      _activeTranscript,
    );
    if (_activeTranscript.trim().isNotEmpty) {
      _markMissionActionStarted();
      if (!_foregroundInactivityRinging &&
          (afterProgress > beforeProgress || _canAdvanceCurrentStep)) {
        _markMissionProgressActivity(force: true);
      }
    }
    _checkMatch(_activeTranscript);
  }

  void _markMissionActionStarted() {
    if (!_isLockedLiveAlarm || _state == EveningAppState.success) {
      return;
    }
    if (_missionActionStarted) return;
    _missionActionStarted = true;
    _lastMissionQuietRefreshAt = null;
    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    unawaited(_extendMissionQuietWindow(stopCurrentSound: true));
    _resetMissionInactivityWindow(force: true);
  }

  Future<void> _extendMissionQuietWindow({
    required bool stopCurrentSound,
  }) async {
    if (_isLockedLiveAlarm) {
      await NativeAlarmService.pauseEveningRetriesForMission();
    }
    if (stopCurrentSound) {
      await AlarmSoundService.instance.stop();
    }
  }

  void _markMissionProgressActivity({bool force = false}) {
    if (!mounted ||
        !_isLockedLiveAlarm ||
        _state == EveningAppState.success ||
        !_missionActionStarted) {
      return;
    }
    if (_foregroundInactivityRinging) {
      return;
    }
    if (_canAdvanceCurrentStep) {
      _cancelMissionInactivityWindow();
      return;
    }

    final wasRinging = _foregroundInactivityRinging;
    _resetMissionInactivityWindow(force: force);

    final now = DateTime.now();
    final lastRefresh = _lastMissionQuietRefreshAt;
    if (!force &&
        lastRefresh != null &&
        now.difference(lastRefresh) < _missionActivityRefreshInterval) {
      return;
    }

    _lastMissionQuietRefreshAt = now;
    unawaited(NativeAlarmService.cancelMorningMissionExitWatchdogs());
    unawaited(_extendMissionQuietWindow(stopCurrentSound: wasRinging));
  }

  void _resetMissionInactivityWindow({bool force = false}) {
    if (!mounted ||
        !_isLockedLiveAlarm ||
        _state == EveningAppState.success ||
        !_missionActionStarted ||
        _canAdvanceCurrentStep) {
      _cancelMissionInactivityWindow();
      return;
    }

    _missionInactivityDeadline = DateTime.now().add(
      _missionInactivityGraceDuration,
    );
    _missionInactivityRemainingSeconds =
        _missionInactivityGraceDuration.inSeconds;

    if (_foregroundInactivityRinging) {
      _foregroundInactivityRinging = false;
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.listening,
      );
      unawaited(AlarmSoundService.instance.stop());
      if (_inputMode == _PrayerInputMode.voice && !_speech.isListening) {
        _scheduleSpeechResume();
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
      _foregroundAlarmWatchdogTimer?.cancel();
      _foregroundAlarmWatchdogTimer = null;
      unawaited(AlarmSoundService.instance.stop());
    }
  }

  void _tickMissionInactivityWindow() {
    if (!mounted ||
        !_isLockedLiveAlarm ||
        _state == EveningAppState.success ||
        !_missionActionStarted ||
        _canAdvanceCurrentStep) {
      _cancelMissionInactivityWindow();
      if (mounted) setState(() {});
      return;
    }

    final deadline = _missionInactivityDeadline;
    if (deadline == null) return;

    final remaining = deadline.difference(DateTime.now()).inSeconds + 1;
    if (remaining <= 0) {
      _onMissionInactivityExpired();
      return;
    }

    if (remaining != _missionInactivityRemainingSeconds) {
      setState(() => _missionInactivityRemainingSeconds = remaining);
    }
  }

  void _onMissionInactivityExpired() {
    if (!mounted ||
        !_isLockedLiveAlarm ||
        _state == EveningAppState.success ||
        !_missionActionStarted ||
        _canAdvanceCurrentStep) {
      _cancelMissionInactivityWindow();
      return;
    }
    if (_foregroundInactivityRinging) return;

    debugPrint('[EVENING] inactive for 15s — foreground alarm resumes');
    _foregroundInactivityRinging = true;
    _missionInactivityTimer?.cancel();
    _missionInactivityTimer = null;
    _missionInactivityRemainingSeconds = 0;
    AlarmSessionService.instance.setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
    if (_inputMode == _PrayerInputMode.voice && _speech.isListening) {
      unawaited(_speech.cancel());
    }
    setState(() {});
    unawaited(_startForegroundInactivityAlarm());
  }

  Future<void> _resumeMissionActionFromInactivity() async {
    if (_state == EveningAppState.success || !_missionActionStarted) return;
    await _stopForegroundInactivityAlarm();
    _resetMissionInactivityWindow(force: true);
    if (_inputMode == _PrayerInputMode.voice && !_speech.isListening) {
      await _beginListeningSession(forceInit: true);
    }
  }

  Future<void> _startForegroundInactivityAlarm() async {
    _foregroundAlarmWatchdogTimer?.cancel();
    await AlarmSoundService.instance.start();
    _foregroundAlarmWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (
      _,
    ) {
      if (_foregroundInactivityRinging &&
          _state == EveningAppState.listening &&
          !_canAdvanceCurrentStep) {
        unawaited(AlarmSoundService.instance.ensurePlaying());
      }
    });
  }

  Future<void> _stopForegroundInactivityAlarm() async {
    if (!_foregroundInactivityRinging) return;
    _foregroundInactivityRinging = false;
    _foregroundAlarmWatchdogTimer?.cancel();
    _foregroundAlarmWatchdogTimer = null;
    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    await AlarmSoundService.instance.stop();
    if (_inputMode == _PrayerInputMode.voice && _speech.isListening) {
      await _speech.cancel();
    }
    if (mounted) setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _beginListeningSession({bool forceInit = false}) async {
    if (_speechStartInFlight ||
        _foregroundInactivityRinging ||
        _inputMode != _PrayerInputMode.voice ||
        _state != EveningAppState.listening ||
        _speech.isListening) {
      return;
    }

    _speechStartInFlight = true;
    try {
      if (!_sttAvailable || forceInit) {
        await _ensureSpeechInitialized(force: forceInit);
      }
      if (!mounted || !_sttAvailable) {
        debugPrint('[EVENING STT] listen skipped — STT unavailable');
        return;
      }
      await AlarmSoundService.instance.prepareForSpeechRecognition();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted ||
          _foregroundInactivityRinging ||
          _inputMode != _PrayerInputMode.voice ||
          _state != EveningAppState.listening) {
        return;
      }

      _localeId = await _resolveSpeechLocale(_currentStepText);
      if (!mounted || _speech.isListening) return;

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _applySpeechResult(result);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: SpeechMatchUtils.listenFor,
          pauseFor: SpeechMatchUtils.pauseFor,
          localeId: _localeId ?? 'en_US',
        ),
      );
      debugPrint('[EVENING STT] listen started locale=$_localeId');
      _speechListenAttempts = 0;
      _armSpeechListenWatchdog();
    } catch (e) {
      debugPrint('STT listen failed: $e');
      _scheduleSpeechResume(forceInit: true);
    } finally {
      _speechStartInFlight = false;
    }
  }

  void _armSpeechListenWatchdog() {
    _speechListenWatchdogTimer?.cancel();
    _speechListenWatchdogTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted ||
          _state != EveningAppState.listening ||
          _foregroundInactivityRinging ||
          _inputMode != _PrayerInputMode.voice ||
          _speech.isListening) {
        return;
      }
      if (_speechListenAttempts >= 5) {
        debugPrint('[EVENING STT] listen watchdog gave up');
        return;
      }
      _speechListenAttempts++;
      debugPrint('[EVENING STT] listen watchdog retry #$_speechListenAttempts');
      _scheduleSpeechResume(forceInit: true);
    });
  }

  Future<void> _restartListeningSession() async {
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _state != EveningAppState.listening) return;
    if (_inputMode != _PrayerInputMode.voice) return;
    if (_foregroundInactivityRinging) return;
    await _beginListeningSession();
  }

  Future<void> _setInputMode(_PrayerInputMode mode) async {
    if (_inputMode == mode) return;

    setState(() {
      _inputMode = mode;
    });

    if (mode == _PrayerInputMode.keyboard) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _speechListening = false);
      _stepTranscript = '';
      _lastPartial = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _typingFocusNode.requestFocus();
      });
      return;
    }

    _resetStepTranscript();
    if (_state == EveningAppState.listening && _speech.isAvailable) {
      await _beginListeningSession();
    }
  }

  @override
  void dispose() {
    _ringingSoundWatchdog?.cancel();
    _missionInactivityTimer?.cancel();
    _foregroundAlarmWatchdogTimer?.cancel();
    _speechResumeTimer?.cancel();
    _speechListenWatchdogTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.isLiveAlarm) {
      AlarmSessionService.instance.setBlockingUiVisible(false);
      if (_state != EveningAppState.success && _missionActionStarted) {
        unawaited(NativeAlarmService.resumeEveningRetryAfterMissionAbandoned());
      }
    }
    unawaited(AlarmSoundService.instance.stop());
    _stepPageController.dispose();
    _typedInputController.removeListener(_onTypedInputChanged);
    _typedInputController.dispose();
    _typingFocusNode.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening({bool force = false}) async {
    if (_state == EveningAppState.success ||
        _listeningFlowStarted ||
        (!force && _state == EveningAppState.listening)) {
      return;
    }
    _listeningFlowStarted = true;

    _ringingSoundWatchdog?.cancel();
    _cancelMissionInactivityWindow();
    _missionActionStarted = false;
    _lastMissionQuietRefreshAt = null;
    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    unawaited(AlarmSoundService.instance.stop());
    if (_isLockedLiveAlarm) {
      unawaited(
        AlarmPersistenceService.onPrayerScreenOpened(
          AlarmPersistenceService.slotEvening,
        ),
      );
    }

    await _ensureSpeechInitialized(force: true);

    final speechReady = _sttAvailable;
    if (!speechReady && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localized(
              ko: '마이크/음성 인식 권한을 확인해 주세요.',
              en: 'Please check microphone and speech recognition permissions.',
            ),
          ),
        ),
      );
    }

    setState(() {
      _state = EveningAppState.listening;
      _recognizedText = '';
      _stepIndex = 0;
      _furthestStepIndex = 0;
      _inputMode = _PrayerInputMode.voice;
      _typedTextByStep.clear();
      _speechListening = false;
    });
    _typedInputController.clear();
    if (_stepPageController.hasClients) {
      _stepPageController.jumpToPage(0);
    }
    _resetStepTranscript();
    await AlarmSoundService.instance.stop();

    if (speechReady) {
      await _beginListeningSession();
    }
    _markMissionActionStarted();
  }

  void _stopListening() {
    _speech.stop();
  }

  void _checkMatch([String? spokenOverride]) {
    if (_advancingStep || !mounted) return;
    setState(() {});
  }

  bool _canNavigateToStep(int index) {
    if (index < 0 || index >= _stepCount) return false;
    if (index <= _furthestStepIndex) return true;
    if (index == _stepIndex + 1 && _canAdvanceCurrentStep) return true;
    return false;
  }

  void _saveTypedTextForCurrentStep() {
    if (_inputMode == _PrayerInputMode.keyboard) {
      _typedTextByStep[_stepIndex] = _typedInputController.text;
    }
  }

  void _loadTypedTextForStep(int index) {
    final saved = _typedTextByStep[index] ?? '';
    _typedInputController.text = saved;
    if (_inputMode == _PrayerInputMode.keyboard) {
      _recognizedText = saved;
    }
  }

  Future<void> _applyStepChange(int index, {bool viaPageView = false}) async {
    if (index == _stepIndex) return;
    _saveTypedTextForCurrentStep();
    _stepTranscript = '';
    _lastPartial = '';
    setState(() {
      _stepIndex = index;
      _recognizedText = '';
      if (index > _furthestStepIndex) _furthestStepIndex = index;
    });
    _loadTypedTextForStep(index);
    if (_inputMode == _PrayerInputMode.voice &&
        _state == EveningAppState.listening) {
      await _restartListeningSession();
    }
    if (!viaPageView && _stepPageController.hasClients) {
      await _stepPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
    if (_inputMode == _PrayerInputMode.keyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _typingFocusNode.requestFocus();
      });
    }
  }

  Future<void> _onStepPageChanged(int index) async {
    if (index == _stepIndex) return;
    if (!_canNavigateToStep(index)) {
      if (_stepPageController.hasClients) {
        await _stepPageController.animateToPage(
          _stepIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    await _applyStepChange(index, viaPageView: true);
  }

  Future<void> _goToPreviousStep() async {
    if (_stepIndex <= 0) return;
    await _applyStepChange(_stepIndex - 1);
  }

  Future<void> _goToNextStep() async {
    if (_isLastStep || !_canAdvanceCurrentStep) return;
    await _applyStepChange(_stepIndex + 1);
  }

  Widget _buildStepNavBar(AppLocalizations l10n) {
    return PrayerStepNavBar(
      stepIndex: _stepIndex,
      stepCount: _stepCount,
      stepLabel: _stepProgressLabel(l10n),
      canGoBack: _stepIndex > 0,
      canGoForward: !_isLastStep && _canAdvanceCurrentStep,
      onBack: () => unawaited(_goToPreviousStep()),
      onForward: () => unawaited(_goToNextStep()),
    );
  }

  Future<void> _advanceReadingStep() async {
    if (_advancingStep || _isLastStep) return;
    if (!_canAdvanceCurrentStep) return;
    _advancingStep = true;
    try {
      await _applyStepChange(_stepIndex + 1);
    } finally {
      _advancingStep = false;
    }
  }

  Future<void> _finishWithAmen() async {
    if (_advancingStep || !_isLastStep) return;
    if (!_canAdvanceCurrentStep) return;
    _advancingStep = true;
    try {
      await _onAlarmSuccess();
    } finally {
      _advancingStep = false;
    }
  }

  Future<void> _onAlarmSuccess() async {
    _stopListening();
    _missionActionStarted = false;
    _cancelMissionInactivityWindow();
    await AlarmSoundService.instance.stop();

    try {
      await CompletionService.instance.record(
        type: CompletionType.evening,
        prayerRead: true,
        verseRead: true,
      );
    } catch (e) {
      debugPrint('저녁 완료 기록 실패: $e');
    }

    if (mounted) setState(() => _state = EveningAppState.success);
    if (_isLockedLiveAlarm) {
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.success,
      );
      await AlarmPersistenceService.onEveningCompleted();
    }
  }

  Future<void> _cancelListening() async {
    _stopListening();
    _advancingStep = false;
    _listeningFlowStarted = false;
    _missionActionStarted = false;
    _lastMissionQuietRefreshAt = null;
    _cancelMissionInactivityWindow();
    _resetStepTranscript();
    setState(() {
      _state = EveningAppState.ringing;
      _recognizedText = '';
      _stepIndex = 0;
      _inputMode = _PrayerInputMode.voice;
    });
    await _syncAlarmSound();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exitPreview() async {
    if (_isLockedLiveAlarm) return;
    if (_state == EveningAppState.listening) {
      await _cancelListening();
    }
    await AlarmSoundService.instance.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildPreviewExitBar(AppLocalizations l10n) {
    if (_isLockedLiveAlarm) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => unawaited(_exitPreview()),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: AppTheme.textMuted,
        ),
        label: Text(
          l10n.backToMain,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  String _localized({required String ko, required String en}) {
    return LocaleService.instance.locale.languageCode == 'ko' ? ko : en;
  }

  Widget _missionInactivityNotice() {
    final visible =
        _missionActionStarted &&
        _state == EveningAppState.listening &&
        !_canAdvanceCurrentStep;
    final text = _foregroundInactivityRinging
        ? (_inputMode == _PrayerInputMode.voice
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
        constraints: const BoxConstraints(minHeight: 18),
        child: Text(
          visible ? text : '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _foregroundInactivityRinging ? _recordRed : _textMuted,
            fontSize: 12,
            height: 1.25,
            fontWeight: _foregroundInactivityRinging
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLockedLiveAlarm || _state == EveningAppState.success,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isLockedLiveAlarm && _state != EveningAppState.success) {
          await _syncAlarmSound();
          return;
        }
        if (_state == EveningAppState.listening) {
          await _cancelListening();
        }
      },
      child: switch (_state) {
        EveningAppState.ringing => _buildRingingScreen(),
        EveningAppState.listening => _buildListeningScreen(),
        EveningAppState.success => _buildSuccessScreen(),
      },
    );
  }

  Widget _buildRingingScreen() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewExitBar(l10n),
              const Spacer(),
              FadeTransition(
                opacity: Tween<double>(
                  begin: 0.4,
                  end: 1.0,
                ).animate(_pulseController),
                child: const Icon(
                  Icons.nightlight_round,
                  color: AppTheme.text,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _timeLabel,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  color: AppTheme.text,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.blessBeforeRest,
                style: const TextStyle(fontSize: 18, color: AppTheme.textMuted),
              ),
              if (_isLockedLiveAlarm) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.eveningAlarmMustComplete,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.accent,
                    height: 1.45,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.text,
                    foregroundColor: AppTheme.bg,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _startListening,
                  child: Text(
                    l10n.blessWithPrayer,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContentColumn(AppLocalizations l10n, int index) {
    const listenText = Colors.white;
    const listenLabel = Color(0xFFB0B0B0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stepLabelAt(index, l10n).toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: listenLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _stepTextAt(index),
          style: TextStyle(
            fontSize: index == 0 ? 20 : 16,
            fontStyle: index == 0 ? FontStyle.italic : FontStyle.normal,
            height: 1.55,
            color: listenText,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_blessingReference · '
          '${EveningBlessingContent.translationLabelFor(LocaleService.instance.locale.languageCode)}',
          style: const TextStyle(
            fontSize: 12,
            color: listenLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceStepPage(AppLocalizations l10n, int index) {
    final showLiveTranscript =
        index == _stepIndex &&
        _state == EveningAppState.listening &&
        _inputMode == _PrayerInputMode.voice;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepContentColumn(l10n, index),
          if (showLiveTranscript)
            LiveSpeechTranscriptPanel(
              transcript: _recognizedText.trim().isEmpty
                  ? _activeTranscript
                  : _recognizedText,
              labelText: l10n.liveTranscriptLabel,
              hintText: l10n.liveTranscriptHint,
              isListening: _speechListening,
            ),
        ],
      ),
    );
  }

  Widget _buildKeyboardStepPage(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepContentColumn(l10n, _stepIndex),
          const SizedBox(height: 20),
          _typingBody(l10n),
        ],
      ),
    );
  }

  Widget _buildInputModeBar(AppLocalizations l10n) {
    const listenBg = Color(0xFF000000);
    const listenText = Colors.white;

    return SegmentedButton<_PrayerInputMode>(
      segments: [
        ButtonSegment(
          value: _PrayerInputMode.voice,
          icon: const Icon(Icons.mic, size: 18),
          label: Text(l10n.inputModeVoice),
        ),
        ButtonSegment(
          value: _PrayerInputMode.keyboard,
          icon: const Icon(Icons.keyboard, size: 18),
          label: Text(l10n.inputModeKeyboard),
        ),
      ],
      selected: {_inputMode},
      onSelectionChanged: (selected) =>
          unawaited(_setInputMode(selected.first)),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return listenBg;
          return listenText;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return listenText;
          return const Color(0xFF1A1A1A);
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: Color(0xFF333333)),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _typingBody(AppLocalizations l10n) {
    final progress = _typingMatchProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final counterColor = _typingDone ? AppTheme.accent : _textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: CupertinoTextField(
            controller: _typedInputController,
            focusNode: _typingFocusNode,
            maxLines: 6,
            minLines: 4,
            autocorrect: true,
            keyboardAppearance: Brightness.dark,
            placeholder: _localized(
              ko: '축복기도를 직접 적어보세요',
              en: 'Type the blessing prayer here',
            ),
            placeholderStyle: const TextStyle(color: _textMuted, fontSize: 15),
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 16,
              height: 1.5,
            ),
            decoration: const BoxDecoration(),
            cursorColor: AppTheme.accent,
            onChanged: (_) {
              setState(() {});
              _markMissionProgressActivity(force: true);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _typingDone
                  ? _localized(
                      ko: '축복기도 확인 완료',
                      en: 'Blessing prayer confirmed',
                    )
                  : _localized(
                      ko: '축복기도를 그대로 입력해 주세요',
                      en: 'Type the blessing prayer as shown',
                    ),
              style: TextStyle(color: counterColor, fontSize: 13),
            ),
            Text(
              '$percent% / 80%',
              style: TextStyle(color: counterColor, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              _typingDone ? AppTheme.accent : const Color(0xFFB0B0B0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListeningScreen() {
    final l10n = AppLocalizations.of(context);
    const listenBg = Color(0xFF000000);
    const listenText = Colors.white;
    const listenLabel = Color(0xFFB0B0B0);
    final progressPercent =
        (SpeechMatchUtils.matchProgress(_currentStepText, _activeTranscript) *
                100)
            .round();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: listenBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: _buildPreviewExitBar(l10n),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _buildStepNavBar(l10n),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: _buildInputModeBar(l10n),
            ),
            Expanded(
              child: _inputMode == _PrayerInputMode.keyboard
                  ? _buildKeyboardStepPage(l10n)
                  : PageView.builder(
                      controller: _stepPageController,
                      onPageChanged: (index) =>
                          unawaited(_onStepPageChanged(index)),
                      itemCount: _stepCount,
                      itemBuilder: (context, index) =>
                          _buildVoiceStepPage(l10n, index),
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
                decoration: const BoxDecoration(
                  color: listenBg,
                  border: Border(top: BorderSide(color: Color(0xFF222222))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_inputMode != _PrayerInputMode.keyboard) ...[
                      GestureDetector(
                        onTap: _foregroundInactivityRinging
                            ? () => unawaited(
                                _resumeMissionActionFromInactivity(),
                              )
                            : null,
                        child: FadeTransition(
                          opacity: Tween<double>(
                            begin: 0.4,
                            end: 1.0,
                          ).animate(_pulseController),
                          child: const Icon(
                            Icons.mic,
                            color: _recordRed,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_inputMode != _PrayerInputMode.keyboard)
                      Text(
                        '${l10n.listening} ($progressPercent%)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: listenLabel,
                        ),
                      ),
                    const SizedBox(height: 6),
                    _missionInactivityNotice(),
                    const SizedBox(height: 12),
                    if (!_isLastStep)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_advancingStep || !_canAdvanceCurrentStep)
                              ? null
                              : _advanceReadingStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: listenText,
                            foregroundColor: listenBg,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.continueToNextStep,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_isLastStep)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_advancingStep || !_canAdvanceCurrentStep)
                              ? null
                              : _finishWithAmen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: listenText,
                            foregroundColor: listenBg,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.amen,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (!keyboardOpen) ...[
                      const SizedBox(height: 8),
                      if (!_isLockedLiveAlarm)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _cancelListening,
                            child: Text(
                              l10n.cancelAlarmResumes,
                              style: const TextStyle(
                                color: listenLabel,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          l10n.eveningAlarmMustComplete,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: listenLabel,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.nightlight_round,
                color: AppTheme.accent,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.goodnightTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.successEveningRest,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.text,
                    foregroundColor: AppTheme.bg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (_isLockedLiveAlarm) {
                      AlarmSessionService.instance.setBlockingUiVisible(false);
                      if (widget.onCompleted != null) {
                        widget.onCompleted!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    l10n.amen,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
