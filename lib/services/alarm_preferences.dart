import 'package:shared_preferences/shared_preferences.dart';

/// 아침·저녁 알람 시간·켜짐 여부를 기기에 저장하는 클래스
class AlarmPreferences {
  AlarmPreferences._();

  // MVP focus: ship the morning alarm first. Evening blessing code remains in
  // the repo for a later update, but product paths must treat it as disabled.
  // 자녀 축복 시간(아론의 축복) — 2026-07-05 부활. 사용자가 직접 켜는
  // 옵트인 기능이다(기본 꺼짐).
  static const eveningFeatureEnabled = true;

  // ── 아침 알람 ──
  static const _morningHourKey = 'morning_alarm_hour';
  static const _morningMinuteKey = 'morning_alarm_minute';
  static const _morningEnabledKey = 'morning_alarm_enabled';
  static const _morningWeekdaysKey = 'morning_alarm_weekdays';
  // 요일별 시간: "1:390,2:405" (weekday:자정 기준 분). 키에 없는 요일은 꺼짐.
  static const _morningDayTimesKey = 'morning_alarm_day_times';

  /// 기본값: 오전 6시 30분
  static const defaultHour = 6;
  static const defaultMinute = 30;
  static const defaultWeekdays = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  // ── 저녁 축복 알람 ──
  static const _eveningHourKey = 'evening_alarm_hour';
  static const _eveningMinuteKey = 'evening_alarm_minute';
  static const _eveningEnabledKey = 'evening_alarm_enabled';
  // 자녀 축복 반복 요일(1=월..7=일). 없으면 매일.
  static const _eveningWeekdaysKey = 'evening_alarm_weekdays';

  /// 기본값: 저녁 9시
  static const defaultEveningHour = 21;
  static const defaultEveningMinute = 0;

  // ── 아침 ──

