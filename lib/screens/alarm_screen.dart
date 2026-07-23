import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../theme/app_theme.dart';
import '../data/daily_content.dart';
import '../data/weekday_themed_content.dart';
import '../l10n/app_localizations.dart';
import '../services/ai_daily_content_service.dart';
import '../models/prayer_intensity.dart';
import '../services/alarm_persistence_service.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/app_launch_state.dart';
import '../services/completion_service.dart';
import '../services/locale_service.dart';
import '../services/prayer_preferences_service.dart';
import '../services/streak_service.dart';
import '../utils/speech_match_utils.dart';
import '../widgets/emergency_exit_sheet.dart';
import '../widgets/listening_typing_field.dart';
import '../widgets/live_speech_transcript_panel.dart';
import '../widgets/prayer_step_nav_bar.dart';

// 화면 상태: 알람 울림 → 녹음(듣기) → 성공
enum AppState { ringing, listening, success }

enum _PrayerInputMode { voice, keyboard }

/// Morning alarm reading order: verse → morning prayer.
enum _AlarmReadingStep { aiPrayer, verse }

/// 아침 알람 3화면 (울림 / 녹음 / 성공)
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.alarmHour,
    required this.alarmMinute,
    this.isLiveAlarm = false,
    this.onCompleted,
  });

  final int alarmHour;
  final int alarmMinute;

  /// true면 실제 알람으로 열린 화면 (소리 재생·완료 전 종료 불가)
  final bool isLiveAlarm;

  /// 아침 기도 완료 후 호출 (앱 잠금 해제)
  final VoidCallback? onCompleted;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppState _state = AppState.ringing;

  late stt.SpeechToText _speech;
  late Future<void> _speechInitFuture;
  String? _localeId;

  late AnimationController _pulseController;

  // 기본 콘텐츠 (기도제목 없을 때)
  final DailyContentItem _defaultContent = DailyContent.forToday();

  // Always-loaded weekday / AI content
  ThemedDailyContent? _themedContent;
  bool _contentLoading = true;

  int _stepIndex = 0;
  int _furthestStepIndex = 0;
  late PageController _stepPageController;
  bool _advancingStep = false;
  PrayerIntensity _intensity = PrayerIntensity.normal;
  bool _completedViaEmergency = false;
  bool _speechListening = false;
  Timer? _ringingSoundWatchdog;
  String _stepTranscript = '';
  String _lastPartial = '';
  bool _resumingSpeech = false;
  _PrayerInputMode _inputMode = _PrayerInputMode.voice;
  late TextEditingController _typedInputController;
  late FocusNode _typingFocusNode;
  final Map<int, String> _typedTextByStep = {};

  String get _aiPrayer =>
      _themedContent?.content.prayer ?? _defaultContent.prayer;

  String get _todayVerse =>
      _themedContent?.content.verse ?? _defaultContent.verse;

  String get _todayVerseRef =>
      _themedContent?.content.reference ?? _defaultContent.reference;

  List<_AlarmReadingStep> get _readingSteps {
    final steps = <_AlarmReadingStep>[
      _AlarmReadingStep.verse,
      _AlarmReadingStep.aiPrayer,
    ];
    return steps;
  }

  String _stepName(_AlarmReadingStep step, AppLocalizations l10n) {
    return switch (step) {
      _AlarmReadingStep.aiPrayer => l10n.stepMorningPrayer,
      _AlarmReadingStep.verse => l10n.stepScripture,
    };
  }

  String _stepHeaderLabelAt(int index, AppLocalizations l10n) {
    switch (_stepAt(index)) {
      case _AlarmReadingStep.aiPrayer:
        if (_themedContent != null) {
          final ai = _themedContent!.isAiGenerated ? ' · AI' : '';
          return '${_themedContent!.weekdayLabel.toUpperCase()} · '
              '${_themedContent!.themeName.toUpperCase()}$ai';
        }
        return l10n.todaysPrayer.toUpperCase();
      case _AlarmReadingStep.verse:
        return l10n.todaysWord.toUpperCase();
    }
  }

  String get _currentStepText => _stepTextAt(_stepIndex);

  _AlarmReadingStep _stepAt(int index) => _readingSteps[index];

  String _stepTextAt(int index) {
    switch (_stepAt(index)) {
      case _AlarmReadingStep.aiPrayer:
        return _aiPrayer;
      case _AlarmReadingStep.verse:
        return '$_todayVerse $_todayVerseRef';
    }
  }

  String _stepLabelAt(int index, AppLocalizations l10n) =>
      _stepName(_stepAt(index), l10n);

  bool _isVerseStepAt(int index) => _stepAt(index) == _AlarmReadingStep.verse;

  String _stepProgressLabelFor(AppLocalizations l10n, int index) => l10n
      .stepOfTotal(index + 1, _readingSteps.length, _stepLabelAt(index, l10n));

  String get _timeLabel =>
      AlarmPreferences.formatTime(widget.alarmHour, widget.alarmMinute);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _speechInitFuture = _initSpeech();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _typedInputController = TextEditingController();
    _typingFocusNode = FocusNode();
    _typedInputController.addListener(_onTypedInputChanged);
    _stepPageController = PageController();
    _loadTodayContent();
    unawaited(_loadIntensity());
    if (widget.isLiveAlarm) {
      AlarmSessionService.instance.setBlockingUiVisible(true);
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.ringing,
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

  static const _liveRingBeforePrayer = Duration(milliseconds: 600);

  Future<void> _beginLiveAlarmFlow() async {
    if (!widget.isLiveAlarm || !mounted) return;

    AlarmSessionService.instance.setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
    await _syncAlarmSound();

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (_contentLoading && mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await Future<void>.delayed(_liveRingBeforePrayer);
    if (!mounted || !_isLockedLiveAlarm || _state == AppState.success) return;
    await _startListening();
  }

  bool get _isLockedLiveAlarm => widget.isLiveAlarm;

  /// 울림(ringing)일 때만 알람 소리 — 듣기/성공 화면에서는 무음
  bool get _shouldRingAlarm => _state == AppState.ringing;

  Future<void> _syncAlarmSound() async {
    if (_shouldRingAlarm) {
      await AlarmSoundService.instance.start();
    } else {
      await AlarmSoundService.instance.stop();
    }
  }

  Future<void> _loadTodayContent() async {
    try {
      final themed = await AiDailyContentService.instance.getTodayContent();

      if (mounted) {
        setState(() {
          _themedContent = themed;
          _contentLoading = false;
        });
      }
    } catch (e) {
      debugPrint('기도제목 로드 실패: $e');
      if (mounted) {
        setState(() {
          _themedContent = ThemedDailyContent(
            content: WeekdayThemedContent.fallbackFor(DateTime.now().weekday),
            themeName: WeekdayThemedContent.themeFor(
              DateTime.now().weekday,
            ).name,
            weekdayLabel: WeekdayThemedContent.themeFor(
              DateTime.now().weekday,
            ).label,
            isAiGenerated: false,
          );
          _contentLoading = false;
        });
      }
    }
  }

  Future<void> _initSpeech() async {
    final permitted = await _speech.hasPermission;
    debugPrint('STT hasPermission: $permitted');

    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        debugPrint('STT error: $error');
        if (mounted) _showError(error.errorMsg);
        _scheduleSpeechResume();
      },
      debugLogging: kDebugMode,
    );

    if (!available) {
      debugPrint('STT initialize failed — check mic/speech in Settings');
      return;
    }
    if (!mounted) return;

    final locales = await _speech.locales();
    final lang = LocaleService.instance.locale.languageCode;
    final prefix = SpeechMatchUtils.speechLocalePrefix('', appLang: lang);
    final matched = locales.where((l) => l.localeId.startsWith(prefix));
    setState(() {
      _localeId = matched.isNotEmpty
          ? matched.first.localeId
          : (locales.isNotEmpty ? locales.first.localeId : 'en_US');
    });
  }

  Future<String> _resolveSpeechLocale(String text) async {
    if (!_speech.isAvailable) await _initSpeech();
    return SpeechMatchUtils.resolveLocaleId(
      fetchLocales: _speech.locales,
      text: text,
      appLang: LocaleService.instance.locale.languageCode,
    );
  }

  void _onSpeechStatus(String status) {
    debugPrint('STT status: $status');
    if (mounted) {
      setState(() => _speechListening = status == 'listening');
    }
    if (_state != AppState.listening ||
        _advancingStep ||
        _inputMode != _PrayerInputMode.voice) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      _scheduleSpeechResume();
    }
  }

  void _scheduleSpeechResume() {
    if (_state != AppState.listening ||
        _advancingStep ||
        _resumingSpeech ||
        _inputMode != _PrayerInputMode.voice) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 350), () async {
      if (!mounted || _state != AppState.listening || _advancingStep) return;
      if (_speech.isListening) return;
      _resumingSpeech = true;
      try {
        await _beginListeningSession();
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
    setState(() {});
  }

  String get _activeTranscript {
    if (_inputMode == _PrayerInputMode.keyboard) {
      return _typedInputController.text;
    }
    return SpeechMatchUtils.combineTranscript(_stepTranscript, _lastPartial);
  }

  void _applySpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _stepTranscript = SpeechMatchUtils.appendFinalTranscript(
        _stepTranscript,
        result.recognizedWords,
      );
      _lastPartial = '';
    } else {
      _lastPartial = result.recognizedWords;
    }
    setState(() {});
    _checkMatch(_activeTranscript);
  }

  Future<void> _beginListeningSession() async {
    await AlarmSoundService.instance.prepareForSpeechRecognition();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _localeId = await _resolveSpeechLocale(_currentStepText);
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
  }

  Future<void> _restartListeningSession() async {
    await _speech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _state != AppState.listening) return;
    if (_inputMode != _PrayerInputMode.voice) return;
    await _beginListeningSession();
  }

  Future<void> _setInputMode(_PrayerInputMode mode) async {
    if (_inputMode == mode) return;

    setState(() {
      _inputMode = mode;
    });

    if (mode == _PrayerInputMode.keyboard) {
      await _speech.stop();
      setState(() => _speechListening = false);
      _stepTranscript = '';
      _lastPartial = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _typingFocusNode.requestFocus();
      });
      return;
    }

    _resetStepTranscript();
    if (_state == AppState.listening && _speech.isAvailable) {
      await _beginListeningSession();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLockedLiveAlarm || _state == AppState.success) return;
    if (state == AppLifecycleState.resumed && _state == AppState.ringing) {
      _syncAlarmSound();
    }
  }

  @override
  void dispose() {
    _ringingSoundWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_isLockedLiveAlarm) {
      AlarmSessionService.instance.setBlockingUiVisible(false);
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

  Future<void> _startListening() async {
    if (_state == AppState.listening || _state == AppState.success) return;

    _ringingSoundWatchdog?.cancel();
    AlarmSessionService.instance.setLiveAlarmUiPhase(
      LiveAlarmUiPhase.listening,
    );
    unawaited(AlarmSoundService.instance.stop());
    if (_isLockedLiveAlarm) {
      unawaited(
        AlarmPersistenceService.onPrayerScreenOpened(
          AlarmPersistenceService.slotMorning,
        ),
      );
    }

    await _speechInitFuture;
    if (!_speech.isAvailable) {
      await _initSpeech();
    }

    final speechReady = _speech.isAvailable;
    if (!speechReady && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).switchedToTypeMode),
        ),
      );
    }

    setState(() {
      _state = AppState.listening;
      _stepIndex = 0;
      _furthestStepIndex = 0;
      _inputMode = speechReady
          ? _PrayerInputMode.voice
          : _PrayerInputMode.keyboard;
      _typedTextByStep.clear();
      _speechListening = false;
    });
    _typedInputController.clear();
    if (_stepPageController.hasClients) {
      _stepPageController.jumpToPage(0);
    }
    _resetStepTranscript();
    await AlarmSoundService.instance.stop();

    if (_inputMode == _PrayerInputMode.voice) {
      await _beginListeningSession();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _typingFocusNode.requestFocus();
      });
    }
  }

  void _stopListening() {
    _speech.stop();
  }

  void _checkMatch([String? spokenOverride]) {
    if (_advancingStep || !mounted) return;
    setState(() {});
  }

  bool _canNavigateToStep(int index) {
    if (index < 0 || index >= _readingSteps.length) return false;
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
  }

  Future<void> _applyStepChange(int index, {bool viaPageView = false}) async {
    if (index == _stepIndex) return;
    _saveTypedTextForCurrentStep();
    _stepTranscript = '';
    _lastPartial = '';
    setState(() {
      _stepIndex = index;
      if (index > _furthestStepIndex) _furthestStepIndex = index;
    });
    _loadTypedTextForStep(index);
    if (_inputMode == _PrayerInputMode.voice && _state == AppState.listening) {
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
      stepCount: _readingSteps.length,
      stepLabel: _stepProgressLabelFor(l10n, _stepIndex),
      canGoBack: _stepIndex > 0,
      canGoForward: !_isLastStep && _canAdvanceCurrentStep,
      onBack: () => unawaited(_goToPreviousStep()),
      onForward: () => unawaited(_goToNextStep()),
    );
  }

  Future<void> _loadIntensity() async {
    final intensity = await PrayerPreferencesService.getIntensity();
    if (mounted) setState(() => _intensity = intensity);
  }

  Future<void> _openEmergencyExit() async {
    if (!await PrayerPreferencesService.canUseEmergency()) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).emergencyNotAvailable);
      return;
    }
    await EmergencyExitSheet.show(
      context,
      kind: EmergencyExitKind.morning,
      onConfirmed: () => unawaited(_onEmergencyExit()),
    );
  }

  Future<void> _onEmergencyExit() async {
    _stopListening();
    await AlarmSoundService.instance.stop();
    await StreakService.onEmergencyCompletion();
    if (_isLockedLiveAlarm) {
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.success,
      );
      await AlarmPersistenceService.onMorningCompleted();
    }
    if (mounted) {
      setState(() {
        _completedViaEmergency = true;
        _state = AppState.success;
      });
    }
  }

  bool get _canAdvanceCurrentStep => SpeechMatchUtils.canAdvance(
    _currentStepText,
    _activeTranscript,
    threshold: _intensity.matchThreshold,
  );

  bool get _isLastStep => _stepIndex >= _readingSteps.length - 1;

  Future<void> _advanceReadingStep() async {
    if (_advancingStep || _isLastStep) return;
    if (!_canAdvanceCurrentStep) return;
    _advancingStep = true;

    try {
      if (!mounted) return;
      _resetStepTranscript();
      setState(() {
        _stepIndex++;
        _furthestStepIndex = _stepIndex;
      });

      if (_stepPageController.hasClients) {
        await _stepPageController.animateToPage(
          _stepIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }

      _loadTypedTextForStep(_stepIndex);
      if (_inputMode == _PrayerInputMode.voice) {
        await _restartListeningSession();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _typingFocusNode.requestFocus();
        });
      }
    } finally {
      _advancingStep = false;
    }
  }

  /// Last step only — stops alarm and completes morning prayer.
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

  /// 음성 인식 성공 → 알람 소리 멈춤 + 성공 화면
  Future<void> _onAlarmSuccess() async {
    _stopListening();
    await AlarmSoundService.instance.stop();

    try {
      await CompletionService.instance.record(
        type: CompletionType.morning,
        prayerRead: true,
        verseRead: true,
      );
    } catch (e) {
      debugPrint('알람 완료 기록 실패: $e');
    }

    if (mounted) setState(() => _state = AppState.success);
    if (_isLockedLiveAlarm) {
      AlarmSessionService.instance.setLiveAlarmUiPhase(
        LiveAlarmUiPhase.success,
      );
      await AlarmPersistenceService.onMorningCompleted();
    }
    await StreakService.onNormalMorningCompletion();
  }

  String _successMessage(AppLocalizations l10n) {
    return l10n.successMeansOfGraceComplete;
  }

  /// 취소 시 알람 울림 화면으로 + 소리 다시 재생
  Future<void> _cancelListening() async {
    _stopListening();
    _advancingStep = false;
    _resetStepTranscript();
    setState(() {
      _state = AppState.ringing;
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
    if (_state == AppState.listening) {
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLockedLiveAlarm || _state == AppState.success,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isLockedLiveAlarm && _state != AppState.success) {
          await _syncAlarmSound();
          return;
        }
        if (_state == AppState.listening) {
          await _cancelListening();
        }
      },
      child: switch (_state) {
        AppState.ringing => _buildRingingScreen(),
        AppState.listening => _buildListeningScreen(),
        AppState.success => _buildSuccessScreen(),
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
                  Icons.notifications_active,
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
                l10n.timeToMeetLord,
                style: const TextStyle(fontSize: 18, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.morningPrayerVoiceTypeHint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.45,
                ),
              ),
              if (_isLockedLiveAlarm) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.morningAlarmMustComplete,
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
                    l10n.stopWithPrayerAndWord,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => unawaited(_openEmergencyExit()),
                  child: Text(
                    l10n.emergencyButton,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.35,
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
    final verse = _isVerseStepAt(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stepHeaderLabelAt(index, l10n),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: listenLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          verse ? _todayVerse : _stepTextAt(index),
          style: const TextStyle(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            height: 1.55,
            color: listenText,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (verse) ...[
          const SizedBox(height: 6),
          Text(
            _todayVerseRef,
            style: const TextStyle(
              fontSize: 12,
              color: listenLabel,
              letterSpacing: 0.5,
            ),
          ),
        ],
        if (index > 0) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(index, (i) {
              final label = _stepName(_readingSteps[i], l10n);
              return Chip(
                label: Text('✓ $label', style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1A1A),
                side: const BorderSide(color: Color(0xFF333333)),
                labelStyle: const TextStyle(color: listenLabel),
                visualDensity: VisualDensity.compact,
              );
            }),
          ),
        ],
      ],
    );
  }

  /// 타이핑 모드: 입력창 위에 항상 기도문·말씀 표시 (키보드가 올라와도 안 가려짐).
  Widget _buildKeyboardPrayerReference(AppLocalizations l10n) {
    const listenLabel = Color(0xFFB0B0B0);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 160),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.readAloudToContinue,
              style: const TextStyle(
                fontSize: 11,
                color: listenLabel,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildStepContentColumn(l10n, _stepIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceStepPage(AppLocalizations l10n, int index) {
    final showLiveTranscript =
        index == _stepIndex &&
        _state == AppState.listening &&
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
              transcript: _activeTranscript,
              labelText: l10n.liveTranscriptLabel,
              hintText: l10n.liveTranscriptHint,
              isListening: _speechListening,
            ),
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
            if (_contentLoading)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 12, 32, 0),
                child: LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Color(0xFF333333),
                ),
              )
            else ...[
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
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildKeyboardPrayerReference(l10n),
                            ListeningTypingField(
                              controller: _typedInputController,
                              focusNode: _typingFocusNode,
                              hintText: l10n.typePrayerHint,
                              echoLabel: l10n.typedEchoLabel,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      )
                    : PageView.builder(
                        controller: _stepPageController,
                        onPageChanged: (index) =>
                            unawaited(_onStepPageChanged(index)),
                        itemCount: _readingSteps.length,
                        itemBuilder: (context, index) =>
                            _buildVoiceStepPage(l10n, index),
                      ),
              ),
            ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_speechListening) ...[
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          FadeTransition(
                            opacity: Tween<double>(
                              begin: 0.4,
                              end: 1.0,
                            ).animate(_pulseController),
                            child: Icon(
                              Icons.mic,
                              color: _speechListening
                                  ? const Color(0xFFE53935)
                                  : listenText,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      _inputMode == _PrayerInputMode.keyboard
                          ? '${l10n.typingProgress} ($progressPercent%)'
                          : _speechListening
                          ? '${l10n.recordingInProgress} ($progressPercent%)'
                          : '${l10n.listening} ($progressPercent%)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: listenLabel),
                    ),
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
                          l10n.morningAlarmMustComplete,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: listenLabel,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                    ],
                    TextButton(
                      onPressed: () => unawaited(_openEmergencyExit()),
                      child: Text(
                        l10n.emergencyButton,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: listenLabel,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
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
                Icons.wb_sunny_outlined,
                color: AppTheme.accent,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.hallelujah,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _completedViaEmergency
                    ? l10n.emergencySuccessMessage
                    : _successMessage(l10n),
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
