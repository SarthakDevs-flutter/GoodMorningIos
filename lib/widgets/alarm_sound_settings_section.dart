import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/alarm_sound_preferences.dart';
import '../services/alarm_sound_service.dart';
import '../theme/app_theme.dart';

class AlarmSoundSettingsSection extends StatefulWidget {
  const AlarmSoundSettingsSection({
    super.key,
    this.initialSource,
    this.onChanged,
    this.persistGlobal = true,
  });

  /// 알람별 모드에서 현재 선택된 소스(null이면 전역 설정을 보여준다).
  final AlarmSoundSource? initialSource;

  /// 선택이 바뀔 때 호출 — 알람별 모드에서 에디터가 자기 알람에 저장한다.
  final ValueChanged<AlarmSoundSource>? onChanged;

  /// false면 전역 설정을 건드리지 않는다(알람별 모드).
  final bool persistGlobal;

  @override
  State<AlarmSoundSettingsSection> createState() =>
      _AlarmSoundSettingsSectionState();
}

class _AlarmSoundSettingsSectionState extends State<AlarmSoundSettingsSection> {
  AlarmSoundSource _source = AlarmSoundSource.bundledGodMorning1;
  String _label = '';

  @override
  void dispose() {
    unawaited(AlarmSoundService.instance.stop());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final source =
        widget.initialSource ?? await AlarmSoundPreferences.getSource();
    final label = AlarmSoundPreferences.labelFor(source);
    if (mounted) {
      setState(() {
        _source = source;
        _label = label;
      });
    }
  }

  Future<void> _selectSource(AlarmSoundSource source) async {
    if (widget.persistGlobal) {
      await AlarmSoundPreferences.setSource(source);
    }
    final label = AlarmSoundPreferences.labelFor(source);
    if (mounted) {
      setState(() {
        _source = source;
        _label = label;
      });
    }
    widget.onChanged?.call(source);
    if (!mounted) return;
    unawaited(AlarmSoundService.instance.playSelectionPreview(source: source));
  }

  List<({AlarmSoundSource source, String title})> _safeAlarmSoundOptions() {
    return [
      (source: AlarmSoundSource.bundledGodMorning1, title: 'God Morning 1'),
      (source: AlarmSoundSource.bundledGodMorning2, title: 'God Morning 2'),
      (source: AlarmSoundSource.bundledGodMorning3, title: 'God Morning 3'),
      (source: AlarmSoundSource.bundledGodMorning4, title: 'God Morning 4'),
      (source: AlarmSoundSource.bundledGodMorning5, title: 'God Morning 5'),
      (source: AlarmSoundSource.bundledGodMorning6, title: 'God Morning 6'),
      (source: AlarmSoundSource.bundledGodMorning7, title: 'God Morning 7'),
      (source: AlarmSoundSource.bundledGodMorning9, title: 'God Morning 8'),
      (source: AlarmSoundSource.bundledGodMorning10, title: 'God Morning 9'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.alarmSound,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isIos ? l10n.alarmSoundDescriptionIos : l10n.alarmSoundDescription,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.currentAlarmSound(_label),
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        if (isIos) ...[
          ..._safeAlarmSoundOptions().map((option) {
            return _SoundTile(
              title: option.title,
              value: option.source,
              groupValue: _source,
              onSelect: () => _selectSource(option.source),
            );
          }),
        ],
        if (!isIos) ...[
          ..._safeAlarmSoundOptions().map((option) {
            return _SoundTile(
              title: option.title,
              value: option.source,
              groupValue: _source,
              onSelect: () => _selectSource(option.source),
            );
          }),
        ],
      ],
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onSelect,
  });

  final String title;
  final AlarmSoundSource value;
  final AlarmSoundSource groupValue;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSaved = value == groupValue;

    return RadioListTile<AlarmSoundSource>(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: AppTheme.text)),
          ),
          if (isSaved) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                l10n.savedAlarmSoundBadge,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      activeColor: AppTheme.accent,
      // ignore: deprecated_member_use
      onChanged: (_) => onSelect(),
    );
  }
}
