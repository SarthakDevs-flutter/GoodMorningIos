/// 완료 기록 유형
enum CompletionType {
  morning('morning'),
  evening('evening');

  const CompletionType(this.value);
  final String value;
}

/// Local-only completion hook.
///
/// The alarm screens still call this service so the completion flow remains
/// stable even though completion sync is not part of the release app.
class CompletionService {
  CompletionService._();

  static final CompletionService instance = CompletionService._();

  /// 아침/저녁 알람 성공 시 호출
  Future<void> record({
    required CompletionType type,
    required bool prayerRead,
    required bool verseRead,
  }) async {}

  static DateTime weekStartMonday(DateTime date) {
    final weekday = date.weekday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: weekday - DateTime.monday));
  }
}
