import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/completion_history_service.dart';
import '../services/alarm_store.dart';
import '../services/streak_service.dart';
import '../theme/app_theme.dart';

/// 기록 달력 — 미션(아멘)을 완료한 날이 자동으로 표시된다.
/// 하루에 여러 알람을 완료하면 점이 여러 개 붙는다.
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  static const _englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late DateTime _month; // 항상 해당 달의 1일
  Map<int, int> _counts = {};
  // 자녀 축복 완료(저녁) — 자녀 아이콘 표시용.
  Map<int, int> _eveningCounts = {};
  int _streak = 0;
  int _eveningStreak = 0;
  int _totalDays = 0;
  // 놓친 날(😢) 판정용: 현재 알람들이 울리는 요일 + 기록이 시작된 날.
  Set<int> _alarmWeekdays = {};
  DateTime? _earliestRecord;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    await CompletionHistoryService.backfillFromStreakIfEmpty();
    final counts = await CompletionHistoryService.monthCounts(
      _month.year,
      _month.month,
    );
    final eveningCounts = await CompletionHistoryService.eveningMonthCounts(
      _month.year,
      _month.month,
    );
    final streak = await StreakService.getCurrentStreak();
    final eveningStreak = await CompletionHistoryService.eveningStreak();
    final totalDays = await CompletionHistoryService.totalDays();
    final earliest = await CompletionHistoryService.earliestDate();
    final alarms = await AlarmStore.loadAlarms();
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _eveningCounts = eveningCounts;
      _streak = streak;
      _eveningStreak = eveningStreak;
      _totalDays = totalDays;
      _earliestRecord = earliest;
      _alarmWeekdays = alarms
          .where((a) => a.enabled)
          .expand((a) => a.weekdays)
          .toSet();
      _loading = false;
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _loading = true;
    });
    _load();
  }

  String _monthLabel(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    if (isKorean) return '${_month.year}년 ${_month.month}월';
    return '${_englishMonths[_month.month - 1]} ${_month.year}';
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('😇', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _streak > 0
                          ? l10n.streakDays(_streak)
                          : l10n.streakStartToday,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _totalDays > 0
                          ? l10n.streakTotalDays(_totalDays)
                          : l10n.streakCalendarSubtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 12),
          // 자녀 축복(저녁) 연속 기록 — 모닝 아래 한 줄(딸+아들 페어).
          Row(
            children: [
              const Text('👧🧒', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _eveningStreak > 0
                      ? l10n.eveningStreakDays(_eveningStreak)
                      : l10n.eveningStreakStart,
                  style: TextStyle(
                    color: _eveningStreak > 0
                        ? AppTheme.text
                        : AppTheme.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppTheme.textMuted,
          ),
        ),
        SizedBox(
          width: 150,
          child: Text(
            _monthLabel(context),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
          icon: Icon(
            Icons.chevron_right_rounded,
            color: _isCurrentMonth
                ? AppTheme.surfaceLight
                : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(AppLocalizations l10n) {
    final labels = [
      l10n.weekdayShortMonday,
      l10n.weekdayShortTuesday,
      l10n.weekdayShortWednesday,
      l10n.weekdayShortThursday,
      l10n.weekdayShortFriday,
      l10n.weekdayShortSaturday,
      l10n.weekdayShortSunday,
    ];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(int day) {
    final now = DateTime.now();
    final date = DateTime(_month.year, _month.month, day);
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    final count = _counts[day] ?? 0;
    final completed = count > 0;
    final blessed = (_eveningCounts[day] ?? 0) > 0;
    // 놓친 날: 기록이 시작된 이후의 지난 날 중, 알람이 울리는 요일인데
    // 완료 기록이 없는 날.
    final earliest = _earliestRecord;
    final missed = !completed &&
        !isFuture &&
        !isToday &&
        earliest != null &&
        !date.isBefore(earliest) &&
        _alarmWeekdays.contains(date.weekday);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(
                          color: AppTheme.accent.withValues(
                            alpha: completed ? 0.55 : 1.0,
                          ),
                          width: 1.6,
                        )
                      : null,
                ),
                child: completed
                    // 완료한 날은 웃는 얼굴, 놓친 날은 슬픈 얼굴.
                    ? const Text(
                        '😇',
                        style: TextStyle(fontSize: 24, height: 1.0),
                      )
                    : missed
                    ? const Text('😢', style: TextStyle(fontSize: 22, height: 1.0))
                    : Text(
                        '$day',
                        style: TextStyle(
                          color: isFuture
                              ? AppTheme.textMuted.withValues(alpha: 0.35)
                              : (isToday ? AppTheme.accent : AppTheme.text),
                          fontSize: 15,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
              ),
              // 자녀 축복을 한 날은 자녀 그림(딸+아들)을 함께 표시한다.
              if (blessed)
                const Positioned(
                  right: -7,
                  bottom: -3,
                  child: Text(
                    '👧🧒',
                    style: TextStyle(fontSize: 11, height: 1.0),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
          child: count >= 2
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < (count > 3 ? 3 : count); i++)
                      Container(
                        width: 4.5,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 1.2,
                          vertical: 2.5,
                        ),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final firstWeekday = _month.weekday; // 1=월
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 1; i < firstWeekday; i++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++) _buildDayCell(day),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final rowCells = cells.sublist(
        i,
        i + 7 > cells.length ? cells.length : i + 7,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (var j = 0; j < 7; j++)
                Expanded(
                  child: j < rowCells.length
                      ? Center(child: rowCells[j])
                      : const SizedBox(),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
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
          l10n.streakTitle,
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 10),
                _buildMonthNav(context),
                const SizedBox(height: 4),
                _buildWeekdayHeader(l10n),
                const SizedBox(height: 6),
                _buildGrid(),
              ],
            ),
    );
  }
}
