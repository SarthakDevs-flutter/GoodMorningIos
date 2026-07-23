import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_preferences_service.dart';

class AppBootstrap {
  AppBootstrap._();

  static const _onboardingDoneKey = 'permissions_onboarding_done';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    await PrayerPreferencesService.ensureFirstUseDate();
  }
}
