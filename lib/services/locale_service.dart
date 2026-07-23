import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language preference (persisted)
class LocaleService extends ChangeNotifier {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const _keyLanguageCode = 'app_language_code';

  static const supportedLocales = [
    Locale('en'),
    Locale('ko'),
    Locale('de'),
    Locale('ru'),
    Locale('es'),
    Locale('pt'),
    Locale('zh'),
    Locale('ja'),
  ];

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLanguageCode);
    if (code != null) {
      final supported = supportedLocales.any(
        (locale) => locale.languageCode == code,
      );
      _locale = supported ? Locale(code) : const Locale('en');
      notifyListeners();
      return;
    }

    _locale = _resolveDeviceLocale();
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguageCode, locale.languageCode);
  }

  String displayNameFor(Locale locale) {
    return switch (locale.languageCode) {
      'en' => 'English',
      'ko' => '한국어',
      'de' => 'Deutsch',
      'ru' => 'Русский',
      'es' => 'Español',
      'pt' => 'Português',
      'zh' => '中文',
      'ja' => '日本語',
      _ => locale.languageCode,
    };
  }

  Locale _resolveDeviceLocale() {
    final deviceLocales = WidgetsBinding.instance.platformDispatcher.locales;

    for (final deviceLocale in deviceLocales) {
      for (final supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode == deviceLocale.languageCode) {
          return supportedLocale;
        }
      }
    }

    return const Locale('en');
  }
}
