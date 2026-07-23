import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'streak_service.dart';

/// 날짜별 아침 미션 완료 기록 — 기록 달력 표시용.
/// 값은 그날 완료한 미션 수(멀티 알람이면 2 이상일 수 있다).
class CompletionHistoryService {
  CompletionHistoryService._();

  // JSON: {"2026-07-02": 1, ...}
  static const _historyKey = 'morning_completion_history';
  // 자녀 축복(저녁) 완료 기록 — 아침과 분리된 키.
  static const _eveningHistoryKey = 'evening_completion_history';
  static const _maxDays = 400;

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<Map<String, int>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value is int ? value : 0),
      )..removeWhere((_, count) => count <= 0);
    } catch (_) {
      return {};
    }
  }

  /// 아멘(미션 완료) 시점에 호출 — 오늘 완료 수를 1 올린다.
  static Future<void> recordCompletion([DateTime? when]) async {
    final history = await loadAll();
    final key = dateKey(when ?? DateTime.now());
    history[key] = (history[key] ?? 0) + 1;
    await _save(history);
  }

  /// 자녀 축복 완료 기록(하루 1회 이상이면 달력에 자녀 표시).
  static Future<void> recordEveningCompletion([DateTime? when]) async {
    final prefs = await SharedPreferences.getInstance();
    final history = _decode(prefs.getString(_eveningHistoryKey));
    final key = dateKey(when ?? DateTime.now());
    history[key] = (history[key] ?? 0) + 1;
    await prefs.setString(_eveningHistoryKey, jsonEncode(_pruned(history)));
  }

  /// 자녀 축복 연속 일수 — 오늘(오늘 아직 안 했으면 어제)부터 거꾸로 센다.
  static Future<int> eveningStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _decode(prefs.getString(_eveningHistoryKey));
    if (history.isEmpty) return 0;
    var cursor = DateTime.now();
    if ((history[dateKey(cursor)] ?? 0) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while ((history[dateKey(cursor)] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<Map<int, int>> eveningMonthCounts(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final history = _decode(prefs.getString(_eveningHistoryKey));
    final out = <int, int>{};
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    history.forEach((key, count) {
      if (!key.startsWith(prefix)) return;
      final day = int.tryParse(key.substring(prefix.length));
      if (day != null) out[day] = count;
    });
    return out;
  }

  static Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value is int ? value : 0),
      )..removeWhere((_, count) => count <= 0);
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _pruned(Map<String, int> history) {
    if (history.length <= _maxDays) return history;
    final keys = history.keys.toList()..sort();
    for (final key in keys.take(history.length - _maxDays)) {
      history.remove(key);
    }
    return history;
  }

  /// 기록이 비어 있으면 현재 연속 일수만큼 과거 날짜를 소급해 채운다
  /// (달력 기능을 켠 시점 이전의 연속 기록도 보이게).
  static Future<void> backfillFromStreakIfEmpty() async {
    final existing = await loadAll();
    if (existing.isNotEmpty) return;
    final streak = await StreakService.getCurrentStreak();
    if (streak <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final lastDayRaw = prefs.getString('morning_streak_last_day');
    final lastDay = lastDayRaw != null ? DateTime.tryParse(lastDayRaw) : null;
    if (lastDay == null) return;
    final history = <String, int>{};
    for (var i = 0; i < streak; i++) {
      history[dateKey(
        DateTime(lastDay.year, lastDay.month, lastDay.day - i),
      )] = 1;
    }
    await _save(history);
  }

  /// 지금까지 완료한 총 일수(날짜 기준, 중복 없음).
  static Future<int> totalDays() async {
    final history = await loadAll();
    return history.length;
  }

  /// 기록이 시작된 날(가장 오래된 완료 날짜). 기록이 없으면 null.
  /// 이 날짜 이전의 과거는 "놓친 날" 표시를 하지 않는다.
  static Future<DateTime?> earliestDate() async {
    final history = await loadAll();
    if (history.isEmpty) return null;
    final keys = history.keys.toList()..sort();
    return DateTime.tryParse(keys.first);
  }

  /// [year]년 [month]월의 일자→완료 수.
  static Future<Map<int, int>> monthCounts(int year, int month) async {
    final history = await loadAll();
    final out = <int, int>{};
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    history.forEach((key, count) {
      if (!key.startsWith(prefix)) return;
      final day = int.tryParse(key.substring(prefix.length));
      if (day != null) out[day] = count;
    });
    return out;
  }

  static Future<void> _save(Map<String, int> history) async {
    // 오래된 날짜는 정리해 저장 용량을 일정하게 유지한다.
    final keys = history.keys.toList()..sort();
    if (keys.length > _maxDays) {
      for (final key in keys.take(keys.length - _maxDays)) {
        history.remove(key);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
  }
}
