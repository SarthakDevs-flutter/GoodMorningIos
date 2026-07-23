import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../navigation/app_page_route.dart';
import '../navigator_key.dart';
import '../l10n/app_localizations.dart';
import '../models/mission_content_mode.dart';
import '../models/scripture_plan.dart';
import '../theme/app_theme.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_store.dart';
import '../services/native_alarm_service.dart';
import '../services/locale_service.dart';
import '../services/weather_forecast_service.dart';
import '../services/weather_preferences_service.dart';
import 'alarm_list_screen.dart';
import 'app_launch_gate.dart';
import 'evening_blessing_setup_screen.dart';
import 'premium_screen.dart';
import 'streak_calendar_screen.dart';
import '../widgets/alarm_sound_settings_section.dart';
import '../widgets/streak_card.dart';
import '../services/prayer_preferences_service.dart';
import 'simple_morning_mission_screen.dart';

/// 앱 홈 화면 — MVP는 아침 알람에 집중. 저녁 축복은 업데이트 후보로 보관.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.enableStartupSideEffects = true,
    this.refreshSignal = 0,
    this.onOpenAlarms,
    this.onOpenCalendar,
    this.onOpenSettings,
  });

  final bool enableStartupSideEffects;

  /// 값이 바뀌면 홈이 설정·알람·날씨 상태를 다시 읽는다(탭 복귀용).
  final int refreshSignal;

  /// 탭 셸 안에서는 push 대신 탭 전환으로 이동한다.
  final VoidCallback? onOpenAlarms;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _morningHour = AlarmPreferences.defaultHour;
  int _morningMinute = AlarmPreferences.defaultMinute;
  bool _morningEnabled = false;
  int _eveningHour = AlarmPreferences.defaultEveningHour;
  int _eveningMinute = AlarmPreferences.defaultEveningMinute;
  bool _eveningEnabled = false;

  bool _notificationsEnabled = true;
  bool _weatherEnabled = false;
  WeatherTemperatureUnit _weatherUnit = WeatherTemperatureUnit.fahrenheit;
  bool _loadingWeather = false;
  WeatherForecast? _weatherForecast;
  WeatherForecastError? _weatherError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    if (!kIsWeb && widget.enableStartupSideEffects) {
      unawaited(PrayerPreferencesService.ensureFirstUseDate());
      unawaited(SimpleMorningMissionScreen.prewarmSpeechRecognition());
      AlarmScheduleHelper.ensureScheduled();
      _maybeOpenMissionFromAlarmKit();
    }
  }

  // If the user stopped an AlarmKit alarm, OpenMissionFromAlarmIntent set a
  // pending-mission flag + opened the app. Consume it and route into the
  // matching mission.
  void _maybeOpenMissionFromAlarmKit() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final pending = await NativeAlarmService.consumePendingMission();
      final kind = pending?.kind;
      if (kind != null && mounted) {
        final routeName = ModalRoute.of(context)?.settings.name;
        final alreadyMorning =
            routeName == '/morning-alarm' || routeName == '/morning-ringing';
        final alreadyEvening =
            routeName == '/evening-alarm' || routeName == '/evening-ringing';
        final phase = AlarmSessionService.instance.liveAlarmUiPhase;
        final canReplaceCompletedMorning =
            kind == NativeAlarmKind.morning &&
            (alreadyMorning ||
                AlarmSessionService.instance.isBlockingUiVisible) &&
            phase == LiveAlarmUiPhase.success;
        if ((kind == NativeAlarmKind.morning && alreadyMorning) ||
            (kind == NativeAlarmKind.evening && alreadyEvening) ||
            AlarmSessionService.instance.isBlockingUiVisible) {
          if (canReplaceCompletedMorning) {
            debugPrint(
              '[ALARMKIT] replacing completed morning route with next mission',
            );
          } else {
            debugPrint(
              '[ALARMKIT] mission already visible; skip duplicate push',
            );
            return;
          }
        }
        if (kind == NativeAlarmKind.morning &&
            await AlarmSessionService.instance.isAlarmCompletedToday(
              pending?.alarmId,
            )) {
          debugPrint('[ALARMKIT] pending morning alarm already completed');
          return;
        }
        debugPrint(
          '[ALARMKIT] pending ${kind.name} mission flag → push mission',
        );
        AlarmSessionService.instance
          ..setBlockingUiVisible(true)
          ..setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
        if (kind == NativeAlarmKind.evening) {
          await AlarmSessionService.instance.activateEveningAlarmSession();
        } else {
          await AlarmSessionService.instance.activateMorningAlarmSession(
            alarmId: pending?.alarmId,
          );
        }
        if (!mounted) return;
        final route = liveAlarmPageRoute<void>(
          settings: RouteSettings(
            name: kind == NativeAlarmKind.evening
                ? '/evening-alarm'
                : '/morning-alarm',
          ),
          builder: (_) => kind == NativeAlarmKind.evening
              ? SimpleMorningMissionScreen(
                  kind: MissionKind.evening,
                  onCompleted: () {
                    AlarmSessionService.instance.setBlockingUiVisible(false);
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppLaunchGate(),
                      ),
                      (_) => false,
                    );
                  },
                )
              : SimpleMorningMissionScreen(
                  alarmId: pending?.alarmId,
                  onCompleted: () {
                    AlarmSessionService.instance.setBlockingUiVisible(false);
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppLaunchGate(),
                      ),
                      (_) => false,
                    );
                  },
                ),
        );
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (canReplaceCompletedMorning) {
          navigator.pushAndRemoveUntil(route, (route) => route.isFirst);
        } else {
          navigator.push(route);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadSettings();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        widget.enableStartupSideEffects) {
      _maybeOpenMissionFromAlarmKit();
      _loadSettings();
      AlarmScheduleHelper.ensureScheduled();
    }
  }

  Future<void> _loadSettings() async {
    // 멀티 알람: 홈 카드에는 알람 목록에서 다음에 실제로 울릴 시간을 보여 준다.
    final alarms = await AlarmStore.loadAlarms();
    final nextMorning = AlarmStore.nextOccurrence(alarms, DateTime.now());
    final morningHour = nextMorning?.hour ?? await AlarmPreferences.getHour();
    final morningMinute =
        nextMorning?.minute ?? await AlarmPreferences.getMinute();
    final morningEnabled = await AlarmPreferences.isEnabled();
    final eveningHour = await AlarmPreferences.getEveningHour();
    final eveningMinute = await AlarmPreferences.getEveningMinute();
    final eveningEnabled = await AlarmPreferences.isEveningEnabled();
    final weatherEnabled =
        !kIsWeb && await WeatherPreferencesService.isEnabled();
    final weatherUnit = !kIsWeb
        ? await WeatherPreferencesService.getTemperatureUnit()
        : WeatherTemperatureUnit.fahrenheit;
    final cachedWeather = weatherEnabled
        ? await WeatherForecastService.getCachedForecast(unit: weatherUnit)
        : null;

    var notificationsEnabled = true;
    if (!kIsWeb) {
      notificationsEnabled = await AlarmNotificationService.instance
          .hasPermissions();
    }

    if (mounted) {
      setState(() {
        _morningHour = morningHour;
        _morningMinute = morningMinute;
        _morningEnabled = morningEnabled;
        _eveningHour = eveningHour;
        _eveningMinute = eveningMinute;
        _eveningEnabled = eveningEnabled;
        _notificationsEnabled = notificationsEnabled;
        _weatherEnabled = weatherEnabled;
        _weatherUnit = weatherUnit;
        _weatherForecast = weatherEnabled ? cachedWeather : null;
      });
    }
    if (weatherEnabled) {
      unawaited(_loadWeatherForecast(unit: weatherUnit));
    }
  }

  Future<void> _loadWeatherForecast({
    bool forceRefresh = false,
    WeatherTemperatureUnit? unit,
  }) async {
    if (kIsWeb || _loadingWeather) return;
    final enabled = await WeatherPreferencesService.isEnabled();
    if (!enabled) return;
    final weatherUnit =
        unit ?? await WeatherPreferencesService.getTemperatureUnit();

    if (mounted) {
      setState(() {
        _weatherEnabled = true;
        _weatherUnit = weatherUnit;
        if (forceRefresh) {
          _weatherForecast = null;
        }
        _loadingWeather = true;
        _weatherError = null;
      });
    }

    try {
      final forecast = await WeatherForecastService.getLocalForecast(
        forceRefresh: forceRefresh,
        unit: weatherUnit,
      );
      if (!mounted) return;
      setState(() {
        _weatherForecast = forecast;
        _weatherError = null;
        _loadingWeather = false;
      });
    } on WeatherForecastException catch (error) {
      if (!mounted) return;
      setState(() {
        _weatherError = error.error;
        _loadingWeather = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = WeatherForecastError.network;
        _loadingWeather = false;
      });
    }
  }

  Future<void> _openMorningSetup() async {
    final onOpenAlarms = widget.onOpenAlarms;
    if (onOpenAlarms != null) {
      onOpenAlarms();
      return;
    }
    await Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (_) => const AlarmListScreen()));
    await _loadSettings();
  }

  Future<void> _openEveningSetup() async {
    await Navigator.of(context).push(
      appPageRoute<void>(builder: (_) => const EveningBlessingSetupScreen()),
    );
    if (!mounted) return;
    await _loadSettings();
  }

  Future<void> _openNotificationSettings() async {
    await Geolocator.openAppSettings();
    if (!mounted) return;
    await _loadSettings();
  }

  Future<void> _openSettings() async {
    final onOpenSettings = widget.onOpenSettings;
    if (onOpenSettings != null) {
      onOpenSettings();
      return;
    }
    await Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (_) => const SettingsScreen()));
    await _loadSettings();
  }

  Future<void> _enableWeather() async {
    await WeatherPreferencesService.setEnabled(true);
    if (!mounted) return;
    setState(() => _weatherEnabled = true);
    await _loadWeatherForecast(forceRefresh: true);
  }

  Future<void> _openCalendar() async {
    final onOpenCalendar = widget.onOpenCalendar;
    if (onOpenCalendar != null) {
      onOpenCalendar();
      return;
    }
    await Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (_) => const StreakCalendarScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final morningLabel = AlarmPreferences.formatTime(
      _morningHour,
      _morningMinute,
    );
    final eveningLabel = AlarmPreferences.formatTime(
      _eveningHour,
      _eveningMinute,
    );
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0D0A), AppTheme.bg, Color(0xFF211B13)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeTopBar(
                  title: l10n.appTitle,
                  settingsTooltip: l10n.settings,
                  // 하단 탭에 설정이 있으면 상단 톱니바퀴는 숨긴다.
                  onSettingsTap: widget.onOpenSettings != null
                      ? null
                      : _openSettings,
                ),
                const SizedBox(height: 26),
                _MorningAlarmCard(
                  label: l10n.morningAlarm,
                  time: morningLabel,
                  enabled: _morningEnabled,
                  onTap: _openMorningSetup,
                ),
                if (AlarmPreferences.eveningFeatureEnabled) ...[
                  const SizedBox(height: 14),
                  _EveningBlessingHomeCard(
                    label: l10n.eveningChildrenBlessing,
                    subtitle: l10n.eveningBlessingSubtitle,
                    time: eveningLabel,
                    enabled: _eveningEnabled,
                    onTap: _openEveningSetup,
                  ),
                ],
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.webPreviewBanner,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
                if (!kIsWeb && !_notificationsEnabled) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.off.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notifications_off_outlined,
                              color: AppTheme.off,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.notificationsDisabledWarning,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openNotificationSettings,
                            child: Text(l10n.openIphoneSettings),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                StreakCard(
                  onTap: _openCalendar,
                  refreshSignal: widget.refreshSignal,
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 16),
                  if (_weatherEnabled)
                    _WeatherForecastCard(
                      forecast: _weatherForecast,
                      loading: _loadingWeather,
                      error: _weatherError,
                      unit: _weatherUnit,
                      onRefresh: () {
                        unawaited(_loadWeatherForecast(forceRefresh: true));
                      },
                    )
                  else
                    _EnableWeatherCard(
                      label: l10n.showLocalWeather,
                      onTap: () => unawaited(_enableWeather()),
                    ),
                ],
                const SizedBox(height: 28),
                _HomeHero(localeCode: _localeCode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _localeCode => LocaleService.instance.locale.languageCode;
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.title,
    required this.settingsTooltip,
    this.onSettingsTap,
  });

  final String title;
  final String settingsTooltip;

  /// null이면 톱니바퀴를 숨긴다(하단 탭에 설정이 있을 때).
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
        ),
        if (onSettingsTap != null) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
                onPressed: onSettingsTap,
                tooltip: settingsTooltip,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final copy = _HomeHeroCopy.forLocale(localeCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.title,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          copy.body,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppTheme.accent, width: 2)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.verse,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 16,
                    height: 1.48,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  copy.reference,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHeroCopy {
  const _HomeHeroCopy({
    required this.title,
    required this.body,
    required this.verse,
    required this.reference,
  });

  final String title;
  final String body;
  final String verse;
  final String reference;

  static _HomeHeroCopy forLocale(String localeCode) {
    switch (localeCode) {
      case 'ko':
        return const _HomeHeroCopy(
          title: '예수님의 습관을 따라',
          body: '말씀을 읽고 기도하며 하루를 시작하세요.',
          verse:
              '예수께서 나가사 습관을 좇아 감람 산에 가시매 제자들도 좇았더니 저희를 떠나 돌 던질 만큼 가서 무릎을 꿇고 기도하여',
          reference: '누가복음 22:39, 41, 개역한글',
        );
      case 'de':
        return const _HomeHeroCopy(
          title: 'Wie es Jesu Gewohnheit war',
          body: 'Lies Gottes Wort, bete laut und beginne mit Gott.',
          verse:
              'Jesus ging, wie es seine Gewohnheit war, zum Ölberg. Dort kniete er nieder und betete.',
          reference: 'Lukas 22,39.41, sinngemäß',
        );
      case 'ru':
        return const _HomeHeroCopy(
          title: 'По обыкновению Иисуса',
          body: 'Прочитайте Писание, помолитесь вслух и начните день с Богом.',
          verse:
              'Иисус, по обыкновению, пошёл на гору Елеонскую. Там Он преклонил колени и молился.',
          reference: 'Луки 22:39, 41, смысловая передача',
        );
      default:
        return const _HomeHeroCopy(
          title: "As Was Jesus' Custom",
          body: 'Read the Word, pray aloud, and begin with God.',
          verse:
              'Jesus went, as was his custom, to the Mount of Olives. There he knelt down and prayed.',
          reference: 'Luke 22:39, 41, WEB',
        );
    }
  }
}

