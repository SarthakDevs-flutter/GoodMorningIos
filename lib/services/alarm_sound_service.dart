import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'alarm_sound_preferences.dart';

/// Plays looping alarm audio. iOS uses native AVAudioPlayer with bundled tones.
class AlarmSoundService {
  AlarmSoundService._();

  static final AlarmSoundService instance = AlarmSoundService._();

  static const _nativeChannel = MethodChannel('means_of_grace/alarm_audio');
  static const _defaultAlarmToneAsset = 'sounds/god_morning_1.wav';
  static const _assetPaths = [
    _defaultAlarmToneAsset,
    'assets/sounds/god_morning_1.wav',
  ];

  AudioPlayer? _assetPlayer;
  Timer? _watchdogTimer;
  Timer? _selectionPreviewTimer;
  Timer? _previewWatchdogTimer;
  bool _isPlaying = false;
  bool _wantPlaying = false;
  bool _previewMode = false;
  DateTime? _lastIosLoudnessReinforceAt;

  bool get isPlaying => _isPlaying;
  bool get isPreviewMode => _previewMode;

  Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetoothA2DP,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (error) {
      debugPrint('AlarmSoundService.configure: $error');
    }
  }

  static const selectionPreviewMaxDuration = Duration(seconds: 30);

  Future<void> start({bool forPreview = false}) async {
    if (forPreview) {
      _selectionPreviewTimer?.cancel();
      _previewWatchdogTimer?.cancel();
      await _stopPlayers(keepSession: true);
      _previewMode = true;
      _wantPlaying = true;
      await _startPlayback(loop: false, loud: false);
      return;
    }

    // Already playing — keep going. Calling stop+restart causes audible gaps,
    // and start() gets called multiple times per alarm (notification, gate,
    // ringing screen). Guard must run BEFORE stop().
    if (_wantPlaying && !_previewMode && await _isAlreadyPlaying()) {
      _isPlaying = true;
      _startWatchdog();
      return;
    }

    await stop();
    _wantPlaying = true;
    await _startPlayback();
  }

  /// Tap a sound in settings — play the selected file once.
  Future<void> playSelectionPreview({
    AlarmSoundSource? source,
    Duration maxDuration = selectionPreviewMaxDuration,
  }) async {
    _selectionPreviewTimer?.cancel();
    _previewWatchdogTimer?.cancel();

    // 직전 미션이 세션을 .record로 두었을 수 있으니 재생 세션으로 복원.
    await prepareForPlayback();
    await _stopPlayers(keepSession: true);
    _previewMode = true;
    _wantPlaying = true;

    if (source != null) {
      try {
        await _startAudioplayersFallback(
          assetName: _assetNameForSource(source),
          loop: false,
        );
        _isPlaying = true;
      } catch (error) {
        debugPrint('AlarmSoundService selection asset preview failed: $error');
        await _startPlayback(loop: false, loud: false, sourceOverride: source);
      }
    } else {
      await _startPlayback(loop: false, loud: false);
    }

    // Safety stop only. The native/player path should finish naturally first.
    _selectionPreviewTimer = Timer(maxDuration, () {
      if (_previewMode) {
        unawaited(stop());
      }
    });
  }

  Future<void> _startPlayback({
    bool loop = true,
    bool loud = true,
    AlarmSoundSource? sourceOverride,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _startIosWithFallbacks(
        loop: loop,
        loud: loud,
        sourceOverride: sourceOverride,
      );
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _startAndroid(loop: loop, sourceOverride: sourceOverride);
        _isPlaying = true;
        if (!_previewMode) _startWatchdog();
        debugPrint('AlarmSoundService: started (Android)');
      } catch (error) {
        debugPrint('AlarmSoundService Android failed: $error');
        await _startAudioplayersFallback(loop: loop);
        _isPlaying = true;
      }
      return;
    }

    await _startAudioplayersFallback(loop: loop);
    _isPlaying = true;
  }

  Future<void> _startIosWithFallbacks({
    bool loop = true,
    bool loud = true,
    AlarmSoundSource? sourceOverride,
  }) async {
    final args = sourceOverride == null
        ? await AlarmSoundPreferences.iosPlayArgs(loud: loud)
        : AlarmSoundPreferences.iosPlayArgsForSource(
            sourceOverride,
            loud: loud,
          );
    final attempts = <Map<String, dynamic>>[
      {...args, 'loop': loop},
      {'type': 'bundled', 'name': 'god_morning_1', 'loud': loud, 'loop': loop},
    ];

    Object? lastError;
    for (final attempt in attempts) {
      try {
        await _invokeIosStart(attempt);
        _isPlaying = true;
        _lastIosLoudnessReinforceAt = DateTime.now();
        if (!_previewMode) _startWatchdog();
        debugPrint('AlarmSoundService: started iOS $attempt');
        return;
      } catch (error) {
        lastError = error;
        debugPrint('AlarmSoundService iOS attempt failed: $error');
      }
    }

    try {
      await _startAudioplayersFallback(loop: loop);
      _isPlaying = true;
      if (!_previewMode) _startWatchdog();
      debugPrint('AlarmSoundService: started iOS audioplayers fallback');
    } catch (error) {
      _isPlaying = false;
      debugPrint(
        'AlarmSoundService all iOS attempts failed: $lastError / $error',
      );
    }
  }

  Future<void> _invokeIosStart(Map<String, dynamic> args) async {
    final ok = await _nativeChannel.invokeMethod<bool>('start', args);
    if (ok != true) {
      throw PlatformException(
        code: 'start_failed',
        message: 'Native alarm returned $ok for $args',
      );
    }
  }

  Future<void> _reinforceIosLoudness({bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final now = DateTime.now();
    final last = _lastIosLoudnessReinforceAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastIosLoudnessReinforceAt = now;
    try {
      await _nativeChannel.invokeMethod<void>('reinforceLoud');
    } catch (error) {
      debugPrint('AlarmSoundService reinforceLoud: $error');
    }
  }

  /// No-op kept so the rest of the codebase doesn't need to change.
  Future<void> armSilentLoop() async {
    debugPrint('[ARM] noop — scheduled alarm package handles delivery');
  }

  Future<void> disarmSilentLoop() async {
    debugPrint('[DISARM] noop — scheduled alarm package handles delivery');
  }

  /// iOS: 녹음(.record)으로 바뀐 오디오 세션을 재생(.playback)으로 되돌린다.
  /// 미션 후 알람음 미리듣기가 무음이 되던 문제 해결.
  Future<void> prepareForPlayback() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _nativeChannel.invokeMethod<void>('prepareForPlayback');
    } catch (error) {
      debugPrint('AlarmSoundService.prepareForPlayback: $error');
    }
  }

  /// iOS: reconfigure AVAudioSession for speech_to_text after alarm playback.
  Future<void> prepareForSpeechRecognition() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _nativeChannel.invokeMethod<void>('prepareForSpeech');
      debugPrint('AlarmSoundService: prepared audio session for speech');
    } catch (error) {
      debugPrint('AlarmSoundService.prepareForSpeech: $error');
    }
  }

  Future<void> stop() async {
    _wantPlaying = false;
    _previewMode = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _selectionPreviewTimer?.cancel();
    _selectionPreviewTimer = null;
    _previewWatchdogTimer?.cancel();
    _previewWatchdogTimer = null;
    _lastIosLoudnessReinforceAt = null;
    await _stopPlayers();
    _isPlaying = false;
    debugPrint('AlarmSoundService: stopped');
  }

  /// Short sample for settings — always stops; no looping watchdog.
  Future<void> previewSample({
    Duration duration = const Duration(seconds: 2),
  }) async {
    await stop();
    try {
      await start(forPreview: true);
      await Future<void>.delayed(duration);
    } finally {
      await stop();
    }
  }

  Future<void> preview({Duration duration = const Duration(seconds: 4)}) async {
    await previewSample(duration: duration);
  }

  Future<void> ensurePlaying() async {
    if (!_wantPlaying) return;
    if (await _isAlreadyPlaying()) {
      _isPlaying = true;
      if (!_previewMode) _startWatchdog();
      await _reinforceIosLoudness();
      return;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _startIosWithFallbacks();
      return;
    }
    if (!_isPlaying) await start();
  }

  Future<bool> _isAlreadyPlaying() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        return await _nativeChannel.invokeMethod<bool>('isPlaying') ?? false;
      } catch (_) {
        return false;
      }
    }
    if (_assetPlayer != null) {
      return _assetPlayer!.state == PlayerState.playing;
    }
    return _isPlaying;
  }

  Future<void> _startAndroid({
    bool loop = true,
    AlarmSoundSource? sourceOverride,
  }) async {
    final source = sourceOverride ?? await AlarmSoundPreferences.getSource();
    switch (source) {
      case AlarmSoundSource.bundledGodMorning1:
      case AlarmSoundSource.bundledGodMorning2:
      case AlarmSoundSource.bundledGodMorning3:
      case AlarmSoundSource.bundledGodMorning4:
      case AlarmSoundSource.bundledGodMorning5:
      case AlarmSoundSource.bundledGodMorning6:
      case AlarmSoundSource.bundledGodMorning7:
      case AlarmSoundSource.bundledGodMorning9:
      case AlarmSoundSource.bundledGodMorning10:
      case AlarmSoundSource.bundledClassic:
      case AlarmSoundSource.bundledChime:
      case AlarmSoundSource.bundledBell:
        await _startAudioplayersFallback(
          loop: loop,
          assetName: _assetNameForSource(source),
        );
      case AlarmSoundSource.systemAlarm:
      case AlarmSoundSource.systemNotification:
      case AlarmSoundSource.systemRingtone:
      case AlarmSoundSource.androidDeviceUri:
        await _startAudioplayersFallback(
          assetName: _defaultAlarmToneAsset,
          loop: loop,
        );
      case AlarmSoundSource.iosSystemSound:
        await _startAudioplayersFallback(
          assetName: _defaultAlarmToneAsset,
          loop: loop,
        );
    }
  }

  String _assetNameForSource(AlarmSoundSource source) {
    return switch (source) {
      AlarmSoundSource.bundledGodMorning1 => 'sounds/god_morning_1.wav',
      AlarmSoundSource.bundledGodMorning2 => 'sounds/god_morning_2.wav',
      AlarmSoundSource.bundledGodMorning3 => 'sounds/god_morning_3.wav',
      AlarmSoundSource.bundledGodMorning4 => 'sounds/god_morning_4.wav',
      AlarmSoundSource.bundledGodMorning5 => 'sounds/god_morning_5.wav',
      AlarmSoundSource.bundledGodMorning6 => 'sounds/god_morning_6.wav',
      AlarmSoundSource.bundledGodMorning7 => 'sounds/god_morning_7.wav',
      AlarmSoundSource.bundledGodMorning9 => 'sounds/god_morning_9.wav',
      AlarmSoundSource.bundledGodMorning10 => 'sounds/god_morning_10.wav',
      _ => _defaultAlarmToneAsset,
    };
  }

  Future<void> _startAudioplayersFallback({
    String? assetName,
    bool loop = true,
  }) async {
    if (assetName == null) {
      // 폴백도 사용자가 고른 알람음으로 — 고정 기본음(god_morning_1)을
      // 틀면 '지정음으로 울리다 다른 소리로 바뀌는' 혼란이 된다
      // (실측 2026-07-11 06:40).
      try {
        final source = await AlarmSoundPreferences.getSource();
        assetName = _assetNameForSource(source);
      } catch (_) {}
    }
    final paths = assetName != null
        ? [assetName, 'assets/$assetName', ..._assetPaths]
        : _assetPaths;

    Object? lastError;
    for (final path in paths) {
      try {
        final player = AudioPlayer();
        _assetPlayer = player;
        await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
        await player.setVolume(1.0);
        await player.play(AssetSource(path));
        return;
      } catch (error) {
        lastError = error;
        try {
          await _assetPlayer?.dispose();
        } catch (_) {
          // The player can already be disposed if a preview/route dispose races.
        }
        _assetPlayer = null;
      }
    }
    throw StateError('Audioplayers fallback failed: $lastError');
  }

  Future<void> _stopPlayers({bool keepSession = false}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _nativeChannel.invokeMethod<void>('stop', {
          'keepSession': keepSession,
        });
      } catch (error) {
        debugPrint('Native iOS alarm stop: $error');
      }
    }

    if (_assetPlayer != null) {
      final player = _assetPlayer!;
      _assetPlayer = null;
      try {
        await player.stop();
      } catch (error) {
        debugPrint('AlarmSoundService player stop: $error');
      }
      try {
        await player.dispose();
      } catch (error) {
        debugPrint('AlarmSoundService player dispose: $error');
      }
    }
  }

  void _startWatchdog() {
    if (!_wantPlaying || _previewMode) return;
    if (_watchdogTimer?.isActive ?? false) return;

    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_wantPlaying) return;
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          final playing =
              await _nativeChannel.invokeMethod<bool>('isPlaying') ?? false;
          if (!playing) {
            debugPrint('Alarm watchdog: restarting');
            await _startIosWithFallbacks();
          } else {
            await _reinforceIosLoudness();
          }
        }
      } catch (error) {
        debugPrint('Alarm watchdog error: $error');
      }
    });
  }

  Future<void> dispose() async {
    await stop();
  }
}
