import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_content_mode.dart';
import '../models/prayer_intensity.dart';
import '../models/scripture_plan.dart';

/// Prayer intensity, first-use grace period, and emergency usage limits.
class PrayerPreferencesService {
  PrayerPreferencesService._();

  static const _intensityKey = 'prayer_intensity';
  static const _scripturePlanKey = 'scripture_plan';
  static const _missionContentModeKey = 'mission_content_mode';
  static const _missionPassThresholdKey = 'mission_pass_threshold';
  // 자녀 축복 전용 통과 기준(아침과 독립). 없으면 축복 기본값을 쓴다.
  static const _blessingPassThresholdKey = 'blessing_pass_threshold';
  static const _firstUseDateKey = 'app_first_use_date';
  static const _emergencyWeekKey = 'emergency_uses_week';
  static const _emergencyCountKey = 'emergency_uses_count';

  static const defaultMissionPassThreshold = 0.30;
  // 자녀 축복은 아이 앞에서 부드럽게 — 기본은 조금 더 낮게.
  static const defaultBlessingPassThreshold = 0.30;
  static const firstWeekGraceDays = 7;

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return _dateKey(monday);
  }

  static Future<void> ensureFirstUseDate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstUseDateKey)) {
      await prefs.setString(_firstUseDateKey, _dateKey(DateTime.now()));
    }
  }

  static Future<int> daysSinceFirstUse() async {
    await ensureFirstUseDate();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_firstUseDateKey);
    if (raw == null) return 0;
    final parts = raw.split('-');
    if (parts.length != 3) return 0;
    final first = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(first).inDays;
  }

  static Future<bool> isInFirstWeekGrace() async {
    return (await daysSinceFirstUse()) < firstWeekGraceDays;
  }

  static Future<int> firstWeekDaysRemaining() async {
    final used = await daysSinceFirstUse();
    final left = firstWeekGraceDays - used;
    return left > 0 ? left : 0;
  }

  static Future<PrayerIntensity> getIntensity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_intensityKey);
    return PrayerIntensity.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => PrayerIntensity.normal,
    );
  }

  static Future<void> setIntensity(PrayerIntensity intensity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_intensityKey, intensity.name);
  }

  static Future<ScripturePlan> getScripturePlan() async {
    final prefs = await SharedPreferences.getInstance();
    return ScripturePlan.fromStorageValue(prefs.getString(_scripturePlanKey));
  }

  static Future<void> setScripturePlan(ScripturePlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scripturePlanKey, plan.name);
  }

  static Future<MissionContentMode> getMissionContentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return MissionContentMode.fromStorageValue(
      prefs.getString(_missionContentModeKey),
    );
  }

  static Future<void> setMissionContentMode(MissionContentMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_missionContentModeKey, mode.name);
  }

  static Future<double> getMissionPassThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_missionPassThresholdKey);
    return (raw ?? defaultMissionPassThreshold).clamp(0.0, 1.0);
  }

  static Future<void> setMissionPassThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_missionPassThresholdKey, threshold.clamp(0.0, 1.0));
  }

  /// 자녀 축복 전용 통과 기준(아침 알람과 완전 독립).
  static Future<double> getBlessingPassThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_blessingPassThresholdKey);
    return (raw ?? defaultBlessingPassThreshold).clamp(0.0, 1.0);
  }

  static Future<void> setBlessingPassThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_blessingPassThresholdKey, threshold.clamp(0.0, 1.0));
  }

  static Future<int> getEmergencyUsesThisWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final week = _weekKey(DateTime.now());
    if (prefs.getString(_emergencyWeekKey) != week) return 0;
    return prefs.getInt(_emergencyCountKey) ?? 0;
  }

  static Future<int> getRemainingEmergenciesThisWeek() async {
    if (await isInFirstWeekGrace()) return 999;
    final intensity = await getIntensity();
    final limit = intensity.weeklyEmergencyLimit;
    if (limit == 0) return 0;
    final used = await getEmergencyUsesThisWeek();
    return (limit - used).clamp(0, limit);
  }

  static Future<bool> canUseEmergency() async {
    if (await isInFirstWeekGrace()) return true;
    return (await getRemainingEmergenciesThisWeek()) > 0;
  }

  static Future<void> recordEmergencyUse() async {
    final prefs = await SharedPreferences.getInstance();
    final week = _weekKey(DateTime.now());
    if (prefs.getString(_emergencyWeekKey) != week) {
      await prefs.setString(_emergencyWeekKey, week);
      await prefs.setInt(_emergencyCountKey, 1);
      return;
    }
    final count = (prefs.getInt(_emergencyCountKey) ?? 0) + 1;
    await prefs.setInt(_emergencyCountKey, count);
  }
}
