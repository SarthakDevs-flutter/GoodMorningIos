import '../data/daily_content.dart';

/// 요일별 아침 묵상 테마 (AI 프롬프트 + 오프라인 fallback)
class WeekdayThemedContent {
  WeekdayThemedContent._();

  static const themes = {
    DateTime.monday: WeekdayTheme(
      label: 'Monday',
      name: 'Fresh Start',
      topic:
          'new beginnings, courage for the week ahead, and trusting God at the start of work',
    ),
    DateTime.tuesday: WeekdayTheme(
      label: 'Tuesday',
      name: 'Wisdom',
      topic:
          'seeking God\'s wisdom, discernment in decisions, and guidance in daily choices',
    ),
    DateTime.wednesday: WeekdayTheme(
      label: 'Wednesday',
      name: 'Perseverance',
      topic: 'midweek faith, endurance, and not growing weary in doing good',
    ),
    DateTime.thursday: WeekdayTheme(
      label: 'Thursday',
      name: 'Gratitude',
      topic:
          'thanksgiving, counting blessings, and a grateful heart before God',
    ),
    DateTime.friday: WeekdayTheme(
      label: 'Friday',
      name: 'Trust',
      topic:
          'surrendering the week to God, resting in his care, and peaceful trust',
    ),
    DateTime.saturday: WeekdayTheme(
      label: 'Saturday',
      name: 'Rest',
      topic: 'Sabbath rest, stillness before God, and quiet reflection',
    ),
    DateTime.sunday: WeekdayTheme(
      label: 'Sunday',
      name: 'Worship',
      topic:
          'worship, resurrection joy, gathering with God\'s people, and praise',
    ),
  };

  static WeekdayTheme themeFor(int weekday) {
    return themes[weekday] ?? themes[DateTime.monday]!;
  }

  /// Offline fallback. The active app content comes from the 365-day God
  /// Morning devotional library, so fallback must not carry old verse/prayer
  /// copy.
  static DailyContentItem fallbackFor(int weekday) {
    return DailyContent.forToday();
  }
}

class WeekdayTheme {
  const WeekdayTheme({
    required this.label,
    required this.name,
    required this.topic,
  });

  final String label;
  final String name;
  final String topic;
}

/// AI/테마 기반 아침 콘텐츠 (기도 요청 없을 때)
class ThemedDailyContent {
  const ThemedDailyContent({
    required this.content,
    required this.themeName,
    required this.weekdayLabel,
    required this.isAiGenerated,
  });

  final DailyContentItem content;
  final String themeName;
  final String weekdayLabel;
  final bool isAiGenerated;
}
