import 'dart:async';

import 'package:alarm/alarm.dart' as alarm_pkg;
import 'package:alarm/utils/alarm_set.dart' as alarm_pkg_set;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'navigator_key.dart';
import 'navigation/app_page_route.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/app_launch_gate.dart';
import 'screens/simple_morning_mission_screen.dart';
import 'services/alarm_fire_watchdog.dart';
import 'services/alarm_launch_bridge.dart';
import 'services/alarm_notification_service.dart';
import 'services/alarm_persistence_service.dart';
import 'services/alarm_preferences.dart';
import 'services/alarm_schedule_helper.dart';
import 'services/alarm_session_service.dart';
import 'services/alarm_sound_preferences.dart';
import 'services/alarm_sound_service.dart';
import 'services/app_persistence_service.dart';
import 'services/app_deferred_startup.dart';
import 'services/app_launch_state.dart';
import 'services/locale_service.dart';
import 'services/native_alarm_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('${details.stack}');
    }
  };

  await LocaleService.instance.load();

  if (!kIsWeb) {
    try {
      debugPrint('[STARTUP] step 0: alarm package init');
      await alarm_pkg.Alarm.init();
      // Route alarm-package ringing events through our existing handler so the
      // ringing screen / mission / lock logic stays unchanged.
      alarm_pkg.Alarm.ringing.listen(_onAlarmPackageRinging);
      await AlarmScheduleHelper.cancelLegacyPackageAlarmsIfAlarmKitAuthorized();
      debugPrint('[STARTUP] step 1: notification init');
      await AlarmNotificationService.instance.init(
        onNotificationTriggered: _handleNotification,
      );
      NativeAlarmService.installAlertHandler((kind) {
        if (kind == NativeAlarmKind.morning) {
          unawaited(_handleNativeMorningAlarmLaunch());
        } else if (kind == NativeAlarmKind.evening) {
          unawaited(_handleNativeEveningAlarmLaunch());
        }
      });
      debugPrint('[STARTUP] step 2: launch bridge + deferred startup');
      AlarmLaunchBridge.install(_handleNotification);
      AppDeferredStartup.registerAlarmHandler(_handleNotification);
      debugPrint('[STARTUP] step 3: ensureLoudestPreset');
      await AlarmSoundPreferences.ensureLoudestPreset();
      debugPrint('[STARTUP] step 4: configure audio service');
      await AlarmSoundService.instance.configure();
      final morningOn = await AlarmPreferences.isEnabled();
      final eveningOn = await AlarmPreferences.isEveningEnabled();
      debugPrint(
        '[STARTUP] alarm prefs: morning=$morningOn evening=$eveningOn',
      );
      if (morningOn || eveningOn) {
        debugPrint('[STARTUP] arming silent loop...');
        await AlarmSoundService.instance.armSilentLoop();
        debugPrint('[STARTUP] arm call returned');
      } else {
        debugPrint('[STARTUP] no alarm enabled — skipping arm');
      }
    } catch (e, st) {
      debugPrint('[STARTUP] FAILED before arm: $e\n$st');
    }
  }

  runApp(const MeansOfGraceApp());
}

final Map<String, DateTime> _lastAlarmNotificationByPayload = {};

Future<bool> _usesAlarmKitForMorningNow() async {
  if (!await AlarmPreferences.isEnabled()) return false;
  return AlarmScheduleHelper.usesAlarmKitForMorning();
}

Future<bool> _usesIOSAlarmKitForMorningNow() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  return _usesAlarmKitForMorningNow();
}

Future<bool> _usesAlarmKitAudioModeNow() {
  return AlarmScheduleHelper.usesAlarmKitForMorning();
}

Future<void> _handleNativeMorningAlarmLaunch() async {
  // Android full-screen intents can arrive while Flutter is already running,
  // without a reliable lifecycle resume signal. If boot is still in progress,
  // leave the pending flag for AppLaunchGate so it can show the ringing screen.
  if (!AppLaunchState.bootComplete) {
    debugPrint('[NATIVE] boot pending; launch gate will show ringing screen');
    return;
  }

  final pending = await NativeAlarmService.consumePendingMission();
  if (pending?.kind != NativeAlarmKind.morning) return;
  if (await AlarmSessionService.instance.isAlarmCompletedToday(
    pending?.alarmId,
  )) {
    debugPrint('[NATIVE] morning alarm already completed; ignore launch');
    return;
  }
  // 어떤 알람이 울렸는지 세션에 기록해 두면 아멘 때 그 알람만 완료 처리된다.
  await AlarmSessionService.instance.activateMorningAlarmSession(
    alarmId: pending?.alarmId,
  );
  await _openAlarmFromNotification(
    AlarmNotificationService.morningAlarmPayload,
    alarmId: pending?.alarmId,
  );
}