class _MorningAlarmCard extends StatelessWidget {
  const _MorningAlarmCard({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15120D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.wb_twilight_outlined,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (enabled ? AppTheme.done : AppTheme.off)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        enabled ? l10n.alarmOn : l10n.alarmOff,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: enabled ? AppTheme.done : AppTheme.off,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      time,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 62,
                        height: 1.0,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.tapToSetTimeAndSound,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.accent,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EveningBlessingHomeCard extends StatelessWidget {
  const _EveningBlessingHomeCard({
    required this.label,
    required this.subtitle,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (enabled ? AppTheme.done : AppTheme.off)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        enabled ? l10n.alarmOn : l10n.alarmOff,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: enabled ? AppTheme.done : AppTheme.off,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      time,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 62,
                        height: 1.0,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.accent,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherForecastCard extends StatelessWidget {
  const _WeatherForecastCard({
    required this.forecast,
    required this.loading,
    required this.error,
    required this.unit,
    required this.onRefresh,
  });

  final WeatherForecast? forecast;
  final bool loading;
  final WeatherForecastError? error;
  final WeatherTemperatureUnit unit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = LocaleService.instance.locale.languageCode;
    final data = forecast;
    final today = data?.today;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data == null
                    ? Icons.cloud_queue
                    : _weatherIcon(data.currentWeatherCode),
                color: AppTheme.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.localWeather,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data == null
                          ? l10n.localWeatherSubtitle
                          : _weatherCondition(
                              data.currentWeatherCode,
                              localeCode,
                            ),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 42,
                height: 42,
                child: IconButton(
                  onPressed: loading ? null : onRefresh,
                  tooltip: l10n.weatherRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: AppTheme.textMuted,
                          size: 21,
                        ),
                ),
              ),
            ],
          ),
          if (data == null) ...[
            const SizedBox(height: 14),
            Text(
              error == null
                  ? l10n.localWeatherLoading
                  : _weatherErrorText(l10n, error!),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _temperature(data.currentTemperature, unit),
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 46,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      [
                        l10n.weatherFeelsLike(
                          _temperature(data.currentApparentTemperature, unit),
                        ),
                        l10n.weatherWind(
                          data.currentWindSpeed.round(),
                          unit.windSpeedLabel,
                        ),
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (today != null) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.weatherHighLow(_temperature(today.highTemperature, unit), _temperature(today.lowTemperature, unit))} · ${l10n.weatherRainChance(today.precipitationProbability)}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (data.days.length > 1) ...[
              const SizedBox(height: 18),
              Text(
                l10n.weatherThisWeek,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = data.days[index];
                    return _WeatherDayPill(
                      day: day,
                      localeCode: localeCode,
                      unit: unit,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.weatherAttribution,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                _weatherErrorText(l10n, error!),
                style: const TextStyle(
                  color: AppTheme.off,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeatherDayPill extends StatelessWidget {
  const _WeatherDayPill({
    required this.day,
    required this.localeCode,
    required this.unit,
  });

  final WeatherDay day;
  final String localeCode;
  final WeatherTemperatureUnit unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _shortWeekday(day.date, localeCode),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(_weatherIcon(day.weatherCode), color: AppTheme.accent, size: 18),
          Text(
            '${_temperature(day.highTemperature, unit)} / ${_temperature(day.lowTemperature, unit)}',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _temperature(double value, WeatherTemperatureUnit unit) =>
    '${value.round()}${unit.symbol}';

IconData _weatherIcon(int code) {
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

String _weatherCondition(int code, String localeCode) {
  final condition = () {
    if (code == 0) return 'clear';
    if (code == 1 || code == 2) return 'partlyCloudy';
    if (code == 3) return 'cloudy';
    if (code == 45 || code == 48) return 'fog';
    if (code >= 51 && code <= 67) return 'drizzle';
    if (code >= 71 && code <= 77) return 'snow';
    if (code >= 80 && code <= 82) return 'rain';
    if (code >= 85 && code <= 86) return 'snowShowers';
    if (code >= 95) return 'thunderstorm';
    return 'unknown';
  }();

  const labels = {
    'en': {
      'clear': 'Clear',
      'partlyCloudy': 'Partly cloudy',
      'cloudy': 'Cloudy',
      'fog': 'Fog',
      'drizzle': 'Drizzle',
      'rain': 'Rain showers',
      'snow': 'Snow',
      'snowShowers': 'Snow showers',
      'thunderstorm': 'Thunderstorm',
      'unknown': 'Weather',
    },
    'ko': {
      'clear': '맑음',
      'partlyCloudy': '구름 조금',
      'cloudy': '흐림',
      'fog': '안개',
      'drizzle': '이슬비',
      'rain': '소나기',
      'snow': '눈',
      'snowShowers': '눈 소나기',
      'thunderstorm': '뇌우',
      'unknown': '날씨',
    },
    'de': {
      'clear': 'Klar',
      'partlyCloudy': 'Teilweise bewölkt',
      'cloudy': 'Bewölkt',
      'fog': 'Nebel',
      'drizzle': 'Nieselregen',
      'rain': 'Regenschauer',
      'snow': 'Schnee',
      'snowShowers': 'Schneeschauer',
      'thunderstorm': 'Gewitter',
      'unknown': 'Wetter',
    },
    'ru': {
      'clear': 'Ясно',
      'partlyCloudy': 'Переменная облачность',
      'cloudy': 'Облачно',
      'fog': 'Туман',
      'drizzle': 'Морось',
      'rain': 'Ливни',
      'snow': 'Снег',
      'snowShowers': 'Снежные заряды',
      'thunderstorm': 'Гроза',
      'unknown': 'Погода',
    },
  };

  return labels[localeCode]?[condition] ?? labels['en']![condition]!;
}

String _shortWeekday(DateTime date, String localeCode) {
  final index = date.weekday - 1;
  const labels = {
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'ko': ['월', '화', '수', '목', '금', '토', '일'],
    'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  };
  return (labels[localeCode] ?? labels['en']!)[index];
}

String _weatherErrorText(AppLocalizations l10n, WeatherForecastError error) {
  switch (error) {
    case WeatherForecastError.denied:
    case WeatherForecastError.deniedForever:
      return l10n.weatherPermissionRequired;
    case WeatherForecastError.locationServicesDisabled:
      return l10n.weatherLocationServicesOff;
    case WeatherForecastError.network:
    case WeatherForecastError.parse:
      return l10n.weatherUnavailable;
  }
}

/// 아침·저녁 알람 시간 설정 화면
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.isRootScreen = false});

  /// true면 설정을 루트 화면처럼 표시합니다.
  final bool isRootScreen;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late TimeOfDay _morningTime;
  bool _morningEnabled = true;
  Set<int> _morningWeekdays = AlarmPreferences.defaultWeekdays.toSet();
  bool _saving = false;
  bool _notificationsPermissionEnabled = false;
  bool _speechPermissionEnabled = false;
  String _alarmKitAuthorizationState = 'unknown';
  bool _checkingPermissions = false;
  ScripturePlan _scripturePlan = ScripturePlan.daily;
  MissionContentMode _missionContentMode =
      MissionContentMode.scriptureAndPrayer;
  double _missionPassThreshold =
      PrayerPreferencesService.defaultMissionPassThreshold;
  bool _weatherEnabled = false;
  WeatherTemperatureUnit _weatherUnit = WeatherTemperatureUnit.fahrenheit;
  bool _savingWeather = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _morningTime = const TimeOfDay(
      hour: AlarmPreferences.defaultHour,
      minute: AlarmPreferences.defaultMinute,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(_loadSettings());
    }
  }

  Future<void> _loadSettings() async {
    // 멀티 알람: 홈 카드에는 알람 목록에서 다음에 실제로 울릴 시간을 보여 준다.
    final alarms = await AlarmStore.loadAlarms();
    final nextMorning = AlarmStore.nextOccurrence(alarms, DateTime.now());
    final morningHour = nextMorning?.hour ?? await AlarmPreferences.getHour();
    final morningMinute =
        nextMorning?.minute ?? await AlarmPreferences.getMinute();
    final morningEnabled = await AlarmPreferences.isEnabled();
    final morningWeekdays = await AlarmPreferences.getWeekdays();
    final notificationsPermissionEnabled =
        !kIsWeb && await AlarmNotificationService.instance.hasPermissions();
    final speechPermissionEnabled =
        !kIsWeb && await stt.SpeechToText().hasPermission;
    final alarmKitAuthorizationState = !kIsWeb
        ? await NativeAlarmService.authorizationState()
        : 'unavailable';
    final scripturePlan = await PrayerPreferencesService.getScripturePlan();
    final missionContentMode =
        await PrayerPreferencesService.getMissionContentMode();
    final missionPassThreshold =
        await PrayerPreferencesService.getMissionPassThreshold();
    final weatherEnabled =
        !kIsWeb && await WeatherPreferencesService.isEnabled();
    final weatherUnit = !kIsWeb
        ? await WeatherPreferencesService.getTemperatureUnit()
        : WeatherTemperatureUnit.fahrenheit;

    setState(() {
      _morningTime = TimeOfDay(hour: morningHour, minute: morningMinute);
      _morningEnabled = morningEnabled;
      _morningWeekdays = morningWeekdays.toSet();
      _notificationsPermissionEnabled = notificationsPermissionEnabled;
      _speechPermissionEnabled = speechPermissionEnabled;
      _alarmKitAuthorizationState = alarmKitAuthorizationState;
      _scripturePlan = scripturePlan;
      _missionContentMode = missionContentMode;
      _missionPassThreshold = missionPassThreshold;
      _weatherEnabled = weatherEnabled;
      _weatherUnit = weatherUnit;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb || _checkingPermissions) return;
    setState(() => _checkingPermissions = true);
    final enabled = await AlarmNotificationService.instance.ensurePermissions();
    if (enabled) {
      await AlarmScheduleHelper.ensureScheduled();
    } else {
      await Geolocator.openAppSettings();
    }
    if (!mounted) return;
    setState(() => _checkingPermissions = false);
    await _loadSettings();
  }

  Future<void> _requestAlarmKitPermission() async {
    if (kIsWeb || _checkingPermissions) return;
    setState(() => _checkingPermissions = true);
    final enabled = await NativeAlarmService.requestAuthorization();
    if (enabled) {
      await AlarmScheduleHelper.ensureScheduled();
    } else {
      await Geolocator.openAppSettings();
    }
    if (!mounted) return;
    setState(() => _checkingPermissions = false);
    await _loadSettings();
  }

  Future<void> _requestSpeechPermission() async {
    if (kIsWeb || _checkingPermissions) return;
    setState(() => _checkingPermissions = true);
    final speech = stt.SpeechToText();
    final enabled = await speech.initialize();
    if (enabled) {
      unawaited(SimpleMorningMissionScreen.prewarmSpeechRecognition());
    }
    if (!enabled) {
      await Geolocator.openAppSettings();
    }
    if (!mounted) return;
    setState(() => _checkingPermissions = false);
    await _loadSettings();
  }

  Future<void> _pickMorningTime() async {
    await Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (_) => const AlarmListScreen()));
    if (!mounted) return;
    await _loadSettings();
  }

  Future<void> _setMorningEnabled(bool value) async {
    if (!value &&
        await AlarmSessionService.instance.isMorningCompletionRequired()) {
      if (!mounted) return;
      setState(() => _morningEnabled = true);
      _showTestSnackBar(AppLocalizations.of(context).morningAlarmMustComplete);
      return;
    }
    setState(() => _morningEnabled = value);
    // 토글일 뿐이니 각 알람의 시간·요일은 그대로 보존한다.
    await AlarmScheduleHelper.setMorningEnabled(value);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final eveningHour = await AlarmPreferences.getEveningHour();
    final eveningMinute = await AlarmPreferences.getEveningMinute();
    final eveningEnabled = await AlarmPreferences.isEveningEnabled();

    await AlarmScheduleHelper.saveAll(
      morningHour: _morningTime.hour,
      morningMinute: _morningTime.minute,
      morningEnabled: _morningEnabled,
      morningWeekdays: _morningWeekdays,
      eveningHour: eveningHour,
      eveningMinute: eveningMinute,
      eveningEnabled: eveningEnabled,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (!widget.isRootScreen) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _saveMissionPassThreshold(double value) async {
    final rounded = (value * 100).round() / 100;
    setState(() => _missionPassThreshold = rounded);
    await PrayerPreferencesService.setMissionPassThreshold(rounded);
  }

  Future<void> _openPracticeMission() async {
    await Navigator.of(context).push(
      appPageRoute<void>(
        settings: const RouteSettings(name: '/practice-morning-mission'),
        builder: (_) => const SimpleMorningMissionScreen(practiceMode: true),
      ),
    );
  }

  Future<void> _openPremium() async {
    await Navigator.of(
      context,
    ).push(appPageRoute<void>(builder: (_) => const PremiumScreen()));
  }

  Future<void> _setWeatherEnabled(bool value) async {
    if (kIsWeb || _savingWeather) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _savingWeather = true);
    if (!value) {
      await WeatherPreferencesService.setEnabled(false);
      if (!mounted) return;
      setState(() {
        _weatherEnabled = false;
        _savingWeather = false;
      });
      _showTestSnackBar(l10n.weatherDisabled);
      return;
    }

    try {
      await WeatherForecastService.getLocalForecast(
        forceRefresh: true,
        unit: _weatherUnit,
      );
      await WeatherPreferencesService.setEnabled(true);
      if (!mounted) return;
      setState(() {
        _weatherEnabled = true;
        _savingWeather = false;
      });
      _showTestSnackBar(l10n.weatherEnabled);
    } on WeatherForecastException catch (error) {
      await WeatherPreferencesService.setEnabled(false);
      if (!mounted) return;
      setState(() {
        _weatherEnabled = false;
        _savingWeather = false;
      });
      _showTestSnackBar(_weatherErrorText(l10n, error.error));
    } catch (_) {
      await WeatherPreferencesService.setEnabled(false);
      if (!mounted) return;
      setState(() {
        _weatherEnabled = false;
        _savingWeather = false;
      });
      _showTestSnackBar(l10n.weatherUnavailable);
    }
  }

  Future<void> _setWeatherTemperatureUnit(WeatherTemperatureUnit unit) async {
    if (kIsWeb || _savingWeather || unit == _weatherUnit) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _weatherUnit = unit;
      _savingWeather = _weatherEnabled;
    });
    await WeatherPreferencesService.setTemperatureUnit(unit);

    if (!_weatherEnabled) return;

    try {
      await WeatherForecastService.getLocalForecast(
        forceRefresh: true,
        unit: unit,
      );
      if (!mounted) return;
      setState(() => _savingWeather = false);
    } on WeatherForecastException catch (error) {
      if (!mounted) return;
      setState(() => _savingWeather = false);
      _showTestSnackBar(_weatherErrorText(l10n, error.error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingWeather = false);
      _showTestSnackBar(l10n.weatherUnavailable);
    }
  }

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context);
    final current = LocaleService.instance.locale;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            l10n.selectLanguage,
            style: const TextStyle(color: AppTheme.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: LocaleService.supportedLocales.map((locale) {
                return RadioListTile<Locale>(
                  title: Text(
                    LocaleService.instance.displayNameFor(locale),
                    style: const TextStyle(color: AppTheme.text),
                  ),
                  value: locale,
                  // ignore: deprecated_member_use
                  groupValue: current,
                  activeColor: AppTheme.accent,
                  // ignore: deprecated_member_use
                  onChanged: (value) async {
                    if (value == null) return;
                    await LocaleService.instance.setLocale(value);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickScripturePlan() async {
    final l10n = AppLocalizations.of(context);
    final current = _scripturePlan;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            l10n.selectScripturePlan,
            style: const TextStyle(color: AppTheme.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ScripturePlan.values.map((plan) {
                return RadioListTile<ScripturePlan>(
                  title: Text(
                    _scripturePlanTitle(l10n, plan),
                    style: const TextStyle(color: AppTheme.text),
                  ),
                  subtitle: Text(
                    _scripturePlanSubtitle(l10n, plan),
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  value: plan,
                  // ignore: deprecated_member_use
                  groupValue: current,
                  activeColor: AppTheme.accent,
                  // ignore: deprecated_member_use
                  onChanged: (value) async {
                    if (value == null) return;
                    await PrayerPreferencesService.setScripturePlan(value);
                    if (!mounted) return;
                    setState(() => _scripturePlan = value);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMissionContentMode() async {
    final l10n = AppLocalizations.of(context);
    final current = _missionContentMode;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            l10n.selectMissionContent,
            style: const TextStyle(color: AppTheme.text),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: MissionContentMode.values.map((mode) {
                return RadioListTile<MissionContentMode>(
                  title: Text(
                    _missionContentModeTitle(l10n, mode),
                    style: const TextStyle(color: AppTheme.text),
                  ),
                  subtitle: Text(
                    _missionContentModeSubtitle(l10n, mode),
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  value: mode,
                  // ignore: deprecated_member_use
                  groupValue: current,
                  activeColor: AppTheme.accent,
                  // ignore: deprecated_member_use
                  onChanged: (value) async {
                    if (value == null) return;
                    await PrayerPreferencesService.setMissionContentMode(value);
                    if (!mounted) return;
                    setState(() => _missionContentMode = value);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _scripturePlanTitle(AppLocalizations l10n, ScripturePlan plan) {
    return switch (plan) {
      ScripturePlan.daily => l10n.scripturePlanDaily,
      ScripturePlan.beloved52 => l10n.scripturePlanBeloved52,
    };
  }

  String _scripturePlanSubtitle(AppLocalizations l10n, ScripturePlan plan) {
    return switch (plan) {
      ScripturePlan.daily => l10n.scripturePlanDailySubtitle,
      ScripturePlan.beloved52 => l10n.scripturePlanBeloved52Subtitle,
    };
  }

  String _missionContentModeTitle(
    AppLocalizations l10n,
    MissionContentMode mode,
  ) {
    return switch (mode) {
      MissionContentMode.scriptureAndPrayer =>
        l10n.missionContentScriptureAndPrayer,
      MissionContentMode.scriptureOnly => l10n.missionContentScriptureOnly,
      MissionContentMode.prayerOnly => l10n.missionContentPrayerOnly,
    };
  }

  String _missionContentModeSubtitle(
    AppLocalizations l10n,
    MissionContentMode mode,
  ) {
    return switch (mode) {
      MissionContentMode.scriptureAndPrayer =>
        l10n.missionContentScriptureAndPrayerSubtitle,
      MissionContentMode.scriptureOnly =>
        l10n.missionContentScriptureOnlySubtitle,
      MissionContentMode.prayerOnly => l10n.missionContentPrayerOnlySubtitle,
    };
  }

  void _showTestSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _settingsSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _timePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AlarmPreferences.formatTime(time.hour, time.minute),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.text,
                  ),
                ),
                const Icon(Icons.access_time, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailedHowItWorksCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline,
                color: AppTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.alarmDetailedHowItWorksTitle,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.alarmDetailedHowItWorksBody,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _missionPassThresholdCard(AppLocalizations l10n) {
    final percent = (_missionPassThreshold * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.missionPassThreshold,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.missionPassThresholdSubtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _missionPassThreshold.clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.surfaceLight,
            onChanged: (value) {
              setState(() => _missionPassThreshold = value);
            },
            onChangeEnd: (value) => unawaited(_saveMissionPassThreshold(value)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.missionPassThresholdLow,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              Text(
                l10n.missionPassThresholdHigh,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _localWeatherSettingsCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: _savingWeather
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : const Icon(
                    Icons.cloud_outlined,
                    color: AppTheme.accent,
                    size: 22,
                  ),
            title: Text(
              l10n.enableLocalWeather,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              l10n.localWeatherSettingsBody,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            value: _weatherEnabled,
            activeThumbColor: AppTheme.accent,
            onChanged: _savingWeather ? null : _setWeatherEnabled,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.weatherTemperatureUnit,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _weatherUnitButton(
                  l10n.weatherUnitFahrenheit,
                  WeatherTemperatureUnit.fahrenheit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _weatherUnitButton(
                  l10n.weatherUnitCelsius,
                  WeatherTemperatureUnit.celsius,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionsSettingsCard(AppLocalizations l10n) {
    final alarmKitEnabled = _alarmKitAuthorizationState == 'authorized';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppTheme.accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.permissionSettingsTitle,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.permissionSettingsBody,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _permissionActionRow(
            icon: Icons.notifications_active_outlined,
            title: l10n.permissionNotificationTitle,
            body: l10n.permissionNotificationBody,
            enabled: _notificationsPermissionEnabled,
            onPressed: _requestNotificationPermission,
            l10n: l10n,
          ),
          const Divider(color: AppTheme.surfaceLight, height: 20),
          _permissionActionRow(
            icon: Icons.alarm_on_outlined,
            title: l10n.permissionAlarmKitTitle,
            body: l10n.permissionAlarmKitBody,
            enabled: alarmKitEnabled,
            onPressed: _requestAlarmKitPermission,
            l10n: l10n,
          ),
          const Divider(color: AppTheme.surfaceLight, height: 20),
          _permissionActionRow(
            icon: Icons.mic_none_outlined,
            title: l10n.permissionMicrophoneTitle,
            body: l10n.permissionMicrophoneBody,
            enabled: _speechPermissionEnabled,
            onPressed: _requestSpeechPermission,
            l10n: l10n,
          ),
        ],
      ),
    );
  }

  Widget _permissionActionRow({
    required IconData icon,
    required String title,
    required String body,
    required bool enabled,
    required VoidCallback onPressed,
    required AppLocalizations l10n,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: enabled ? AppTheme.accent : AppTheme.textMuted,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: enabled || _checkingPermissions ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: enabled ? AppTheme.textMuted : AppTheme.bg,
            disabledForegroundColor: AppTheme.textMuted,
            backgroundColor: enabled ? Colors.transparent : AppTheme.accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: enabled ? AppTheme.surfaceLight : AppTheme.accent,
              ),
            ),
          ),
          child: Text(
            enabled ? l10n.permissionEnabled : l10n.permissionEnable,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _weatherUnitButton(String label, WeatherTemperatureUnit unit) {
    final selected = _weatherUnit == unit;
    return OutlinedButton(
      onPressed: _savingWeather
          ? null
          : () => unawaited(_setWeatherTemperatureUnit(unit)),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppTheme.bg : AppTheme.text,
        backgroundColor: selected ? AppTheme.accent : Colors.transparent,
        side: BorderSide(
          color: selected ? AppTheme.accent : AppTheme.surfaceLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _bibleLicenseCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: AppTheme.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bibleLicenseTitle,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.bibleLicenseBody,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        automaticallyImplyLeading: !widget.isRootScreen,
        iconTheme: const IconThemeData(color: AppTheme.textMuted),
        title: Text(
          l10n.settings,
          style: const TextStyle(color: AppTheme.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _settingsSectionTitle(l10n.missionContent),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language, color: AppTheme.textMuted),
                title: Text(
                  l10n.language,
                  style: const TextStyle(color: AppTheme.text),
                ),
                subtitle: Text(
                  LocaleService.instance.displayNameFor(
                    LocaleService.instance.locale,
                  ),
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                onTap: _pickLanguage,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.textMuted,
                ),
                title: Text(
                  l10n.scripturePlan,
                  style: const TextStyle(color: AppTheme.text),
                ),
                subtitle: Text(
                  _scripturePlanTitle(l10n, _scripturePlan),
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                onTap: _pickScripturePlan,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.checklist_rtl,
                  color: AppTheme.textMuted,
                ),
                title: Text(
                  l10n.missionContent,
                  style: const TextStyle(color: AppTheme.text),
                ),
                subtitle: Text(
                  _missionContentModeTitle(l10n, _missionContentMode),
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                onTap: _pickMissionContentMode,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.34),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppTheme.accent,
                  ),
                  title: Text(
                    l10n.premiumTitle,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    l10n.premiumSettingsSubtitle,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                  ),
                  onTap: _openPremium,
                ),
              ),
              const SizedBox(height: 32),
              _timePickerTile(
                label: l10n.morningAlarm,
                time: _morningTime,
                onTap: _pickMorningTime,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.enableMorningAlarm,
                  style: const TextStyle(color: AppTheme.text),
                ),
                subtitle: Text(
                  l10n.morningAlarmSubtitle,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                value: _morningEnabled,
                activeThumbColor: AppTheme.accent,
                onChanged: _setMorningEnabled,
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 32),
                const AlarmSoundSettingsSection(),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_saving ? l10n.saving : l10n.saveAlarms),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openPracticeMission,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(l10n.practiceMission),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    side: BorderSide(
                      color: AppTheme.accent.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.practiceMissionSubtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _missionPassThresholdCard(l10n),
              if (!kIsWeb) ...[
                const SizedBox(height: 32),
                _settingsSectionTitle(l10n.localWeather),
                _localWeatherSettingsCard(l10n),
                const SizedBox(height: 32),
                _settingsSectionTitle(l10n.permissionSettingsTitle),
                _permissionsSettingsCard(l10n),
              ],
              const SizedBox(height: 32),
              _detailedHowItWorksCard(l10n),
              const SizedBox(height: 12),
              _bibleLicenseCard(l10n),
            ],
          ),
        ),
      ),
    );
  }
}

/// 날씨가 꺼져 있을 때 홈에 보여 주는 켜기 카드.
class _EnableWeatherCard extends StatelessWidget {
  const _EnableWeatherCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF12100D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceLight),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                color: AppTheme.accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 날씨 탭 — 애플 날씨 스타일: 큰 현재 기온 + 시간별 + 10일 예보.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _enabled = false;
  bool _loading = true;
  WeatherForecast? _forecast;
  WeatherForecastError? _error;
  WeatherTemperatureUnit _unit = WeatherTemperatureUnit.fahrenheit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final enabled = await WeatherPreferencesService.isEnabled();
    final unit = await WeatherPreferencesService.getTemperatureUnit();
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _enabled = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _enabled = true;
      _unit = unit;
      _loading = true;
      _error = null;
    });
    try {
      final forecast = await WeatherForecastService.getLocalForecast(
        forceRefresh: forceRefresh,
        unit: unit,
      );
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _loading = false;
      });
    } on WeatherForecastException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = WeatherForecastError.network;
        _loading = false;
      });
    }
  }

  Future<void> _enable() async {
    await WeatherPreferencesService.setEnabled(true);
    await _load(forceRefresh: true);
  }

  String _hourLabel(BuildContext context, DateTime time, bool isNow) {
    final l10n = AppLocalizations.of(context);
    if (isNow) return l10n.nowLabel;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final hour = time.hour;
    if (isKorean) {
      final period = hour < 12 ? '오전' : '오후';
      final display = hour % 12 == 0 ? 12 : hour % 12;
      return '$period $display시';
    }
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }

  Widget _buildHero(AppLocalizations l10n, WeatherForecast data) {
    final today = data.today;
    final localeCode = LocaleService.instance.locale.languageCode;
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.myLocation,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
        ),
        Text(
          _temperature(data.currentTemperature, _unit),
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 78,
            fontWeight: FontWeight.w200,
            height: 1.15,
          ),
        ),
        Text(
          _weatherCondition(data.currentWeatherCode, localeCode),
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (today != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.weatherHighLow(
              _temperature(today.highTemperature, _unit),
              _temperature(today.lowTemperature, _unit),
            ),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildHourly(BuildContext context, WeatherForecast data) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour);
    final upcoming = data.hours
        .where((h) => !h.time.isBefore(start))
        .take(13)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: upcoming.length,
          itemBuilder: (context, index) {
            final hour = upcoming[index];
            return SizedBox(
              width: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _hourLabel(context, hour.time, index == 0),
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    _weatherIcon(hour.weatherCode),
                    color: AppTheme.accent,
                    size: 22,
                  ),
                  Text(
                    _temperature(hour.temperature, _unit),
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDaily(BuildContext context, WeatherForecast data) {
    final l10n = AppLocalizations.of(context);
    final localeCode = LocaleService.instance.locale.languageCode;
    if (data.days.isEmpty) return const SizedBox.shrink();

    var minLow = data.days.first.lowTemperature;
    var maxHigh = data.days.first.highTemperature;
    for (final day in data.days) {
      if (day.lowTemperature < minLow) minLow = day.lowTemperature;
      if (day.highTemperature > maxHigh) maxHigh = day.highTemperature;
    }
    final range = (maxHigh - minLow).abs() < 0.1 ? 1.0 : maxHigh - minLow;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tenDayForecast,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < data.days.length; i++) ...[
            if (i > 0) const Divider(color: AppTheme.surfaceLight, height: 1),
            _buildDailyRow(
              l10n,
              localeCode,
              data.days[i],
              isToday: i == 0,
              minLow: minLow,
              range: range,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyRow(
    AppLocalizations l10n,
    String localeCode,
    WeatherDay day, {
    required bool isToday,
    required double minLow,
    required double range,
  }) {
    final startFraction = ((day.lowTemperature - minLow) / range).clamp(
      0.0,
      1.0,
    );
    final widthFraction = ((day.highTemperature - day.lowTemperature) / range)
        .clamp(0.06, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              isToday ? l10n.todayLabel : _shortWeekday(day.date, localeCode),
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(_weatherIcon(day.weatherCode), color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text(
              _temperature(day.lowTemperature, _unit),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                return SizedBox(
                  height: 5,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Positioned(
                        left: trackWidth * startFraction,
                        width:
                            trackWidth *
                            (startFraction + widthFraction > 1.0
                                ? 1.0 - startFraction
                                : widthFraction),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accent.withValues(alpha: 0.45),
                                AppTheme.accent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              _temperature(day.highTemperature, _unit),
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = _forecast;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: AppTheme.textMuted,
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: l10n.backToMain,
              )
            : null,
        title: Text(
          l10n.localWeather,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
            tooltip: l10n.localWeather,
            onPressed: _loading
                ? null
                : () => unawaited(_load(forceRefresh: true)),
          ),
        ],
      ),
      body: _loading && data == null && _enabled
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (!_enabled)
                  _EnableWeatherCard(
                    label: l10n.showLocalWeather,
                    onTap: () => unawaited(_enable()),
                  )
                else if (data == null)
                  _WeatherForecastCard(
                    forecast: null,
                    loading: _loading,
                    error: _error,
                    unit: _unit,
                    onRefresh: () => unawaited(_load(forceRefresh: true)),
                  )
                else ...[
                  _buildHero(l10n, data),
                  _buildHourly(context, data),
                  const SizedBox(height: 14),
                  _buildDaily(context, data),
                  const SizedBox(height: 12),
                  Text(
                    l10n.weatherAttribution,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _weatherErrorText(l10n, _error!),
                      style: const TextStyle(
                        color: AppTheme.off,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
