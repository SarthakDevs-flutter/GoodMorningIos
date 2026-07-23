/// Tracks whether the splash / launch gate has finished.
class AppLaunchState {
  AppLaunchState._();

  static bool bootComplete = false;

  static void markBootComplete() {
    bootComplete = true;
  }

  static void resetForTest() {
    bootComplete = false;
  }
}
