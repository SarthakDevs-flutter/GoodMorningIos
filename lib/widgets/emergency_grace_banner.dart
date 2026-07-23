import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/prayer_preferences_service.dart';
import '../theme/app_theme.dart';

/// Shows Emergency grace-period status on the home screen.
class EmergencyGraceBanner extends StatefulWidget {
  const EmergencyGraceBanner({super.key, this.refreshSignal = 0});

  final int refreshSignal;

  @override
  State<EmergencyGraceBanner> createState() => _EmergencyGraceBannerState();
}

class _EmergencyGraceBannerState extends State<EmergencyGraceBanner> {
  bool _inGrace = false;
  int _graceDaysLeft = 0;
  int _remaining = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmergencyGraceBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _load();
    }
  }

  Future<void> _load() async {
    final grace = await PrayerPreferencesService.isInFirstWeekGrace();
    final graceLeft = await PrayerPreferencesService.firstWeekDaysRemaining();
    final remaining = await PrayerPreferencesService.getRemainingEmergenciesThisWeek();
    if (mounted) {
      setState(() {
        _inGrace = grace;
        _graceDaysLeft = graceLeft;
        _remaining = remaining;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    final status = _inGrace
        ? l10n.emergencyGraceRemaining(_graceDaysLeft)
        : l10n.emergencyRemainingThisWeek(_remaining);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.off.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_outline, color: AppTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.emergencyFeatureTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.emergencyFeatureBody,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