Future<void> _handleNativeEveningAlarmLaunch() async {
  if (!AppLaunchState.bootComplete) {
    debugPrint('[NATIVE] boot pending; launch gate will show evening mission');
    return;
  }

  final pending = await NativeAlarmService.consumePendingMission();
  if (pending?.kind != NativeAlarmKind.evening) return;
  await AlarmSessionService.instance.activateEveningAlarmSession();
  await _openEveningMissionNow(
    '[ALARMKIT] route evening blessing',
    forceFromPending: true,
  );
}

/// alarm package ring callback — fires when its scheduled fallback alarm goes off.
/// Route into our existing handler for fallback/evening alarms. On iOS 26+
/// AlarmKit owns the morning path, so stale alarm-package morning rings are
/// stopped here before they can create a second sound or screen.
void _onAlarmPackageRinging(alarm_pkg_set.AlarmSet ringingSet) {
  debugPrint('[alarm-pkg] ring callback: ${ringingSet.alarms.length} alarm(s)');
  // Only push the mission UI when the app is actually foregrounded. While the
  // phone is on the lock screen, leave the alarm-package sound ringing —
  // pushing SimpleMorningMissionScreen runs its initState, which calls
  // Alarm.stop and kills the sound the moment the user wakes the screen.
  final state = WidgetsBinding.instance.lifecycleState;
  final navReady =
      navigatorKey.currentState != null && navigatorKey.currentContext != null;
  final isForeground = state == AppLifecycleState.resumed && navReady;
  for (final settings in ringingSet.alarms) {
    final payload = settings.payload;
    debugPrint(
      '[alarm-pkg] ringing id=${settings.id} payload=$payload '
      'lifecycle=$state navReady=$navReady foreground=$isForeground',
    );
    if (payload == AlarmNotificationService.morningAlarmPayload) {
      unawaited(_handleMorningPackageRinging(settings.id, isForeground));
      continue;
    }
    if (payload == AlarmNotificationService.eveningAlarmPayload) {
      unawaited(_handleEveningPackageRinging(settings.id, isForeground));
      continue;
    }
    if (!isForeground) {
      debugPrint('[alarm-pkg] backgrounded — keep ringing, no UI push');
      continue;
    }
  }
}

Future<void> _handleMorningPackageRinging(
  int alarmId,
  bool isForeground,
) async {
  if (await _usesAlarmKitForMorningNow()) {
    debugPrint('[ALARMKIT] stop stale alarm-package morning ring id=$alarmId');
    try {
      await alarm_pkg.Alarm.stop(alarmId);
    } catch (error) {
      debugPrint('[ALARMKIT] stale alarm-package stop failed: $error');
    }
    // 경량 취소만 — 전체 취소는 미션 보호 계열(시리즈·융단)까지 철거.
    await AlarmNotificationService.instance.cancelMorningMainNotification();
    return;
  }

  if (!isForeground) {
    debugPrint('[alarm-pkg] backgrounded — keep ringing, no UI push');
    return;
  }
  await _openMorningMissionNow('[ALARM] package ringing');
}

Future<void> _handleEveningPackageRinging(
  int alarmId,
  bool isForeground,
) async {
  if (await _usesAlarmKitAudioModeNow()) {
    debugPrint('[ALARMKIT] stop stale alarm-package evening ring id=$alarmId');
    try {
      await alarm_pkg.Alarm.stop(alarmId);
    } catch (error) {
      debugPrint('[ALARMKIT] stale evening alarm-package stop failed: $error');
    }
    // 경량 취소만 — 전체 취소는 미션 보호 계열(시리즈·융단)까지 철거.
    await AlarmNotificationService.instance.cancelEveningMainNotification();
    return;
  }

  if (!isForeground) {
    debugPrint('[alarm-pkg] backgrounded — keep ringing, no UI push');
    return;
  }
  await _handleNotification(
    AlarmNotificationService.eveningAlarmPayload,
    persistent: true,
  );
}

