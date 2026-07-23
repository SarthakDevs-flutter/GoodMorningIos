import '../data/daily_content.dart';
import '../data/morning_devotional_content.dart';
import '../data/weekday_themed_content.dart';
import 'locale_service.dart';
import 'prayer_preferences_service.dart';

/// Offline morning devotion content.
///
/// The class name is kept for compatibility with existing callers, but this
/// service no longer calls OpenAI or any network API. Content is selected from
/// the curated offline devotion library bundled with the app.
class AiDailyContentService {
  AiDailyContentService._();

  static final AiDailyContentService instance = AiDailyContentService._();

  Future<ThemedDailyContent> getTodayContent([DateTime? date]) async {
    final plan = await PrayerPreferencesService.getScripturePlan();
    final item = MorningDevotionalContent.forDate(
      date,
      LocaleService.instance.locale.languageCode,
      plan,
    );
    return ThemedDailyContent(
      content: DailyContentItem(
        prayer: item.prayer,
        verse: item.verse,
        reference: item.reference,
      ),
      themeName: item.themeName,
      weekdayLabel: item.weekdayLabel,
      isAiGenerated: false,
    );
  }
}
