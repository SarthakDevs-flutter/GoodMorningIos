import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_sound_preferences.dart';
import '../services/alarm_sound_service.dart';
import '../services/alarm_store.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_sound_settings_section.dart';
import '../widgets/inline_alarm_time_wheel.dart';

/// 알람 하나(시간·요일·켜짐)를 편집하는 화면. [alarm]이 null이면 새 알람.
class MorningAlarmSetupScreen extends StatefulWidget {
  const MorningAlarmSetupScreen({super.key, this.alarm});

  final MorningAlarm? alarm;

  @override
  State<MorningAlarmSetupScreen> createState() =>
      _MorningAlarmSetupScreenState();
}

class _MorningAlarmSetupScreenState extends State<MorningAlarmSetupScreen> {
  late String _alarmId;
  late TimeOfDay _time;
  bool _enabled = true;
  Set<int> _weekdays = AlarmPreferences.defaultWeekdays.toSet();
  bool _loading = true;
  bool _timeWheelExpanded = false;
  // 휠 위젯 인스턴스 캐시 — 칸(디텐트)마다 오는 setState가 휠 서브트리를
  // 재구성해 스크롤이 앞뒤로 튕기던 버그의 수리(저녁 설정과 동일).
  InlineAlarmTimeWheel? _wheelCache;
  // 시간 라벨 전용 실시간 알림 — 돌리는 중에도 라벨=저장값 (2026-07-10
  // 7:50 설정이 7:51로 저장되던 사고의 수리, 저녁과 동일).
  late final ValueNotifier<TimeOfDay> _timeListenable;
  // 이 알람만의 알람음(null = 전역 설정 따름).
  String? _soundName;
  // 새 알람은 저장 버튼을 누르기 전까지 목록에 추가하지 않는다.
  bool _addedToList = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _alarmId = alarm?.id ?? AlarmStore.newAlarmId();
    _time = TimeOfDay(
      hour: alarm?.hour ?? AlarmPreferences.defaultHour,
      minute: alarm?.minute ?? AlarmPreferences.defaultMinute,
    );
    _timeListenable = ValueNotifier(_time);
    _enabled = alarm?.enabled ?? true;
    _weekdays = (alarm?.weekdays ?? AlarmPreferences.defaultWeekdays).toSet();
    _soundName = alarm?.soundName;
    _loading = false;
  }

  @override
  void dispose() {
    _timeListenable.dispose();
    unawaited(AlarmSoundService.instance.stop());
    super.dispose();
  }

  MorningAlarm _currentAlarm({bool? enabled}) {
    return MorningAlarm(
      id: _alarmId,
      hour: _time.hour,
      minute: _time.minute,
      weekdays: _weekdays.toList()..sort(),
      enabled: enabled ?? _enabled,
      soundName: _soundName,
    );
  }

  bool get _isNewAlarm => widget.alarm == null && !_addedToList;

  /// 이 알람을 목록에 반영(추가/수정)하고 전체를 재예약한다.
  /// 새 알람은 저장 버튼을 누르기 전까지는 반영하지 않는다.
  Future<void> _persist({bool? enabled, bool force = false}) async {
    if (_isNewAlarm && !force) return;
    final alarms = await AlarmStore.loadAlarms();
    final updated = [
      for (final alarm in alarms)
        if (alarm.id != _alarmId) alarm,
      _currentAlarm(enabled: enabled),
    ];
    await AlarmScheduleHelper.saveAlarms(updated);
    _addedToList = true;
  }

  Future<void> _saveAlarm() async {
    await _persist(force: true);
    if (!mounted) return;
    await _showScheduledFeedback();
  }

  Future<void> _setEnabled(bool value) async {
    if (!value &&
        await AlarmSessionService.instance.isMorningCompletionRequired()) {
      if (!mounted) return;
      setState(() => _enabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).morningAlarmMustComplete),
        ),
      );
      return;
    }
    setState(() => _enabled = value);
    await _persist(enabled: value);
  }

  Future<void> _setWeekday(int weekday, bool selected) async {
    final next = Set<int>.from(_weekdays);
    if (selected) {
      next.add(weekday);
    } else {
      next.remove(weekday);
    }
    if (next.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).selectAtLeastOneAlarmDay),
        ),
      );
      return;
    }
    setState(() => _weekdays = next);
    await _persist();
  }

  Future<void> _showScheduledFeedback() async {
    final l10n = AppLocalizations.of(context);
    final status = await AlarmNotificationService.instance
        .scheduleFromPreferences();
    if (!mounted) return;
    if (!status.notificationsEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enableNotificationsToRing)));
      return;
    }
    final alarms = await AlarmStore.loadAlarms();
    final next = AlarmStore.nextOccurrence(alarms, DateTime.now());
    if (!mounted || next == null) return;
    final label = AlarmPreferences.formatTime(next.hour, next.minute);
    final now = DateTime.now();
    final isToday =
        next.year == now.year && next.month == now.month && next.day == now.day;
    final dayHint = isToday
        ? ''
        : ' (${_weekdayShortLabel(l10n, next.weekday)})';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.alarmScheduledNext('$label$dayHint'))),
    );
  }

  String _weekdayShortLabel(AppLocalizations l10n, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return l10n.weekdayShortMonday;
      case DateTime.tuesday:
        return l10n.weekdayShortTuesday;
      case DateTime.wednesday:
        return l10n.weekdayShortWednesday;
      case DateTime.thursday:
        return l10n.weekdayShortThursday;
      case DateTime.friday:
        return l10n.weekdayShortFriday;
      case DateTime.saturday:
        return l10n.weekdayShortSaturday;
      default:
        return l10n.weekdayShortSunday;
    }
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
                    // 높이 고정 + 넘치면 축소 — 두 자리 시에서도 배치 불변
                    // (저녁 휠 널뛰기의 뿌리였던 '라벨 줄바꿈' 차단).
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
                    key: const ValueKey('inline-time-wheel'),
                    padding: const EdgeInsets.only(top: 16),
                    child: _inlineWheel(use24Hour),
                  ),
          ),
        ],
      ),
    );
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
        // 돌리는 중 화면 setState는 금지(널뛰기 원인)지만 시간 라벨만은
        // 노티파이어로 즉시 진실하게 — 라벨과 저장값은 항상 같아야 한다.
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

  Widget _buildWeekdaySelector(AppLocalizations l10n) {
    final days = <({int value, String label})>[
      (value: DateTime.monday, label: l10n.weekdayShortMonday),
      (value: DateTime.tuesday, label: l10n.weekdayShortTuesday),
      (value: DateTime.wednesday, label: l10n.weekdayShortWednesday),
      (value: DateTime.thursday, label: l10n.weekdayShortThursday),
      (value: DateTime.friday, label: l10n.weekdayShortFriday),
      (value: DateTime.saturday, label: l10n.weekdayShortSaturday),
      (value: DateTime.sunday, label: l10n.weekdayShortSunday),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.repeatDays,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final selected = _weekdays.contains(day.value);
            return FilterChip(
              label: Text(day.label),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppTheme.accent,
              backgroundColor: AppTheme.surface,
              side: BorderSide(
                color: selected ? AppTheme.accent : AppTheme.surfaceLight,
              ),
              labelStyle: TextStyle(
                color: selected ? AppTheme.bg : AppTheme.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              onSelected: (value) => _setWeekday(day.value, value),
            );
          }).toList(),
        ),
      ],
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
          l10n.morningAlarm,
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  _buildTimePicker(l10n),
                  const SizedBox(height: 20),
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
                    value: _enabled,
                    activeThumbColor: AppTheme.accent,
                    onChanged: _setEnabled,
                  ),
                  const SizedBox(height: 12),
                  _buildWeekdaySelector(l10n),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 28),
                    const Divider(color: AppTheme.surfaceLight),
                    const SizedBox(height: 20),
                    AlarmSoundSettingsSection(
                      // 알람별 소리: 이 알람에만 저장, 전역 설정은 그대로.
                      initialSource: AlarmSoundPreferences.sourceForFileName(
                        _soundName,
                      ),
                      persistGlobal: false,
                      onChanged: (source) {
                        setState(
                          () => _soundName = AlarmSoundPreferences.fileNameFor(
                            source,
                          ),
                        );
                        // 기존 알람은 즉시 반영(새 알람은 저장 버튼에서).
                        unawaited(_persist());
                      },
                    ),
                  ],
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
                  child: ElevatedButton(
                    onPressed: _saveAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.text,
                      foregroundColor: AppTheme.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.save,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