Future<void> _handleNotification(
  String payload, {
  bool persistent = false,
}) async {
  final isMorning = payload == AlarmNotificationService.morningAlarmPayload;
  final isEvening = payload == AlarmNotificationService.eveningAlarmPayload;

  if (isMorning && await _usesAlarmKitForMorningNow()) {
    debugPrint('[ALARMKIT] ignore legacy morning notification payload');
    // ⚠️ 경량 취소만 — cancelMorningAlarm(전체)을 부르면 포그라운드로
    // 배달된 융단/백스톱 1발이나 워치독 재발사가 강제종료 시리즈·백스톱
    // 전 계열을 스스로 철거한다(실측 2026-07-10: 미션마다 50발→11발 전멸).
    await AlarmNotificationService.instance.cancelMorningMainNotification();
    return;
  }

  if (isEvening && await _usesAlarmKitAudioModeNow()) {
    debugPrint('[ALARMKIT] ignore legacy evening notification payload');
    // 동일 원칙(저녁) — 융단·이탈시리즈는 참여/아멘만이 걷는다.
    await AlarmNotificationService.instance.cancelEveningMainNotification();
    return;
  }

  if (!AppLaunchState.bootComplete) {
    if (isMorning || isEvening) {
      await AlarmPersistenceService.onAlarmFired(payload);
    }
    return;
  }

  final now = DateTime.now();
  if (!persistent &&
      (payload == AlarmNotificationService.morningAlarmPayload ||
          payload == AlarmNotificationService.eveningAlarmPayload)) {
    final last = _lastAlarmNotificationByPayload[payload];
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastAlarmNotificationByPayload[payload] = now;
  }

  if (payload == AlarmNotificationService.morningAlarmPayload ||
      payload == AlarmNotificationService.eveningAlarmPayload) {
    final phase = AlarmSessionService.instance.liveAlarmUiPhase;
    if (phase != LiveAlarmUiPhase.listening &&
        phase != LiveAlarmUiPhase.success) {
      await AlarmPersistenceService.onAlarmFired(payload);
    }
  }

  await _openAlarmFromNotification(payload);
}

Future<void> _openAlarmFromNotification(
  String payload, {
  String? alarmId,
}) async {
  debugPrint(
    '[MISSION] _openAlarmFromNotification payload=$payload bootComplete=${AppLaunchState.bootComplete}',
  );
  if (!AppLaunchState.bootComplete) {
    debugPrint('Alarm UI: waiting for launch gate ($payload)');
    return;
  }

  final isMorning = payload == AlarmNotificationService.morningAlarmPayload;
  final isEvening = payload == AlarmNotificationService.eveningAlarmPayload;

  if (isMorning && await _usesIOSAlarmKitForMorningNow()) {
    await _openMorningMissionNow(
      '[ALARMKIT] route morning lock',
      alarmId: alarmId,
    );
    return;
  }

  // Android morning: the native audio service owns the ringing sound (it has
  // been playing continuously since the alarm fired) — never start the in-app
  // loop on top of it, or the ring restarts/overlaps.
  final nativeOwnsMorningSound =
      isMorning && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  for (var attempt = 0; attempt < 40; attempt++) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      if (AlarmSessionService.instance.isBlockingUiVisible) {
        final phase = AlarmSessionService.instance.liveAlarmUiPhase;
        if (phase == LiveAlarmUiPhase.ringing) {
          if ((isMorning || isEvening) && !nativeOwnsMorningSound) {
            await AlarmSoundService.instance.start();
          }
        }
        return;
      }

      final routeName = ModalRoute.of(context)?.settings.name;
      if (payload == AlarmNotificationService.eveningAlarmPayload &&
          (routeName == '/evening-ringing' || routeName == '/evening-alarm')) {
        return;
      }
      if (payload == AlarmNotificationService.morningAlarmPayload &&
          (routeName == '/morning-ringing' || routeName == '/morning-alarm')) {
        return;
      }

      if ((isMorning || isEvening) && !nativeOwnsMorningSound) {
        await AlarmSoundService.instance.start();
      }

      final ringingKind = isMorning
          ? AlarmRingingKind.morning
          : AlarmRingingKind.evening;
      final ringingRouteName = isMorning
          ? '/morning-ringing'
          : '/evening-ringing';

      await nav.push(
        liveAlarmPageRoute<void>(
          settings: RouteSettings(name: ringingRouteName),
          builder: (_) => AlarmRingingScreen(
            kind: ringingKind,
            onStartMission: () => _pushMissionFromRinging(payload),
          ),
        ),
      );
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  if ((isMorning || isEvening) && !nativeOwnsMorningSound) {
    await AlarmSoundService.instance.start();
  }
  debugPrint('Alarm UI: navigator not ready for $payload');
}

