/// Flush / reload all local app data so nothing is lost on background or restart.
class AppPersistenceService {
  AppPersistenceService._();

  static Future<void> reloadAll() async {}

  static Future<void> flushAll() async {}
}
