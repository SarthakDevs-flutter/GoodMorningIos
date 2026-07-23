import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_preferences.dart';

/// 아침 알람 하나 — 시간 + 반복 요일 + 켜짐 여부.
/// 같은 날 여러 개가 울릴 수 있고, 각 알람은 자기 미션 완료를 따로 가진다.
class MorningAlarm {
  const MorningAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.enabled,
    this.soundName,
  });

  final String id;
  final int hour;
  final int minute;

  /// 1=월 .. 7=일
  final List<int> weekdays;
  final bool enabled;

  /// 알람별 알람음 파일명(god_morning_N.wav). null = 전역 설정 폴백.
  final String? soundName;

  int get minutesOfDay => hour * 60 + minute;

  MorningAlarm copyWith({
    int? hour,
    int? minute,
    List<int>? weekdays,
    bool? enabled,
    String? soundName,
  }) {
    // 주의: soundName을 copyWith에서 빠뜨리면 토글 한 번에 알람별 소리가
    // 전부 유실된다(과거 버그) — 반드시 기존 값을 보존한다.
    return MorningAlarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      soundName: soundName ?? this.soundName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
    'enabled': enabled,
    if (soundName != null) 'soundName': soundName,
  };

  static MorningAlarm? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final hour = json['hour'];
    final minute = json['minute'];
    if (id is! String || hour is! int || minute is! int) return null;
    final weekdays = AlarmPreferences.normalizeWeekdays(
      (json['weekdays'] as List?)?.whereType<int>(),
    );
    final rawSound = json['soundName'];
    final soundName = rawSound is String && rawSound.trim().isNotEmpty
        ? rawSound.trim()
        : null;
    return MorningAlarm(
      id: id,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
      weekdays: weekdays,
      enabled: json['enabled'] == true,
      soundName: soundName,
    );
  }

  /// 네이티브 채널 payload 형태.
  Map<String, dynamic> toChannelPayload() => {
    'id': id,
    'minutes': minutesOfDay,
    'weekdays': weekdays,
    // Android는 fire 시점에 미러에서 이 알람의 소리를 찾는다.
    if (soundName != null) 'soundName': soundName,
  };
}

/// 아침 알람 목록의 저장소 + 발화 계산.
class AlarmStore {
  AlarmStore._();

  static const _alarmsKey = 'morning_alarms_v1';
  static const maxAlarms = 5;

