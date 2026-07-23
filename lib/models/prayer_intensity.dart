/// How much of each prayer step must be read or typed before advancing.
enum PrayerIntensity {
  gentle,
  normal,
  strict;

  double get matchThreshold => switch (this) {
        PrayerIntensity.gentle => 0.65,
        PrayerIntensity.normal => 0.80,
        PrayerIntensity.strict => 0.90,
      };

  /// Emergency exits allowed per calendar week (after first 7 days).
  int get weeklyEmergencyLimit => switch (this) {
        PrayerIntensity.gentle => 3,
        PrayerIntensity.normal => 1,
        PrayerIntensity.strict => 0,
      };
}
