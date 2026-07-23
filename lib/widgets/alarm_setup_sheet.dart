import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/app_page_route.dart';
import '../l10n/app_localizations.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../theme/app_theme.dart';
import '../screens/alarm_screen.dart';
import '../screens/evening_blessing_screen.dart';
import 'alarm_sound_settings_section.dart';

enum AlarmSetupKind { morning, evening }

/// Tap morning/evening on home → set time, on/off, and alarm sound in one place.
class AlarmSetupSheet extends StatefulWidget {
  const AlarmSetupSheet({super.key, required this.kind});

  final AlarmSetupKind kind;

  static Future<void> show(
    BuildContext context, {
    required AlarmSetupKind kind,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return AlarmSetupSheet(kind: kind);
        },
      ),
    );
  }

  @override
  State<AlarmSetupSheet> createState() => _AlarmSetupSheetState();
}

class _AlarmSetupSheetState extends State<AlarmSetupSheet> {
  late TimeOfDay _time;
  late bool _enabled;
  bool _loading = true;

  bool get _isMorning => widget.kind == AlarmSetupKind.morning;

  @override
  void initState() {
    super.initState();
    _time = TimeOfDay(
      hour: _isMorning
          ? AlarmPreferences.defaultHour
          : AlarmPreferences.defaultEveningHour,
      minute: _isMorning
          ? AlarmPreferences.defaultMinute
          : AlarmPreferences.defaultEveningMinute,
    );
    _enabled = true;
    _load();
  }

  Future<void> _load() async {
    if (_isMorning) {
      _time = TimeOfDay(
        hour: await AlarmPreferences.getHour(),
        minute: await AlarmPreferences.getMinute(),
      );
      _enabled = await AlarmPreferences.isEnabled();
    } else {
      _time = TimeOfDay(
        hour: await AlarmPreferences.getEveningHour(),
        minute: await AlarmPreferences.getEveningMinute(),
      );
      _enabled = await AlarmPreferences.isEveningEnabled();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(data: AppTheme.timePickerTheme(context), child: child!);
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    if (_isMorning) {
      await AlarmScheduleHelper.saveMorning(
        hour: picked.hour,
        minute: picked.minute,
        enabled: _enabled,
      );
    } else {
      await AlarmScheduleHelper.saveEvening(
        hour: picked.hour,
        minute: picked.minute,
        enabled: _enabled,
      );
    }
    if (!mounted) return;
    await _showScheduledFeedback(picked.hour, picked.minute);
  }

  Future<void> _setEnabled(bool value) async {
    if (_isMorning &&
        !value &&
        await AlarmSessionService.instance.hasActiveMorningSessionToday()) {
      if (!mounted) return;
      setState(() => _enabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).morningAlarmMustComplete),
        ),
      );
      return;
    }
    // 저녁도 대칭: 미션 완료 전 끄기는 거부 + 피드백(무피드백이면 UI는
    // 꺼진 것처럼 보이는데 실제론 켜져 있는 불일치가 남는다).
    if (!_isMorning &&
        !value &&
        await AlarmSessionService.instance.isEveningCompletionRequired()) {
      if (!mounted) return;
      setState(() => _enabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).eveningAlarmMustComplete),
        ),
      );
      return;
    }
    setState(() => _enabled = value);
    if (_isMorning) {
      // 토글일 뿐이니 각 알람의 시간·요일은 그대로 보존한다.
      await AlarmScheduleHelper.setMorningEnabled(value);
    } else {
      await AlarmScheduleHelper.saveEvening(
        hour: _time.hour,
        minute: _time.minute,
        enabled: value,
      );
    }
  }

  Future<void> _showScheduledFeedback(int hour, int minute) async {
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
    final weekdays = _isMorning ? await AlarmPreferences.getWeekdays() : null;
    if (!mounted) return;
    final next = AlarmNotificationService.instance.nextInstanceOfTime(
      hour,
      minute,
      weekdays: weekdays,
    );
    final label = AlarmPreferences.formatTime(next.hour, next.minute);
    final dayHint = next.day == DateTime.now().day ? '' : ' (${l10n.tomorrow})';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.alarmScheduledNext('$label$dayHint'))),
    );
  }

  Future<void> _testAlarm() async {
    final l10n = AppLocalizations.of(context);
    final granted = await AlarmNotificationService.instance.ensurePermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enableNotificationsToRing)));
      return;
    }
    if (_isMorning) {
      await AlarmNotificationService.instance.scheduleTestMorningAlarm();
    } else {
      await AlarmNotificationService.instance.scheduleTestEveningAlarm();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMorning ? l10n.testMorningAlarm : l10n.testEveningAlarm,
        ),
      ),
    );
  }

  Future<void> _previewFlow() async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final hour = _time.hour;
    final minute = _time.minute;
    nav.pop();
    if (_isMorning) {
      await nav.push(
        appPageRoute<void>(
          builder: (_) => AlarmScreen(
            alarmHour: hour,
            alarmMinute: minute,
            isLiveAlarm: false,
          ),
        ),
      );
    } else {
      await nav.push(
        appPageRoute<void>(
          builder: (_) => EveningBlessingScreen(
            alarmHour: hour,
            alarmMinute: minute,
            isLiveAlarm: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isMorning ? l10n.morningAlarm : l10n.eveningBlessing;
    final icon = _isMorning ? Icons.wb_sunny_outlined : Icons.nightlight_round;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      Text(
                        l10n.tapTimeToSetAlarm,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AlarmPreferences.formatTime(
                                  _time.hour,
                                  _time.minute,
                                ),
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w300,
                                  color: AppTheme.text,
                                ),
                              ),
                              const Icon(
                                Icons.access_time,
                                color: AppTheme.accent,
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _isMorning
                              ? l10n.enableMorningAlarm
                              : l10n.enableEveningBlessing,
                          style: const TextStyle(color: AppTheme.text),
                        ),
                        subtitle: Text(
                          _isMorning
                              ? l10n.morningAlarmSubtitle
                              : l10n.eveningBlessingSubtitle,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        value: _enabled,
                        activeThumbColor: AppTheme.accent,
                        onChanged: _setEnabled,
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: 24),
                        const Divider(color: AppTheme.surfaceLight),
                        const SizedBox(height: 16),
                        const AlarmSoundSettingsSection(),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testAlarm,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                            _isMorning
                                ? l10n.testMorningAlarm
                                : l10n.testEveningAlarm,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            side: const BorderSide(color: AppTheme.textMuted),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _previewFlow,
                          child: Text(
                            _isMorning
                                ? l10n.previewMorningAlarm
                                : l10n.previewEveningBlessing,
                            style: const TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