Future<void> _openMorningMissionNow(String reason, {String? alarmId}) async {
  debugPrint('$reason → push simple morning mission');
  final nativeOwnsMorningSound =
      await _usesIOSAlarmKitForMorningNow() ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  if (await AlarmSessionService.instance.isAlarmCompletedToday(alarmId)) {
    // Stale trigger after Amen (leftover notification, late retry) — today's
    // mission for this alarm is done, never open a second one.
    debugPrint(
      '[MISSION] morning alarm already completed today — ignore trigger',
    );
    return;
  }
  if (nativeOwnsMorningSound) {
    // AlarmKit (iOS 26+) and the Android native audio service own the alert
    // sound on their platforms — never start the in-app loop on top of them.
    await AlarmSessionService.instance.activateMorningAlarmSession(
      alarmId: alarmId,
    );
  }
  if (AlarmSessionService.instance.isBlockingUiVisible) {
    final phase = AlarmSessionService.instance.liveAlarmUiPhase;
    // A ringing/mission UI is already up — never stack a second mission on
    // top of it. While still in the pre-record ringing phase, just make sure
    // the alarm is audible again (retry re-fires land here).
    //
    // Exception: after Amen, the completed screen can still be on the same
    // /morning-alarm route while the next close alarm fires. In that success
    // phase, replace it with the new alarm's mission instead of dropping the
    // pending mission and waiting for the retry ladder.
    if (phase != LiveAlarmUiPhase.success) {
      if (phase == LiveAlarmUiPhase.ringing && !nativeOwnsMorningSound) {
        await AlarmSoundService.instance.start();
      }
      return;
    }
  }
  if (!nativeOwnsMorningSound) {
    if (AlarmSessionService.instance.isBlockingUiVisible &&
        AlarmSessionService.instance.liveAlarmUiPhase ==
            LiveAlarmUiPhase.ringing) {
      await AlarmSoundService.instance.start();
    } else {
      // Legacy iOS: start the in-app alarm loop so the alarm keeps ringing
      // until the mission's auto-record takes over the microphone.
      await AlarmPersistenceService.onAlarmFired(
        AlarmNotificationService.morningAlarmPayload,
      );
    }
  }

  if (!AppLaunchState.bootComplete) {
    debugPrint('[MISSION] boot not complete; AppLaunchGate will force mission');
    return;
  }

  final nav = navigatorKey.currentState;
  if (nav == null) {
    debugPrint('[MISSION] navigator not ready for direct mission push');
    return;
  }

  // Stay in ringing phase — the mission UI is up, but the user hasn't started
  // the prayer action yet. SimpleMission switches to listening when the user
  // taps record / typing (alarm sound must stay on until then).
  AlarmSessionService.instance
    ..setBlockingUiVisible(true)
    ..setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);

  await nav.pushAndRemoveUntil(
    liveAlarmPageRoute<void>(
      settings: const RouteSettings(name: '/morning-alarm'),
      builder: (_) => SimpleMorningMissionScreen(
        alarmId: alarmId,
        onCompleted: () {
          AlarmSessionService.instance.setBlockingUiVisible(false);
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const AppLaunchGate()),
            (_) => false,
          );
        },
      ),
    ),
    (_) => false,
  );
}

Future<void> _openEveningMissionNow(
  String reason, {
  bool forceFromPending = false,
}) async {
  debugPrint('$reason → push evening blessing mission');
  if (!forceFromPending &&
      await AlarmSessionService.instance.hasCompletedEveningToday()) {
    debugPrint('[MISSION] evening blessing already completed today');
    return;
  }

  if (AlarmSessionService.instance.isBlockingUiVisible &&
      AlarmSessionService.instance.liveAlarmUiPhase !=
          LiveAlarmUiPhase.success) {
    debugPrint('[MISSION] live alarm UI already visible; skip evening push');
    return;
  }

  if (!AppLaunchState.bootComplete) {
    debugPrint('[MISSION] boot not complete; AppLaunchGate will force evening');
    return;
  }

  final nav = navigatorKey.currentState;
  if (nav == null) {
    debugPrint('[MISSION] navigator not ready for evening mission push');
    return;
  }

  await AlarmSessionService.instance.activateEveningAlarmSession();
  await AlarmSoundService.instance.stop();
  AlarmSessionService.instance
    ..setBlockingUiVisible(true)
    ..setLiveAlarmUiPhase(LiveAlarmUiPhase.listening);

  await nav.pushAndRemoveUntil(
    liveAlarmPageRoute<void>(
      settings: const RouteSettings(name: '/evening-alarm'),
      builder: (_) => SimpleMorningMissionScreen(
        kind: MissionKind.evening,
        onCompleted: () {
          AlarmSessionService.instance.setBlockingUiVisible(false);
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const AppLaunchGate()),
            (_) => false,
          );
        },
      ),
    ),
    (_) => false,
  );
}

