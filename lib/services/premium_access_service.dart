import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store_subscription_service.dart';

class PremiumAccessService {
  PremiumAccessService._();

  static const trialDays = 7;
  // iOS App Store: 구독 필수(7일 무료체험 후 결제). 무료 개방은 환경변수로만
  // 켤 수 있다. Android는 betaAccessEnabled(안드로이드 전용)로 계속 열려 있음.
  static const launchFreeAccessEnabled = bool.fromEnvironment(
    'GOD_MORNING_LAUNCH_FREE_ACCESS',
    defaultValue: false,
  );
  static const _legacyDeveloperBypassEnabled = bool.fromEnvironment(
    'GOD_MORNING_DEV_BYPASS',
    defaultValue: false,
  );
  // App Store 제출용: false. 개발 중 우회가 필요하면
  // --dart-define=GOD_MORNING_DEV_ACCESS=true 로 빌드한다.
  static const developerAccessEnabled =
      bool.fromEnvironment('GOD_MORNING_DEV_ACCESS', defaultValue: false) ||
      _legacyDeveloperBypassEnabled;
  static const androidBetaAccessEnabled = bool.fromEnvironment(
    'GOD_MORNING_ANDROID_BETA_ACCESS',
    defaultValue: true,
  );
  static const _premiumUnlockedKey = 'premium_access_unlocked';
  static const _developerAccessUnlockedKey = 'developer_access_unlocked';

  static bool get betaAccessEnabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      androidBetaAccessEnabled;

  static Future<void> ensureTrialStarted() async {}

  static Future<int> trialDaysRemaining() async => 0;

  static Future<bool> isTrialActive() async => false;

  static Future<bool> isPremiumUnlocked() async {
    if (betaAccessEnabled) return true;
    if (await isDeveloperAccessUnlocked()) return true;

    final activeSubscription =
        await StoreSubscriptionService.hasActiveSubscription();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumUnlockedKey, activeSubscription);
    return activeSubscription;
  }

  static Future<bool> hasAccess() async {
    if (launchFreeAccessEnabled) return true;
    if (betaAccessEnabled) return true;
    if (await isDeveloperAccessUnlocked()) return true;
    return isPremiumUnlocked();
  }

  static Future<bool> refreshPremiumStatus() {
    return isPremiumUnlocked();
  }

  static Future<void> markPremiumUnlockedForPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumUnlockedKey, true);
  }

  static Future<bool> isDeveloperAccessUnlocked() async {
    if (!developerAccessEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_developerAccessUnlockedKey) ?? false;
  }

  static Future<void> markDeveloperAccessUnlocked() async {
    if (!developerAccessEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerAccessUnlockedKey, true);
    await prefs.setBool(_premiumUnlockedKey, true);
  }
}
