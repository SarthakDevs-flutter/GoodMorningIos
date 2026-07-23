import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/streak_calendar_screen.dart';
import '../services/streak_service.dart';
import '../theme/app_theme.dart';

class StreakCard extends StatefulWidget {
  const StreakCard({super.key, this.refreshSignal = 0, this.onTap});

  final int refreshSignal;
  final VoidCallback? onTap;

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _load();
    }
  }

  Future<void> _load() async {
    final streak = await StreakService.getCurrentStreak();
    if (mounted) {
      setState(() {
        _streak = streak;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Container(
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF15120D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: AppTheme.accent,
          strokeWidth: 2,
        ),
      );
    }

    final subtitle = _streak > 0
        ? l10n.streakDays(_streak)
        : l10n.streakStartToday;

    return Material(
      color: const Color(0xFF12100D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // 탭하면 기록 달력이 열린다(셸 안에서는 탭 전환).
        onTap: widget.onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StreakCalendarScreen(),
                ),
              );
            },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _streak > 0
                  ? Icons.local_fire_department
                  : Icons.local_fire_department_outlined,
              color: AppTheme.accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.streakTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.1,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: _streak > 0 ? 22 : 14,
                    fontWeight:
                        _streak > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: AppTheme.text,
                    height: 1.3,
                  ),
                ),
              ],
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