  static Future<int> getHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_morningHourKey) ?? defaultHour;
  }

  static Future<int> getMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_morningMinuteKey) ?? defaultMinute;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_morningEnabledKey) ?? false;
  }

  static List<int> normalizeWeekdays(Iterable<int>? weekdays) {
    final normalized =
        (weekdays ?? defaultWeekdays)
            .where(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            )
            .toSet()
            .toList()
          ..sort();
    return normalized.isEmpty ? List<int>.from(defaultWeekdays) : normalized;
  }

  static Future<List<int>> getWeekdays() async {
    final prefs = await SharedPreferences.getInstance();
    // 요일별 시간 맵이 있으면 그 키들이 곧 켜진 요일이다.
    final dayTimesRaw = prefs.getString(_morningDayTimesKey);
    if (dayTimesRaw != null && dayTimesRaw.isNotEmpty) {
      final days = parseDayTimes(dayTimesRaw).keys.toList()..sort();
      if (days.isNotEmpty) return days;
    }
    final raw = prefs.getStringList(_morningWeekdaysKey);
    if (raw == null) return List<int>.from(defaultWeekdays);
    return normalizeWeekdays(raw.map((value) => int.tryParse(value) ?? -1));
  }

  // ── 요일별 아침 알람 시간 ──

  /// weekday(1=월..7=일) → 자정 기준 분. 맵에 없는 요일은 알람 꺼짐.
  /// 저장된 맵이 없으면 기존 "시간 하나 + 요일들" 설정에서 만들어 준다(마이그레이션).
  static Future<Map<int, int>> getDayTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_morningDayTimesKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = parseDayTimes(raw);
      if (parsed.isNotEmpty) return parsed;
    }
    final hour = prefs.getInt(_morningHourKey) ?? defaultHour;
    final minute = prefs.getInt(_morningMinuteKey) ?? defaultMinute;
    final legacyRaw = prefs.getStringList(_morningWeekdaysKey);
    final weekdays = legacyRaw == null
        ? List<int>.from(defaultWeekdays)
        : normalizeWeekdays(legacyRaw.map((value) => int.tryParse(value) ?? -1));
    return {for (final day in weekdays) day: hour * 60 + minute};
  }

  /// 요일별 시간을 저장한다. 기존 단일 시간/요일 키도 함께 갱신해서
  /// 아직 맵을 모르는 코드가 이상한 값을 읽지 않게 한다.
  static Future<void> saveDayTimes(Map<int, int> dayTimes) async {
    final sanitized = sanitizeDayTimes(dayTimes);
    if (sanitized.isEmpty) return; // 최소 하루는 켜져 있어야 한다.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_morningDayTimesKey, encodeDayTimes(sanitized));
    await prefs.setStringList(
      _morningWeekdaysKey,
      (sanitized.keys.toList()..sort()).map((d) => d.toString()).toList(),
    );
    final next = nextOccurrenceFor(sanitized, DateTime.now());
    if (next != null) {
      await prefs.setInt(_morningHourKey, next.hour);
      await prefs.setInt(_morningMinuteKey, next.minute);
    }
  }

  static Map<int, int> sanitizeDayTimes(Map<int, int> dayTimes) {
    final out = <int, int>{};
    dayTimes.forEach((day, minutes) {
      if (day < DateTime.monday || day > DateTime.sunday) return;
      out[day] = minutes.clamp(0, 24 * 60 - 1);
    });
    return out;
  }

  static Map<int, int> parseDayTimes(String raw) {
    final map = <int, int>{};
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length != 2) continue;
      final day = int.tryParse(kv[0].trim());
      final minutes = int.tryParse(kv[1].trim());
      if (day == null || minutes == null) continue;
      if (day < DateTime.monday || day > DateTime.sunday) continue;
      map[day] = minutes.clamp(0, 24 * 60 - 1);
    }
    return map;
  }

  static String encodeDayTimes(Map<int, int> dayTimes) {
    final entries = dayTimes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  /// 오늘 요일의 알람 시간(자정 기준 분). 오늘 꺼져 있으면 null.
  static Future<int?> minutesForWeekday(int weekday) async {
    final dayTimes = await getDayTimes();
    return dayTimes[weekday];
  }

  /// [now] 이후 가장 가까운 발화 시각. 모든 요일이 꺼져 있으면 null.
  static Future<DateTime?> nextMorningDateTime([DateTime? now]) async {
    final dayTimes = await getDayTimes();
    return nextOccurrenceFor(dayTimes, now ?? DateTime.now());
  }

  /// 앞으로 7일을 훑어 요일별 시간 중 가장 가까운 미래 발화를 찾는다
  /// (AOSP 시계앱과 같은 방식).
  static DateTime? nextOccurrenceFor(Map<int, int> dayTimes, DateTime now) {
    if (dayTimes.isEmpty) return null;
    for (var offset = 0; offset <= 7; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final minutes = dayTimes[date.weekday];
      if (minutes == null) continue;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  static Future<void> saveWeekdays(Iterable<int> weekdays) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _morningWeekdaysKey,
      normalizeWeekdays(weekdays).map((weekday) => weekday.toString()).toList(),
    );
  }

  static Future<void> save({
    required int hour,
    required int minute,
    required bool enabled,
    Iterable<int>? weekdays,
  }) async {
    // 단일 시간 저장 시 요일별 맵도 같은 시간으로 재구성해서
    // 두 저장소가 어긋나지 않게 한다.
    final days = weekdays != null
        ? normalizeWeekdays(weekdays)
        : await getWeekdays();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_morningHourKey, hour);
    await prefs.setInt(_morningMinuteKey, minute);
    await prefs.setBool(_morningEnabledKey, enabled);
    await prefs.setStringList(
      _morningWeekdaysKey,
      days.map((weekday) => weekday.toString()).toList(),
    );
    await prefs.setString(
      _morningDayTimesKey,
      encodeDayTimes({for (final day in days) day: hour * 60 + minute}),
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_morningEnabledKey, enabled);
  }

  // ── 저녁 ──

  static Future<int> getEveningHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_eveningHourKey) ?? defaultEveningHour;
  }

  static Future<int> getEveningMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_eveningMinuteKey) ?? defaultEveningMinute;
  }

  static Future<bool> isEveningEnabled() async {
    if (!eveningFeatureEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    // 옵트인: 사용자가 자녀 축복을 직접 켜기 전까지는 꺼져 있다.
    return prefs.getBool(_eveningEnabledKey) ?? false;
  }

  static Future<void> saveEvening({
    required int hour,
    required int minute,
    required bool enabled,
    Iterable<int>? weekdays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eveningHourKey, hour);
    await prefs.setInt(_eveningMinuteKey, minute);
    await prefs.setBool(_eveningEnabledKey, eveningFeatureEnabled && enabled);
    if (weekdays != null) {
      final normalized = normalizeWeekdays(weekdays);
      await prefs.setStringList(
        _eveningWeekdaysKey,
        normalized.map((d) => d.toString()).toList(),
      );
    }
  }

  /// 자녀 축복 반복 요일(1=월..7=일). 저장이 없으면 매일.
  static Future<List<int>> getEveningWeekdays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_eveningWeekdaysKey);
    if (raw == null || raw.isEmpty) return List.of(defaultWeekdays);
    final parsed = normalizeWeekdays(
      raw.map(int.tryParse).whereType<int>(),
    );
    return parsed.isEmpty ? List.of(defaultWeekdays) : parsed;
  }

  /// "6:30 AM" / "9:00 PM" 형식으로 표시
  static String formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }
}
