import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/alarm_notification_service.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/app_deferred_startup.dart';
import '../services/app_launch_state.dart';
import '../services/app_bootstrap.dart';
import '../services/native_alarm_service.dart';
import '../services/premium_access_service.dart';
import '../services/prayer_preferences_service.dart';
import '../theme/app_theme.dart';
import 'alarm_ringing_screen.dart';
import 'home_screen.dart';
import 'main_shell.dart';
import 'onboarding/permissions_onboarding_screen.dart';
import 'premium_screen.dart';
import 'simple_morning_mission_screen.dart';
import 'splash_screen.dart';

enum _LaunchPhase { splash, permissions, premium, ready }

enum _AlarmLockKind { none, morning, morningRinging, evening }

class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate>
    with WidgetsBindingObserver {
  _LaunchPhase _phase = _LaunchPhase.splash;
  _AlarmLockKind _alarmLock = _AlarmLockKind.none;
  bool _alarmKitPendingMorningMission = false;
  bool _alarmKitPendingEveningMission = false;
  bool _androidPendingMorningRinging = false;
  bool _premiumRequired = false;
  String? _pendingMorningAlarmId;

  static const _splashDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        precacheImage(const AssetImage('assets/icon/splash_logo.png'), context),
      );
    });
    _boot();
  }

  Future<void> _completeBoot() async {
    _applyBlockingUiForAlarmLock();
    AppLaunchState.markBootComplete();
    await AppDeferredStartup.runAfterLaunchGate();
  }

  Future<void> _boot() async {
    if (kIsWeb) {
      await Future<void>.delayed(_splashDuration);
      if (!mounted) return;
      setState(() => _phase = _LaunchPhase.ready);
      await _completeBoot();
      return;
    }

    final results = await Future.wait([
      Future<void>.delayed(_splashDuration),
      _prepareLaunchState(),
    ]);
    final onboardingDone = results[1] as bool;

    if (!mounted) return;

    setState(
      () => _phase = onboardingDone
          ? _LaunchPhase.ready
          : _LaunchPhase.permissions,
    );
    if (onboardingDone) {
      await _completeBoot();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _phase == _LaunchPhase.ready) {
      unawaited(_checkAlarmLock());
      unawaited(_checkPremiumLock());
    }
  }

  /// Loads onboarding / alarm lock state without leaving the splash screen.
  Future<bool> _prepareLaunchState() async {
    try {
      final onboardingDone = await AppBootstrap.hasCompletedOnboarding();
      if (!onboardingDone) return false;

      await PrayerPreferencesService.ensureFirstUseDate();
      await _consumeAlarmKitPendingMission();
      await _checkAlarmLock(silent: true);
      await _checkPremiumLock(silent: true);
      return true;
    } catch (e, st) {
      debugPrint('Launch gate failed: $e\n$st');
      return true;
    }
  }

  Future<void> _onPermissionsComplete() async {
    await AppBootstrap.markOnboardingComplete();
    final hasAccess = await PremiumAccessService.hasAccess();
    if (!mounted) return;
    if (!hasAccess) {
      setState(() => _phase = _LaunchPhase.premium);
      return;
    }
    await _finishFirstRunAfterPremiumUnlock();
  }

  Future<void> _finishFirstRunAfterPremiumUnlock() async {
    await AppBootstrap.markOnboardingComplete();
    await _prepareLaunchState();
    if (!mounted) return;
    setState(() => _phase = _LaunchPhase.ready);
    await _completeBoot();
  }

  Future<void> _checkAlarmLock({bool silent = false}) async {
    if (kIsWeb) return;
    if (_phase != _LaunchPhase.ready && !silent) return;

    await _consumeAlarmKitPendingMission();

    final morningRequired =
        _androidPendingMorningRinging ||
        _alarmKitPendingMorningMission ||
        await AlarmSessionService.instance.isMorningAppLocked();
    if (morningRequired) {
      await AlarmSessionService.instance.activateMorningAlarmSession();
    }
    final eveningRequired =
        !morningRequired &&
        (_alarmKitPendingEveningMission ||
            await AlarmSessionService.instance.isEveningAppLocked());
    if (eveningRequired) {
      await AlarmSessionService.instance.activateEveningAlarmSession();
    }
    debugPrint('[GATE] morning=$morningRequired evening=$eveningRequired');
    // 화면이 안 보이는 상태(잠금 뒤/화면 꺼짐)에서 미션을 강제로 여는 경우 =
    // 전원 버튼으로 알람만 죽인 채 잠들어 있다는 뜻. AlarmKit 추격을 여기서
    // 무장한다 — 인텐트 실행 여부와 무관하게 이 게이트는 확실히 돈다(실측).
    // 사용자가 화면을 실제로 보면(잠금 해제 resumed) 미션 화면이 취소한다.
    // lifecycle(resumed)은 잠금 뒤 포그라운드에서도 참 — 하드웨어 신호 사용.
    final visiblyActive = await NativeAlarmService.isDeviceInteractive();
    if (!visiblyActive) {
      if (morningRequired) {
        debugPrint('[GATE] mission forced while not visible — arm chase');
        unawaited(NativeAlarmService.resumeMorningRetryAfterMissionAbandoned());
        // 융단(10초 간격)은 울리는 지금 이 순간에만 깐다 — 평상시 저장/앱
        // 열기가 알림 수십 건을 만지던 낭비 제거(앱 전체 굼뜸의 원인).
        unawaited(
          AlarmNotificationService.instance.scheduleMorningRingCarpet(
            anchor: DateTime.now(),
          ),
        );
      } else if (eveningRequired) {
        debugPrint('[GATE] evening mission not visible — arm chase');
        unawaited(NativeAlarmService.resumeEveningRetryAfterMissionAbandoned());
        unawaited(
          AlarmNotificationService.instance.scheduleEveningRingCarpet(
            anchor: DateTime.now(),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      if (morningRequired) {
        _alarmLock = _androidPendingMorningRinging
            ? _AlarmLockKind.morningRinging
            : _AlarmLockKind.morning;
      } else if (eveningRequired) {
        _alarmLock = _AlarmLockKind.evening;
      } else {
        _alarmLock = _AlarmLockKind.none;
      }
    });

    if (!silent && _phase == _LaunchPhase.ready) {
      _applyBlockingUiForAlarmLock();
    }
  }

  Future<void> _checkPremiumLock({bool silent = false}) async {
    if (kIsWeb) return;
    if (_phase != _LaunchPhase.ready && !silent) return;

    final hasAccess = await PremiumAccessService.hasAccess();
    final premiumRequired = !hasAccess;
    if (premiumRequired) {
      await AlarmScheduleHelper.pauseScheduledAlarmsForPremiumLock();
    }
    if (!mounted) return;
    setState(() => _premiumRequired = premiumRequired);
  }

  Future<void> _consumeAlarmKitPendingMission() async {
    final pending = await NativeAlarmService.consumePendingMission();
    final kind = pending?.kind;
    if (kind == NativeAlarmKind.morning) {
      // 알람별 완료: 울린 그 알람이 오늘 이미 완료됐을 때만 무시한다.
      if (await AlarmSessionService.instance.isAlarmCompletedToday(
        pending?.alarmId,
      )) {
        return;
      }
      await AlarmSessionService.instance.activateMorningAlarmSession(
        alarmId: pending?.alarmId,
      );
      _pendingMorningAlarmId = pending?.alarmId;
      _alarmKitPendingEveningMission = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Android: ringing screen keeps the alarm sounding; the mission
        // starts when the user unlocks the device (or slides).
        _androidPendingMorningRinging = true;
        _alarmKitPendingMorningMission = false;
      } else {
        _alarmKitPendingMorningMission = true;
        _androidPendingMorningRinging = false;
      }
    } else if (kind == NativeAlarmKind.evening) {
      await AlarmSessionService.instance.activateEveningAlarmSession();
      _alarmKitPendingEveningMission = true;
      _alarmKitPendingMorningMission = false;
      _androidPendingMorningRinging = false;
    }
  }

  void _applyBlockingUiForAlarmLock() {
    if (_alarmLock == _AlarmLockKind.morning ||
        _alarmLock == _AlarmLockKind.morningRinging ||
        _alarmLock == _AlarmLockKind.evening) {
      AlarmSessionService.instance.setBlockingUiVisible(true);
      // 실미션은 게이트 서브트리(루트)에 뜬다 — 연습 미션 등 위에 push된
      // 라우트가 남아 있으면 실미션이 그 '아래'에 깔려 화면이 겹친다.
      // 잠금이 걸리는 순간 루트 위 라우트를 전부 걷는다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      });
    } else {
      AlarmSessionService.instance.setBlockingUiVisible(false);
    }
  }

  void _onAlarmCompleted() {
    _alarmKitPendingMorningMission = false;
    _alarmKitPendingEveningMission = false;
    _androidPendingMorningRinging = false;
    _pendingMorningAlarmId = null;
    AlarmSessionService.instance
      ..setBlockingUiVisible(false)
      ..setLiveAlarmUiPhase(LiveAlarmUiPhase.success);
    if (!mounted) return;
    setState(() => _alarmLock = _AlarmLockKind.none);
    unawaited(_checkPremiumLock());
  }

  Widget _readyScreen() {
    if (_premiumRequired && _alarmLock == _AlarmLockKind.none) {
      return PremiumScreen(
        key: const ValueKey('premium-lock'),
        blocking: true,
        onUnlocked: () => unawaited(_checkPremiumLock()),
      );
    }

    switch (_alarmLock) {
      case _AlarmLockKind.morningRinging:
        debugPrint('[GATE] force morning ringing screen');
        return AlarmRingingScreen(
          key: const ValueKey('morning-ringing'),
          kind: AlarmRingingKind.morning,
          onStartMission: () {
            _androidPendingMorningRinging = false;
            if (!mounted) return;
            setState(() => _alarmLock = _AlarmLockKind.morning);
          },
        );
      case _AlarmLockKind.morning:
        debugPrint('[GATE] force simple morning mission');
        return SimpleMorningMissionScreen(
          key: const ValueKey('simple-morning-mission'),
          alarmId: _pendingMorningAlarmId,
          onCompleted: _onAlarmCompleted,
        );
      case _AlarmLockKind.evening:
        debugPrint('[GATE] force evening blessing mission');
        return SimpleMorningMissionScreen(
          key: const ValueKey('evening-blessing-mission'),
          kind: MissionKind.evening,
          onCompleted: _onAlarmCompleted,
        );
      case _AlarmLockKind.none:
        return const MainShell(key: ValueKey('home'));
    }
  }

  Widget _phaseScreen() {
    return switch (_phase) {
      _LaunchPhase.splash => const SplashScreen(key: ValueKey('splash')),
      _LaunchPhase.permissions => PermissionsOnboardingScreen(
        key: const ValueKey('permissions'),
        onComplete: _onPermissionsComplete,
      ),
      _LaunchPhase.premium => PremiumScreen(
        key: const ValueKey('onboarding-premium'),
        blocking: true,
        onUnlocked: () => unawaited(_finishFirstRunAfterPremiumUnlock()),
      ),
      _LaunchPhase.ready => _readyScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const HomeScreen();
    }

    // 전환 애니메이션 없이 즉시 교체한다. 크로스페이드는 로고 잔상을,
    // 페이드인은 '내용 없는 배경만 보이는 구간'(밝은 검정 번쩍임)을 만든다.
    // 모든 화면의 배경색이 동일해 순간 전환이 가장 깔끔하다.
    return ColoredBox(color: AppTheme.bg, child: _phaseScreen());
  }
}
