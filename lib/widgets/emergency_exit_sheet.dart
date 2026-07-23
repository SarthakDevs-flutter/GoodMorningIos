import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/emergency_exit_service.dart';
import '../services/prayer_preferences_service.dart';

enum EmergencyExitKind { morning, evening }

/// Type the confession phrase (morning) or fill the blank (evening) to exit a live alarm.
class EmergencyExitSheet extends StatefulWidget {
  const EmergencyExitSheet({
    super.key,
    required this.kind,
    required this.onConfirmed,
  });

  final EmergencyExitKind kind;
  final VoidCallback onConfirmed;

  static Future<void> show(
    BuildContext context, {
    required EmergencyExitKind kind,
    required VoidCallback onConfirmed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EmergencyExitSheet(kind: kind, onConfirmed: onConfirmed),
      ),
    );
  }

  @override
  State<EmergencyExitSheet> createState() => _EmergencyExitSheetState();
}

class _EmergencyExitSheetState extends State<EmergencyExitSheet> {
  final _controller = TextEditingController();
  bool _inGrace = false;
  int _remaining = 0;
  int _graceDaysLeft = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final grace = await PrayerPreferencesService.isInFirstWeekGrace();
    final remaining = await PrayerPreferencesService.getRemainingEmergenciesThisWeek();
    final graceLeft = await PrayerPreferencesService.firstWeekDaysRemaining();
    if (mounted) {
      setState(() {
        _inGrace = grace;
        _remaining = remaining;
        _graceDaysLeft = graceLeft;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final l10n = AppLocalizations.of(context);
    if (widget.kind == EmergencyExitKind.morning) {
      return EmergencyExitService.morningPhraseMatches(_controller.text, l10n);
    }
    return EmergencyExitService.eveningReasonValid(_controller.text);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!await PrayerPreferencesService.canUseEmergency()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).emergencyNotAvailable),
        ),
      );
      return;
    }
    await PrayerPreferencesService.recordEmergencyUse();
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const textColor = Colors.white;
    const muted = Color(0xFFB0B0B0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.emergencyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.kind == EmergencyExitKind.morning
                  ? l10n.emergencyMorningHint
                  : l10n.emergencyEveningHint,
              style: const TextStyle(
                fontSize: 13,
                color: muted,
                height: 1.45,
              ),
            ),
            if (!_loading) ...[
              const SizedBox(height: 10),
              Text(
                _inGrace
                    ? l10n.emergencyGraceRemaining(_graceDaysLeft)
                    : l10n.emergencyRemainingThisWeek(_remaining),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.kind == EmergencyExitKind.morning)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Text(
                  l10n.emergencyMorningPhrase,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textColor,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: textColor,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: l10n.emergencyEveningPrefix),
                    const TextSpan(
                      text: ' ______ ',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Color(0xFFCCCCCC),
                      ),
                    ),
                    TextSpan(text: l10n.emergencyEveningSuffix),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: widget.kind == EmergencyExitKind.morning ? 2 : 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: textColor, fontSize: 16),
              cursorColor: textColor,
              decoration: InputDecoration(
                hintText: widget.kind == EmergencyExitKind.morning
                    ? l10n.emergencyTypePhraseHint
                    : l10n.emergencyEveningReasonHint,
                hintStyle: const TextStyle(color: muted),
                filled: true,
                fillColor: const Color(0xFF252525),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: textColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.emergencyConfirm),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
