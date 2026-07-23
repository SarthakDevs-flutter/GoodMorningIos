import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../navigation/app_page_route.dart';
import '../services/alarm_preferences.dart';
import '../services/alarm_schedule_helper.dart';
import '../services/alarm_session_service.dart';
import '../services/alarm_store.dart';
import '../theme/app_theme.dart';
import 'morning_alarm_setup_screen.dart';

/// 아침 알람 목록 — 여러 개의 알람을 추가·수정·삭제·토글한다.
/// 각 알람은 자기 미션 완료를 따로 가진다(같은 날 여러 번 가능).
class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  List<MorningAlarm> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alarms = await AlarmStore.loadAlarms();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _loading = false;
    });
  }

  Future<void> _openEditor([MorningAlarm? alarm]) async {
    if (alarm == null && _alarms.length >= AlarmStore.maxAlarms) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.maxAlarmsReached)));
      return;
    }
    await Navigator.of(context).push(
      appPageRoute<void>(builder: (_) => MorningAlarmSetupScreen(alarm: alarm)),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _setAlarmEnabled(MorningAlarm alarm, bool enabled) async {
    if (!enabled &&
        await AlarmSessionService.instance.hasActiveMorningSessionToday()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).morningAlarmMustComplete),
        ),
      );
      return;
    }
    final updated = AlarmStore.sortedByTime([
      for (final a in _alarms)
        a.id == alarm.id ? a.copyWith(enabled: enabled) : a,
    ]);
    setState(() => _alarms = updated);
    await AlarmScheduleHelper.saveAlarms(updated);
    if (mounted) await _load();
  }

  Future<void> _deleteAlarm(MorningAlarm alarm) async {
    final l10n = AppLocalizations.of(context);
    if (await AlarmSessionService.instance.hasActiveMorningSessionToday()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.morningAlarmMustComplete)));
      return;
    }
    if (!mounted) return;
    if (_alarms.length <= 1) {
      // 마지막 알람은 지우는 대신 끄도록 안내한다.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteLastAlarm)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          l10n.deleteAlarmTitle,
          style: const TextStyle(color: AppTheme.text, fontSize: 17),
        ),
        content: Text(
          AlarmPreferences.formatTime(alarm.hour, alarm.minute),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.deleteAlarmTitle,
              style: const TextStyle(color: AppTheme.off),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = _alarms.where((a) => a.id != alarm.id).toList();
    setState(() => _alarms = updated);
    await AlarmScheduleHelper.saveAlarms(updated);
    if (mounted) await _load();
  }

  String _weekdaySummary(AppLocalizations l10n, List<int> weekdays) {
    if (weekdays.length == 7) return l10n.everyDay;
    final labels = <int, String>{
      DateTime.monday: l10n.weekdayShortMonday,
      DateTime.tuesday: l10n.weekdayShortTuesday,
      DateTime.wednesday: l10n.weekdayShortWednesday,
      DateTime.thursday: l10n.weekdayShortThursday,
      DateTime.friday: l10n.weekdayShortFriday,
      DateTime.saturday: l10n.weekdayShortSaturday,
      DateTime.sunday: l10n.weekdayShortSunday,
    };
    return (weekdays.toList()..sort()).map((d) => labels[d]).join(' ');
  }

  Widget _buildAlarmCard(AppLocalizations l10n, MorningAlarm alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alarm.enabled
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.surfaceLight,
        ),
      ),
      child: InkWell(
        onTap: () => unawaited(_openEditor(alarm)),
        onLongPress: () => unawaited(_deleteAlarm(alarm)),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AlarmPreferences.formatTime(alarm.hour, alarm.minute),
                      style: TextStyle(
                        color: alarm.enabled
                            ? AppTheme.text
                            : AppTheme.textMuted,
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _weekdaySummary(l10n, alarm.weekdays),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => unawaited(_deleteAlarm(alarm)),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
                tooltip: l10n.deleteAlarmTitle,
              ),
              Switch(
                value: alarm.enabled,
                activeThumbColor: AppTheme.accent,
                onChanged: (value) => unawaited(_setAlarmEnabled(alarm, value)),
              ),
            ],
          ),
        ),
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
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: AppTheme.textMuted,
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: l10n.backToMain,
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          l10n.alarmsTitle,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_openEditor()),
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.bg,
        tooltip: l10n.addAlarm,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
              children: [
                for (final alarm in _alarms) _buildAlarmCard(l10n, alarm),
                const SizedBox(height: 8),
                Text(
                  l10n.alarmListHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
    );
  }
}
