import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'alarm_list_screen.dart';
import 'home_screen.dart';
import 'streak_calendar_screen.dart';

/// 홈·알람·달력·설정을 하단 탭으로 오가는 루트 셸.
/// 바는 항상 고정이고, 홈 탭의 상태는 유지된다.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // 홈 탭으로 돌아올 때마다 올려서 홈이 설정·알람·날씨 상태를 다시 읽게 한다.
  int _homeRefresh = 0;

  void _go(int index) {
    if (_index == index) return;
    setState(() {
      if (index == 0) _homeRefresh++;
      _index = index;
    });
  }

  Widget _currentTab() {
    switch (_index) {
      case 1:
        return const AlarmListScreen();
      case 2:
        return const WeatherScreen();
      case 3:
        return const StreakCalendarScreen();
      case 4:
        return const SettingsScreen(isRootScreen: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      bottomNavigationBar: _QuickNavBar(
        selectedIndex: _index,
        onSelect: _go,
        labels: [
          l10n.homeTab,
          l10n.alarmsTitle,
          l10n.weatherTab,
          l10n.calendarTab,
          l10n.settings,
        ],
      ),
      body: Stack(
        children: [
          // 홈은 상태(날씨 등)를 유지하기 위해 살려 두고 가리기만 한다.
          Offstage(
            offstage: _index != 0,
            child: HomeScreen(
              refreshSignal: _homeRefresh,
              onOpenAlarms: () => _go(1),
              onOpenCalendar: () => _go(3),
              onOpenSettings: () => _go(4),
            ),
          ),
          // 나머지 탭은 열 때마다 새로 만들어 항상 최신 데이터를 보여 준다.
          if (_index != 0) _currentTab(),
        ],
      ),
    );
  }
}

/// 하단 고정 바 — 홈 · 알람 · 달력 · 설정.
class _QuickNavBar extends StatelessWidget {
  const _QuickNavBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<String> labels;

  static const _icons = [
    Icons.home_rounded,
    Icons.alarm_rounded,
    Icons.wb_sunny_outlined,
    Icons.calendar_month_rounded,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14110D),
        border: Border(top: BorderSide(color: Color(0xFF2A2520), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _icons.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[i],
                          color: i == selectedIndex
                              ? AppTheme.accent
                              : AppTheme.textMuted,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: i == selectedIndex
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