  /// 알람 목록. 저장된 목록이 없으면 기존 설정(요일별 시간 맵 또는 단일
  /// 시간+요일)에서 자동 변환한다 — 같은 시간끼리 묶어 알람 하나씩.
  static Future<List<MorningAlarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alarmsKey);
    if (raw != null && raw.isNotEmpty) {
      // 저장은 정렬돼 있지만, 과거 빌드가 남긴 데이터도 있으므로 방어적으로
      // 항상 시간순으로 돌려준다(이른 새벽이 맨 위).
      final parsed = sortedByTime(_decode(raw));
      if (parsed.isNotEmpty) return parsed;
    }
    return _migrateFromLegacy();
  }

  /// 시간순(이른 시각 먼저) 정렬한 새 목록. 동시각이면 id로 안정 정렬.
  static List<MorningAlarm> sortedByTime(List<MorningAlarm> alarms) {
    final out = List<MorningAlarm>.of(alarms);
    out.sort(
      (a, b) => a.minutesOfDay != b.minutesOfDay
          ? a.minutesOfDay.compareTo(b.minutesOfDay)
          : a.id.compareTo(b.id),
    );
    return out;
  }

  static Future<void> saveAlarms(List<MorningAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = _sanitize(alarms);
    await prefs.setString(
      _alarmsKey,
      jsonEncode(sanitized.map((a) => a.toJson()).toList()),
    );
    await _syncLegacyKeys(sanitized);
  }

  /// [now] 이후 가장 가까운 발화. [isCompletedToday]가 true를 돌려주는 알람은
  /// 오늘 발화에서 제외된다(그날 미션 완료 → 그 알람만 조용).
  static DateTime? nextOccurrence(
    List<MorningAlarm> alarms,
    DateTime now, {
    bool Function(String alarmId)? isCompletedToday,
  }) {
    return nextOccurrenceInfo(
      alarms,
      now,
      isCompletedToday: isCompletedToday,
    )?.when;
  }

  /// [nextOccurrence]와 같지만 어떤 알람의 발화인지도 함께 돌려준다
  /// (iOS 롤포워드 예약에서 알람 id를 네이티브에 전달할 때 사용).
  static ({MorningAlarm alarm, DateTime when})? nextOccurrenceInfo(
    List<MorningAlarm> alarms,
    DateTime now, {
    bool Function(String alarmId)? isCompletedToday,
  }) {
    ({MorningAlarm alarm, DateTime when})? best;
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      for (var offset = 0; offset <= 7; offset++) {
        final date = DateTime(now.year, now.month, now.day + offset);
        if (!alarm.weekdays.contains(date.weekday)) continue;
        if (offset == 0 &&
            isCompletedToday != null &&
            isCompletedToday(alarm.id)) {
          continue;
        }
        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          alarm.hour,
          alarm.minute,
        );
        if (!candidate.isAfter(now)) continue;
        if (best == null || candidate.isBefore(best.when)) {
          best = (alarm: alarm, when: candidate);
        }
        break; // 이 알람의 첫 미래 발화만 후보로 쓰면 된다.
      }
    }
    return best;
  }

  /// 오늘 이미 지나갔더라도 [afterAlarmId] 다음 순서의 미완료 알람을 찾는다.
  ///
  /// 첫 알람 미션을 하는 동안 두 번째 알람 시간이 지나가면 일반
  /// [nextOccurrenceInfo]는 그 시간을 "과거"로 보고 내일로 넘긴다. Amen 직후
  /// 같은 날의 다음 알람을 즉시 다시 울리기 위해 이 보조 계산을 쓴다.
  static ({MorningAlarm alarm, DateTime when})? nextTodayAfterInfo(
    List<MorningAlarm> alarms,
    DateTime now, {
    required String? afterAlarmId,
    bool Function(String alarmId)? isCompletedToday,
  }) {
    if (afterAlarmId == null || afterAlarmId.isEmpty) return null;
    MorningAlarm? anchor;
    for (final alarm in alarms) {
      if (alarm.id == afterAlarmId) {
        anchor = alarm;
        break;
      }
    }
    if (anchor == null) return null;

    final today = DateTime(now.year, now.month, now.day);
    if (!anchor.weekdays.contains(today.weekday)) return null;
    final anchorTime = DateTime(
      today.year,
      today.month,
      today.day,
      anchor.hour,
      anchor.minute,
    );

    ({MorningAlarm alarm, DateTime when})? best;
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      if (!alarm.weekdays.contains(today.weekday)) continue;
      if (isCompletedToday != null && isCompletedToday(alarm.id)) continue;
      final candidate = DateTime(
        today.year,
        today.month,
        today.day,
        alarm.hour,
        alarm.minute,
      );
      if (!candidate.isAfter(anchorTime)) continue;
      if (best == null || candidate.isBefore(best.when)) {
        best = (alarm: alarm, when: candidate);
      }
    }
    return best;
  }

  /// 오늘 울릴(요일이 맞고 켜진) 알람들.
  static List<MorningAlarm> dueToday(List<MorningAlarm> alarms, DateTime now) {
    return alarms
        .where((a) => a.enabled && a.weekdays.contains(now.weekday))
        .toList();
  }

  static bool anyEnabled(List<MorningAlarm> alarms) =>
      alarms.any((a) => a.enabled);

  static String newAlarmId() =>
      'a${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  /// 요일별 시간 맵(요일→분)을 알람 목록으로 변환 — 같은 시간끼리 묶는다.
  static List<MorningAlarm> fromDayTimes(
    Map<int, int> dayTimes, {
    required bool enabled,
  }) {
    final byTime = <int, List<int>>{};
    dayTimes.forEach((day, minutes) {
      byTime.putIfAbsent(minutes, () => []).add(day);
    });
    var index = 0;
    return _sanitize(
      byTime.entries.map((entry) {
        index += 1;
        return MorningAlarm(
          id: 'legacy$index',
          hour: entry.key ~/ 60,
          minute: entry.key % 60,
          weekdays: entry.value..sort(),
          enabled: enabled,
        );
      }).toList(),
    );
  }

  // ── 내부 ──

  static List<MorningAlarm> _decode(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return _sanitize(
        list
            .whereType<Map<String, dynamic>>()
            .map(MorningAlarm.fromJson)
            .whereType<MorningAlarm>()
            .toList(),
      );
    } catch (_) {
      return const [];
    }
  }

  static List<MorningAlarm> _sanitize(List<MorningAlarm> alarms) {
    final seenIds = <String>{};
    final out = <MorningAlarm>[];
    for (final alarm in alarms) {
      if (alarm.weekdays.isEmpty) continue;
      if (!seenIds.add(alarm.id)) continue;
      out.add(alarm);
      if (out.length >= maxAlarms) break;
    }
    return sortedByTime(out);
  }

  /// 기존 "요일별 시간 맵"을 알람 목록으로 변환: 같은 시간의 요일끼리 묶어
  /// 알람 하나로. (예전 단일 시간 설정은 맵 마이그레이션이 이미 처리한다.)
  static Future<List<MorningAlarm>> _migrateFromLegacy() async {
    final dayTimes = await AlarmPreferences.getDayTimes();
    final enabled = await AlarmPreferences.isEnabled();
    final byTime = <int, List<int>>{};
    dayTimes.forEach((day, minutes) {
      byTime.putIfAbsent(minutes, () => []).add(day);
    });
    var index = 0;
    final alarms = byTime.entries.map((entry) {
      index += 1;
      return MorningAlarm(
        id: 'legacy$index',
        hour: entry.key ~/ 60,
        minute: entry.key % 60,
        weekdays: entry.value..sort(),
        enabled: enabled,
      );
    }).toList();
    final sanitized = _sanitize(alarms);
    if (sanitized.isNotEmpty) {
      // 다음 실행부터는 목록이 진실이 되도록 저장해 둔다.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _alarmsKey,
        jsonEncode(sanitized.map((a) => a.toJson()).toList()),
      );
    }
    return sanitized;
  }

  /// 알람 목록을 모르는 나머지 코드(레거시 단일 시간/요일별 맵 사용처)가
  /// 이상한 값을 읽지 않도록 대표값을 함께 갱신한다.
  static Future<void> _syncLegacyKeys(List<MorningAlarm> alarms) async {
    final enabledAlarms = alarms.where((a) => a.enabled).toList();
    if (enabledAlarms.isEmpty) {
      await AlarmPreferences.setEnabled(false);
      return;
    }
    await AlarmPreferences.setEnabled(true);
    // 요일별 맵: 요일마다 "그 요일의 가장 이른" 알람 시간을 대표로 둔다.
    final dayTimes = <int, int>{};
    for (final alarm in enabledAlarms) {
      for (final day in alarm.weekdays) {
        final existing = dayTimes[day];
        if (existing == null || alarm.minutesOfDay < existing) {
          dayTimes[day] = alarm.minutesOfDay;
        }
      }
    }
    if (dayTimes.isNotEmpty) {
      await AlarmPreferences.saveDayTimes(dayTimes);
    }
  }
}
