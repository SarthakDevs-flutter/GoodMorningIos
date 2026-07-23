import 'morning_devotional_content.dart';

/// 하루에 표시할 기도문·성경 구절 한 세트.
class DailyContentItem {
  const DailyContentItem({
    required this.prayer,
    required this.verse,
    required this.reference,
  });

  /// 한 줄 아침 기도문.
  final String prayer;

  /// 성경 본문.
  final String verse;

  /// 출처.
  final String reference;
}

/// Compatibility wrapper around the God Morning 365-day devotional library.
class DailyContent {
  DailyContent._();

  static List<DailyContentItem> get items {
    return MorningDevotionalContent.all('en')
        .map(
          (item) => DailyContentItem(
            prayer: item.prayer,
            verse: item.verse,
            reference: item.reference,
          ),
        )
        .toList(growable: false);
  }

  static int dayOfYear([DateTime? date]) {
    final today = date ?? DateTime.now();
    final startOfYear = DateTime(today.year, 1, 1);
    return today.difference(startOfYear).inDays + 1;
  }

  static DailyContentItem forToday([DateTime? date]) {
    final item = MorningDevotionalContent.forDate(date, 'en');
    return DailyContentItem(
      prayer: item.prayer,
      verse: item.verse,
      reference: item.reference,
    );
  }
}
