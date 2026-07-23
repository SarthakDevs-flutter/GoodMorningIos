import '../l10n/app_localizations.dart';

/// Validates emergency confession text for morning and evening alarms.
class EmergencyExitService {
  EmergencyExitService._();

  static String normalize(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?…]+$'), '');
  }

  static String morningRequiredPhrase(AppLocalizations l10n) =>
      normalize(l10n.emergencyMorningPhrase);

  static bool morningPhraseMatches(String input, AppLocalizations l10n) {
    return normalize(input) == morningRequiredPhrase(l10n);
  }

  static String eveningReasonPrefix(AppLocalizations l10n) =>
      l10n.emergencyEveningPrefix;

  static String eveningReasonSuffix(AppLocalizations l10n) =>
      l10n.emergencyEveningSuffix;

  static String buildEveningConfession(
    String reason,
    AppLocalizations l10n,
  ) {
    final trimmed = reason.trim();
    return '${eveningReasonPrefix(l10n)}$trimmed${eveningReasonSuffix(l10n)}';
  }

  static bool eveningReasonValid(String reason) {
    final trimmed = reason.trim();
    return trimmed.length >= 2;
  }
}
