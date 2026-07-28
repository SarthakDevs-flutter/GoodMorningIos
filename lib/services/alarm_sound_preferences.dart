import 'package:shared_preferences/shared_preferences.dart';

/// Where the in-app alarm loop sound comes from
enum AlarmSoundSource {
  bundledGodMorning1,
  bundledGodMorning2,
  bundledGodMorning3,
  bundledGodMorning4,
  bundledGodMorning5,
  bundledGodMorning6,
  bundledGodMorning7,
  bundledGodMorning9,
  bundledGodMorning10,

  // Legacy choices kept only so old saved preferences normalize cleanly.
  bundledClassic,
  bundledChime,
  bundledBell,
  systemAlarm,
  systemNotification,
  systemRingtone,
  androidDeviceUri,
  iosSystemSound,
}

class AlarmSoundPreferences {
  AlarmSoundPreferences._();

  static const _sourceKey = 'alarm_sound_source';
  static const _androidUriKey = 'alarm_sound_android_uri';
  static const _androidTitleKey = 'alarm_sound_android_title';
  static const _iosSoundIdKey = 'alarm_sound_ios_id';
  static const _iosSoundTitleKey = 'alarm_sound_ios_title';
  static const _loudestAppliedKey = 'alarm_sound_loudest_v2';
  static const _godMorningDefaultKey = 'alarm_sound_god_morning_default_v1';

