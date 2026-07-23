import 'package:shared_preferences/shared_preferences.dart';

/// Consecutive days of completed morning prayer (normal completion only).
class StreakService {
  StreakService._();

  static const _streakKey = 'morning_streak_count';
  static const _lastStreakDayKey = 'morning_streak_last_day';

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _yesterdayKey(DateTime now) {
    final y = now.subtract(const Duration(days: 1));
    return _dateKey(y);
  }

  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static Future<bool> hasCountedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastStreakDayKey) == _dateKey(DateTime.now());
  }

  /// Full prayer completion — extends streak.
  static Future<void> onNormalMorningCompletion() async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastStreakDayKey);
    if (last == today) return;

    final count = prefs.getInt(_streakKey) ?? 0;
    if (last == _yesterdayKey(now)) {
      await prefs.setInt(_streakKey, count + 1);
    } else {
      await prefs.setInt(_streakKey, 1);
    }
    await prefs.setString(_lastStreakDayKey, today);
  }

  /// Emergency exit — alarm clears; streak unchanged.
  static Future<void> onEmergencyCompletion() async {}
}
