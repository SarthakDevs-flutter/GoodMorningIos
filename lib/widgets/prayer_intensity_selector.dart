import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/prayer_intensity.dart';
import '../services/prayer_preferences_service.dart';
import '../theme/app_theme.dart';

class PrayerIntensitySelector extends StatefulWidget {
  const PrayerIntensitySelector({super.key});

  @override
  State<PrayerIntensitySelector> createState() =>
      _PrayerIntensitySelectorState();
}

class _PrayerIntensitySelectorState extends State<PrayerIntensitySelector> {
  PrayerIntensity _intensity = PrayerIntensity.normal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await PrayerPreferencesService.getIntensity();
    if (mounted) setState(() {
      _intensity = value;
      _loading = false;
    });
  }

  String _label(PrayerIntensity i, AppLocalizations l10n) => switch (i) {
        PrayerIntensity.gentle => l10n.prayerIntensityGentle,
        PrayerIntensity.normal => l10n.prayerIntensityNormal,
        PrayerIntensity.strict => l10n.prayerIntensityStrict,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.prayerIntensity,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<PrayerIntensity>(
          segments: PrayerIntensity.values
              .map(
                (i) => ButtonSegment(
                  value: i,
                  label: Text(_label(i, l10n)),
                ),
              )
              .toList(),
          selected: {_intensity},
          onSelectionChanged: (selected) async {
            final next = selected.first;
            setState(() => _intensity = next);
            await PrayerPreferencesService.setIntensity(next);
          },
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppTheme.bg
                  : AppTheme.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.prayerIntensityHint,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
