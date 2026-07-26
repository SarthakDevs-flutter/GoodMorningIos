import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/app_page_route.dart';
import '../l10n/app_localizations.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/native_alarm_service.dart';
import '../services/prayer_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_sound_settings_section.dart';
import '../widgets/inline_alarm_time_wheel.dart';
import 'simple_morning_mission_screen.dart';

/// Full-screen black evening blessing setup — time, on/off, and alarm sound.
class EveningBlessingSetupScreen extends StatefulWidget {
  const EveningBlessingSetupScreen({super.key});

  @override
  State<EveningBlessingSetupScreen> createState() =>
      _EveningBlessingSetupScreenState();
}

class _EveningBlessingSetupScreenState extends State<EveningBlessingSetupScreen>
    with SingleTickerProviderStateMixin {
  late TimeOfDay _time;
  bool _enabled = true;
  bool _loading = true;
  bool _timeWheelExpanded = false;
  // 휠 위젯 인스턴스 캐시 — 칸(디텐트)마다 오는 setState가 휠 서브트리를
  // 재구성해 스크롤이 앞뒤로 튕기던 버그의 수리. 동일 인스턴스를 돌려주면
  // 프레임워크가 그 서브트리 리빌드를 건너뛴다.
  InlineAlarmTimeWheel? _wheelCache;
  // 시간 라벨 전용 실시간 알림 — 라벨은 돌리는 중에도 진실해야 한다.
  // 정착 전 라벨이 이전 값을 보여주는 사이 저장을 누르면 화면(7:50)과
  // 다른 값(7:51)이 저장되던 실사용 사고(2026-07-10 아침)의 수리.
  // 라벨 Text만 이 노티파이어로 갱신되므로 휠 서브트리는 여전히 무접촉.
  late final ValueNotifier<TimeOfDay> _timeListenable;
  double _blessingPassThreshold =
      PrayerPreferencesService.defaultBlessingPassThreshold;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    AlarmSessionService.instance.setSetupScreenActive(true);
    _time = const TimeOfDay(
      hour: AlarmPreferences.defaultEveningHour,
      minute: AlarmPreferences.defaultEveningMinute,
    );
    _timeListenable = ValueNotifier(_time);
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    AlarmSessionService.instance.setSetupScreenActive(false);
    _pulseController.dispose();
    _timeListenable.dispose();
    unawaited(AlarmSoundService.instance.stop());
    super.dispose();
  }

  Future<void> _load() async {
    final hour = await AlarmPreferences.getEveningHour();
    final minute = await AlarmPreferences.getEveningMinute();
    final enabled = await AlarmPreferences.isEveningEnabled();
    final blessingPassThreshold =
        await PrayerPreferencesService.getBlessingPassThreshold();
    if (!mounted) return;
    setState(() {
      _time = TimeOfDay(hour: hour, minute: minute);
      _timeListenable.value = _time;
      _enabled = enabled;
      _blessingPassThreshold = blessingPassThreshold;
      _loading = false;
    });
  }

  Future<void> _saveTime({TimeOfDay? time, bool showFeedback = true}) async {
    final next = time ?? _time;
    final saved = await AlarmScheduleHelper.saveEvening(
      hour: next.hour,
      minute: next.minute,
      enabled: _enabled,
    );
    if (!mounted) return;
    if (!saved) {
      // 미션 완료 전 끄기 거부 — 토글을 되돌리고 이유를 보여준다.
      setState(() => _enabled = true);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.eveningAlarmMustComplete)));
      return;
    }
    if (!showFeedback) return;
    _showSavedFeedback();
  }

  void _setEnabled(bool value) {
    setState(() => _enabled = value);
  }

  void _toggleTimeWheel() {
    setState(() {
      _timeWheelExpanded = !_timeWheelExpanded;
      // 접을 때 캐시를 비워 다음 펼침이 현재 시각으로 다시 시드되게 한다.
      if (!_timeWheelExpanded) _wheelCache = null;
    });
  }

  Widget _inlineWheel(bool use24Hour) {
    final cached = _wheelCache;
    if (cached == null || cached.use24Hour != use24Hour) {
      _wheelCache = InlineAlarmTimeWheel(
        initialTime: _time,
        use24Hour: use24Hour,
        // 돌리는 중 화면 setState는 금지(실기기 널뛰기 원인)지만, 시간
        // 라벨만은 노티파이어로 즉시 진실하게 — 라벨과 저장값은 어떤
        // 순간에도 같아야 한다(2026-07-10 7:50→7:51 저장 사고).
        onChanged: (next) {
          _time = next;
          _timeListenable.value = next;
        },
        onInteractionEnd: () {
          if (mounted) setState(() {});
        },
      );
    }
    return _wheelCache!;
  }

  Future<void> _saveBlessingPassThreshold(double value) async {
    final rounded = ((value * 100).round() / 100).clamp(0.0, 1.0);
    setState(() => _blessingPassThreshold = rounded);
    await PrayerPreferencesService.setBlessingPassThreshold(rounded);
    final enabled = await AlarmPreferences.isEveningEnabled();
    final hour = await AlarmPreferences.getEveningHour();
    final minute = await AlarmPreferences.getEveningMinute();
    final now = DateTime.now();
    final nextFire = DateTime(now.year, now.month, now.day, hour, minute);
    if (enabled && nextFire.isAfter(now)) {
      await AlarmSessionService.instance.clearEveningCompleted();
      await NativeAlarmService.clearEveningMissionCompleted();
    }
  }

  void _showSavedFeedback() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.alarmsSaved)));
  }

  Future<void> _previewBlessing() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute<void>(
        builder: (_) => const SimpleMorningMissionScreen(
          kind: MissionKind.evening,
          practiceMode: true,
        ),
      ),
    );
  }

  Widget _buildBlessingPreview(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border.all(
          color: AppTheme.surfaceLight.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: 0.45,
              end: 1.0,
            ).animate(_pulseController),
            child: const Icon(
              Icons.nightlight_round,
              color: AppTheme.text,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _toggleTimeWheel,
            // 높이 고정 + 한 줄 강제: '오후 10:50' 같은 두 자리 시가 폭을
            // 넘어 두 줄로 접히면 카드가 커져 아래 휠을 밀어낸다 — 돌리는
            // 중 시가 9↔10을 오가면 접힘이 반복되며 휠이 왔다갔다 하던
            // 실기기 버그. 넘치면 줄바꿈 대신 살짝 축소한다.
            child: SizedBox(
              height: 76,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ValueListenableBuilder<TimeOfDay>(
                  valueListenable: _timeListenable,
                  builder: (context, time, _) => Text(
                    AlarmPreferences.formatTime(time.hour, time.minute),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      color: _enabled ? AppTheme.text : AppTheme.textMuted,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.blessBeforeRest,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.eveningBlessingSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
          if (!_enabled) ...[
            const SizedBox(height: 10),
            Text(
              l10n.eveningBlessingOffHint,
              style: const TextStyle(fontSize: 13, color: AppTheme.off),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePicker(AppLocalizations l10n) {
    final use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.setAlarmTime,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: InkWell(
              onTap: _toggleTimeWheel,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bg.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 높이 고정 + 넘치면 축소 — 두 자리 시에서도 배치 불변.
                    Flexible(
                      child: SizedBox(
                        height: 58,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ValueListenableBuilder<TimeOfDay>(
                            valueListenable: _timeListenable,
                            builder: (context, time, _) => Text(
                              AlarmPreferences.formatTime(
                                time.hour,
                                time.minute,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      _timeWheelExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              l10n.tapTimeToSetAlarm,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !_timeWheelExpanded
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('evening-inline-time-wheel'),
                    padding: const EdgeInsets.only(top: 16),
                    child: _inlineWheel(use24Hour),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _missionPassThresholdCard(AppLocalizations l10n) {
    final percent = (_blessingPassThreshold * 100).round();
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
            value: _blessingPassThreshold.clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.surfaceLight,
            onChanged: (value) {
              setState(() => _blessingPassThreshold = value);
            },
            onChangeEnd: (value) =>
                unawaited(_saveBlessingPassThreshold(value)),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppTheme.textMuted,
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: l10n.backToMain,
        ),
        title: Text(
          l10n.eveningChildrenBlessing,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _buildBlessingPreview(l10n),
                  const SizedBox(height: 24),
                  _buildTimePicker(l10n),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.enableEveningBlessing,
                      style: const TextStyle(color: AppTheme.text),
                    ),
                    subtitle: Text(
                      l10n.eveningBlessingSubtitle,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    value: _enabled,
                    activeThumbColor: AppTheme.accent,
                    onChanged: _setEnabled,
                  ),
                  const SizedBox(height: 20),
                  _missionPassThresholdCard(l10n),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 28),
                    const Divider(color: AppTheme.surfaceLight),
                    const SizedBox(height: 20),
                    AlarmSoundSettingsSection(
                      onChanged: (source) {
                        unawaited(_saveTime(showFeedback: false));
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _previewBlessing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.text,
                        foregroundColor: AppTheme.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.previewEveningBlessing,
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
      // 저장은 스크롤 끝이 아니라 화면 하단에 항상 고정.
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => unawaited(_saveTime()),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      l10n.saveAlarms,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.text,
                      foregroundColor: AppTheme.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