  /// One-time: set default alarm to bundled God Morning audio for new installs.
  static Future<void> ensureLoudestPreset() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_godMorningDefaultKey) == true) return;

    final raw = prefs.getString(_sourceKey);
    if (raw == null || raw == AlarmSoundSource.bundledClassic.name) {
      await prefs.setString(
        _sourceKey,
        AlarmSoundSource.bundledGodMorning1.name,
      );
    }
    await prefs.setBool(_godMorningDefaultKey, true);
    await prefs.setBool(_loudestAppliedKey, true);
  }

  static Future<AlarmSoundSource> getSource() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sourceKey);
    if (raw == null) return AlarmSoundSource.bundledGodMorning1;

    final source = AlarmSoundSource.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => AlarmSoundSource.bundledGodMorning1,
    );
    final normalized = _normalizeLegacySource(source);
    if (normalized != source) {
      await prefs.setString(_sourceKey, normalized.name);
    }
    return normalized;
  }

  static AlarmSoundSource _normalizeLegacySource(AlarmSoundSource source) {
    return switch (source) {
      AlarmSoundSource.bundledGodMorning1 ||
      AlarmSoundSource.bundledGodMorning2 ||
      AlarmSoundSource.bundledGodMorning3 ||
      AlarmSoundSource.bundledGodMorning4 ||
      AlarmSoundSource.bundledGodMorning5 ||
      AlarmSoundSource.bundledGodMorning6 ||
      AlarmSoundSource.bundledGodMorning7 ||
      AlarmSoundSource.bundledGodMorning9 ||
      AlarmSoundSource.bundledGodMorning10 => source,
      AlarmSoundSource.bundledClassic ||
      AlarmSoundSource.bundledChime ||
      AlarmSoundSource.bundledBell ||
      AlarmSoundSource.systemAlarm ||
      AlarmSoundSource.systemNotification ||
      AlarmSoundSource.systemRingtone ||
      AlarmSoundSource.androidDeviceUri ||
      AlarmSoundSource.iosSystemSound => AlarmSoundSource.bundledGodMorning1,
    };
  }

  static Future<void> setSource(AlarmSoundSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceKey, _normalizeLegacySource(source).name);
  }

  static Future<String?> getAndroidUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_androidUriKey);
  }

  static Future<String?> getAndroidTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_androidTitleKey);
  }

  static Future<void> setAndroidSound({
    required String uri,
    required String title,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_androidUriKey, uri);
    await prefs.setString(_androidTitleKey, title);
    await prefs.setString(_sourceKey, AlarmSoundSource.androidDeviceUri.name);
  }

  static Future<int?> getIosSoundId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_iosSoundIdKey);
  }

  static Future<String?> getIosSoundTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_iosSoundTitleKey);
  }

  static Future<void> setIosSound({
    required int soundId,
    required String title,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_iosSoundIdKey, soundId);
    await prefs.setString(_iosSoundTitleKey, title);
    await prefs.setString(_sourceKey, AlarmSoundSource.iosSystemSound.name);
  }

  /// Native iOS plugin arguments for the current selection.
  static Future<Map<String, dynamic>> iosPlayArgs({bool loud = true}) async {
    final source = await getSource();
    return iosPlayArgsForSource(source, loud: loud);
  }

  static Map<String, dynamic> iosPlayArgsForSource(
    AlarmSoundSource source, {
    bool loud = true,
  }) {
    return {
      'type': 'bundled',
      'name': _baseName(source),
      'ext': _extension(source),
      'loud': loud,
    };
  }

  /// Filename in the iOS app bundle for lock-screen notification sound.
  /// Keep this on short bundled files. Large/long files can fail silently as
  /// lock-screen alarm sounds.
  static Future<String> iosNotificationSoundFile() async {
    return notificationSoundFileFor(await alarmKitSoundFile());
  }

  /// Local notification sounds must be shorter than 30 seconds. Alarm 8's
  /// full tone is intentionally kept for AlarmKit and in-app playback, while
  /// notification retries use a shorter excerpt of that same tone.
  static String notificationSoundFileFor(String fileName) {
    if (fileName == 'god_morning_9.wav' || fileName == 'god_morning_10.wav') {
      // 30초 초과 파일은 iOS 로컬 알림(백스톱/융단)에서 무음(진동만 발생) 처리되므로,
      // 안전하고 검증된 15초짜리 god_morning_1.wav로 대체하여 항상 소리가 나도록 합니다.
      return 'god_morning_1.wav';
    }
    return fileName;
  }

  /// Bundled filename for AlarmKit. System sounds and legacy long hymn
  /// selections fall back to short, verified bundled files.
  static Future<String> alarmKitSoundFile() async {
    final source = await getSource();
    return '${_baseName(source)}.${_extension(source)}';
  }

  static Future<String> displayLabel() async {
    final source = await getSource();
    return _displayLabel(source);
  }

  /// 알람별 소리용 공개 헬퍼: 소스 → 파일명(god_morning_N.wav).
  static String fileNameFor(AlarmSoundSource source) {
    return '${_baseName(source)}.${_extension(source)}';
  }

  /// 알람별 소리용 공개 헬퍼: 소스 → 표시 라벨.
  static String labelFor(AlarmSoundSource source) => _displayLabel(source);

  /// 파일명(god_morning_N.wav) → 소스. 모르는 이름이면 null(전역 폴백 유지).
  static AlarmSoundSource? sourceForFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    for (final source in AlarmSoundSource.values) {
      if (fileNameFor(source) == fileName) {
        return _normalizeLegacySource(source);
      }
    }
    return null;
  }

  static String _baseName(AlarmSoundSource source) {
    return switch (_normalizeLegacySource(source)) {
      AlarmSoundSource.bundledGodMorning1 => 'god_morning_1',
      AlarmSoundSource.bundledGodMorning2 => 'god_morning_2',
      AlarmSoundSource.bundledGodMorning3 => 'god_morning_3',
      AlarmSoundSource.bundledGodMorning4 => 'god_morning_4',
      AlarmSoundSource.bundledGodMorning5 => 'god_morning_5',
      AlarmSoundSource.bundledGodMorning6 => 'god_morning_6',
      AlarmSoundSource.bundledGodMorning7 => 'god_morning_7',
      AlarmSoundSource.bundledGodMorning9 => 'god_morning_9',
      AlarmSoundSource.bundledGodMorning10 => 'god_morning_10',
      _ => 'god_morning_1',
    };
  }

  static String _extension(AlarmSoundSource _) => 'wav';

  static String _displayLabel(AlarmSoundSource source) {
    return switch (_normalizeLegacySource(source)) {
      AlarmSoundSource.bundledGodMorning1 => 'God Morning 1',
      AlarmSoundSource.bundledGodMorning2 => 'God Morning 2',
      AlarmSoundSource.bundledGodMorning3 => 'God Morning 3',
      AlarmSoundSource.bundledGodMorning4 => 'God Morning 4',
      AlarmSoundSource.bundledGodMorning5 => 'God Morning 5',
      AlarmSoundSource.bundledGodMorning6 => 'God Morning 6',
      AlarmSoundSource.bundledGodMorning7 => 'God Morning 7',
      AlarmSoundSource.bundledGodMorning9 => 'God Morning 8',
      AlarmSoundSource.bundledGodMorning10 => 'God Morning 9',
      _ => 'God Morning 1',
    };
  }
}
