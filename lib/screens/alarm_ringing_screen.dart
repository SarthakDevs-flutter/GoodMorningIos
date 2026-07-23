import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/native_alarm_service.dart';

enum AlarmRingingKind { morning, evening }

/// Full-screen ringing UI shown before the prayer mission.
/// Pop is blocked. The alarm keeps ringing until the user engages:
/// on Android the morning mission starts when the user unlocks the device
/// (sliding while locked brings up the system unlock UI first); the slide
/// remains as the direct path when the device is already unlocked.
class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({
    super.key,
    required this.kind,
    required this.onStartMission,
  });

  final AlarmRingingKind kind;
  final VoidCallback onStartMission;

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  static const _slideThreshold = 0.82;
  static const _slideHeight = 64.0;
  static const _slidePadding = 4.0;
  static const _slideThumbSize = 56.0;

  late DateTime _now;
  bool _missionStarted = false;
  bool _slideDragging = false;
  double _slideProgress = 0;
  Timer? _clockTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    debugPrint('[RINGING] screen opened kind=${widget.kind}');
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    AlarmSessionService.instance
      ..setBlockingUiVisible(true)
      ..setLiveAlarmUiPhase(LiveAlarmUiPhase.ringing);
    if (_unlockStartsMission) {
      // Android morning: the native alarm audio service has been sounding
      // since the alarm fired and keeps playing through this screen, so the
      // ring is one continuous loop — don't start the in-app player on top.
      // Unlocking the device is what starts the mission (slide also works).
      NativeAlarmService.onDeviceUnlocked = _onDeviceUnlocked;
    } else {
      unawaited(AlarmSoundService.instance.start());
    }
  }

  bool get _unlockStartsMission =>
      widget.kind == AlarmRingingKind.morning &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  void _onDeviceUnlocked() {
    if (!mounted || _missionStarted) return;
    debugPrint('[RINGING] unlock detected → start mission');
    _startMission();
  }

  void _startMission() {
    if (_missionStarted) return;
    _missionStarted = true;
    debugPrint('[RINGING] user started mission kind=${widget.kind}');
    widget.onStartMission();
  }

  Future<void> _triggerMission() async {
    if (_missionStarted) return;
    if (_unlockStartsMission && await NativeAlarmService.isDeviceLocked()) {
      // Slid while still locked — bring up the system unlock UI; the mission
      // starts from the onDeviceUnlocked callback once the user unlocks.
      debugPrint('[RINGING] slide while locked → request keyguard dismiss');
      await NativeAlarmService.requestDismissKeyguard();
      if (mounted) setState(() => _slideProgress = 0);
      return;
    }
    _startMission();
  }

  void _updateSlideProgress(double delta, double maxDrag) {
    if (_missionStarted) return;
    setState(() {
      _slideProgress = (_slideProgress + delta / maxDrag).clamp(0.0, 1.0);
    });
  }

  void _finishSlide() {
    if (_missionStarted) return;
    if (_slideProgress >= _slideThreshold) {
      setState(() {
        _slideProgress = 1;
        _slideDragging = false;
      });
      unawaited(_triggerMission());
      return;
    }
    setState(() {
      _slideProgress = 0;
      _slideDragging = false;
    });
  }

  @override
  void dispose() {
    if (_unlockStartsMission &&
        NativeAlarmService.onDeviceUnlocked == _onDeviceUnlocked) {
      NativeAlarmService.onDeviceUnlocked = null;
    }
    _clockTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _formatClock(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  String _slideLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ko'
        ? '밀어서 말씀과 기도 시작'
        : 'Slide to start prayer';
  }

  Widget _buildSlideToMissionControl(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag =
            (constraints.maxWidth - _slideThumbSize - _slidePadding * 2)
                .clamp(1.0, double.infinity)
                .toDouble();
        final thumbLeft = _slidePadding + maxDrag * _slideProgress;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            if (_missionStarted) return;
            setState(() => _slideDragging = true);
          },
          onHorizontalDragUpdate: (details) {
            _updateSlideProgress(details.primaryDelta ?? 0, maxDrag);
          },
          onHorizontalDragEnd: (_) => _finishSlide(),
          onHorizontalDragCancel: _finishSlide,
          child: SizedBox(
            height: _slideHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _slideProgress.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: (1.0 - _slideProgress * 1.3).clamp(0.18, 1.0),
                    duration: const Duration(milliseconds: 120),
                    child: Text(
                      _slideLabel(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _slideDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: thumbLeft,
                  top: _slidePadding,
                  child: Container(
                    width: _slideThumbSize,
                    height: _slideThumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: Color(0xFF0A0A0A),
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typeLabel = widget.kind == AlarmRingingKind.morning
        ? l10n.stepMorningPrayer
        : l10n.eveningBlessing;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                _formatClock(_now),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.timeToMeetLord,
                style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                typeLabel,
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),
              const Spacer(flex: 2),
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 84,
                ),
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.04).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: _buildSlideToMissionControl(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