/// Called by AlarmRingingScreen's dismiss button — swap it for the prayer mission.
/// pushReplacement so popping the mission returns to home, not back to ringing.
Future<void> _pushMissionFromRinging(String payload) async {
  debugPrint('[MISSION] _pushMissionFromRinging called payload=$payload');
  final isMorning = payload == AlarmNotificationService.morningAlarmPayload;
  final isEvening = payload == AlarmNotificationService.eveningAlarmPayload;
  if (!isMorning && !isEvening) return;

  final nav = navigatorKey.currentState;
  if (nav == null) {
    debugPrint('[MISSION] navigator unavailable — abort');
    return;
  }

  if (isMorning) {
    // MVP: route morning into the simple mission screen (prayer + verse + record + Amen).
    await nav.pushReplacement(
      liveAlarmPageRoute<void>(
        settings: const RouteSettings(name: '/morning-alarm'),
        builder: (_) => SimpleMorningMissionScreen(
          onCompleted: () {
            AlarmSessionService.instance.setBlockingUiVisible(false);
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const AppLaunchGate()),
              (_) => false,
            );
          },
        ),
      ),
    );
  } else {
    await nav.pushReplacement(
      liveAlarmPageRoute<void>(
        settings: const RouteSettings(name: '/evening-alarm'),
        builder: (_) =>
            const SimpleMorningMissionScreen(kind: MissionKind.evening),
      ),
    );
  }
}

class MeansOfGraceApp extends StatefulWidget {
  const MeansOfGraceApp({super.key});

  @override
  State<MeansOfGraceApp> createState() => _MeansOfGraceAppState();
}

class _MeansOfGraceAppState extends State<MeansOfGraceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocaleService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocaleService.instance.removeListener(_onLocaleChanged);
    if (!kIsWeb) {
      AlarmFireWatchdog.instance.stop();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppLaunchState.bootComplete) return;
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(_handleAppResumed());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AppPersistenceService.flushAll();
    }
  }

  /// On resume: if a live alarm is currently locking the app, do NOT call
  /// ensureScheduled — it would cancel the ringing alarm + the in-mission
  /// watchdog (same id 100001) and reschedule them for the next day.
  /// Only re-enforce the lock UI and reload persisted state.
  Future<void> _handleAppResumed() async {
    final morningLocked = await AlarmSessionService.instance
        .isMorningAppLocked();
    final eveningLocked = morningLocked
        ? false
        : await AlarmSessionService.instance.isEveningAppLocked();

    if (morningLocked || eveningLocked) {
      debugPrint('[RESUME] live alarm locked — skip ensureScheduled');
      await _enforceAlarmIfNeeded();
      await AppPersistenceService.reloadAll();
      return;
    }

    await AlarmScheduleHelper.ensureScheduled();
    await _enforceAlarmIfNeeded();
    await AppPersistenceService.reloadAll();
  }

  Future<void> _enforceAlarmIfNeeded() async {
    if (!AppLaunchState.bootComplete) return;

    if (await AlarmSessionService.instance.isMorningAppLocked()) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/morning-alarm' || routeName == '/morning-ringing') {
        return;
      }
      if (AlarmSessionService.instance.isBlockingUiVisible) return;

      await _openAlarmFromNotification(
        AlarmNotificationService.morningAlarmPayload,
      );
      return;
    }

    if (await AlarmSessionService.instance.isEveningAppLocked()) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/evening-alarm' || routeName == '/evening-ringing') {
        return;
      }
      if (AlarmSessionService.instance.isBlockingUiVisible) return;

      await _openAlarmFromNotification(
        AlarmNotificationService.eveningAlarmPayload,
      );
    }
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'God Morning',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.dark,
      locale: LocaleService.instance.locale,
      supportedLocales: LocaleService.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppLaunchGate(),
    );
  }
}
