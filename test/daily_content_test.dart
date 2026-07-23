import 'package:flutter_test/flutter_test.dart';
import 'package:means_of_grace/data/daily_content.dart';
import 'package:means_of_grace/data/morning_devotional_content.dart';
import 'package:means_of_grace/models/scripture_plan.dart';

void main() {
  test('365 Psalms and Prayers has a full year of content', () {
    expect(DailyContent.items.length, 365);
  });

  test('365 Psalms and Prayers has complete bundled content', () {
    for (final item in DailyContent.items) {
      expect(item.reference.trim(), isNotEmpty);
      expect(item.verse.trim(), isNotEmpty);
      expect(item.prayer.trim(), isNotEmpty);
    }
  });

  test('daily lookup returns one of the bundled Psalm readings', () {
    final item = DailyContent.forToday(DateTime(2026, 1, 5));
    final references = DailyContent.items.map((item) => item.reference).toSet();

    expect(references, contains(item.reference));
    expect(item.verse.trim(), isNotEmpty);
    expect(item.prayer.trim(), isNotEmpty);
  });

  test('365 Psalms and Prayers is localized in all devotional languages', () {
    for (final languageCode in [
      'en',
      'ko',
      'de',
      'ru',
      'es',
      'pt',
      'zh',
      'ja',
    ]) {
      final item = MorningDevotionalContent.forDate(
        DateTime(2026, 1, 5),
        languageCode,
      );

      expect(item.reference.trim(), isNotEmpty);
      expect(item.verse.trim(), isNotEmpty);
      expect(item.prayer.trim(), isNotEmpty);
      expect(item.languageCode, languageCode);
    }

    final english = MorningDevotionalContent.forDate(
      DateTime(2026, 1, 5),
      'en',
    );
    final german = MorningDevotionalContent.forDate(DateTime(2026, 1, 5), 'de');
    final russian = MorningDevotionalContent.forDate(
      DateTime(2026, 1, 5),
      'ru',
    );
    final spanish = MorningDevotionalContent.forDate(
      DateTime(2026, 1, 5),
      'es',
    );

    expect(german.verse, isNot(english.verse));
    expect(russian.verse, isNot(english.verse));
    expect(spanish.verse, isNot(english.verse));
    expect(german.prayer, isNot(english.prayer));
    expect(russian.prayer, isNot(english.prayer));
    expect(spanish.prayer, isNot(english.prayer));
  });

  test('Psalm superscriptions are omitted from localized verse text', () {
    for (final languageCode in [
      'en',
      'ko',
      'de',
      'ru',
      'es',
      'pt',
      'zh',
      'ja',
    ]) {
      for (final item in MorningDevotionalContent.all(languageCode)) {
        expect(item.verse, isNot(startsWith('[')));
        expect(item.verse, isNot(endsWith('Псалом Давида. Учение.')));
      }
    }
  });

  test('52 Beloved Verses remains separate from the Psalm plan', () {
    final item = MorningDevotionalContent.forDate(
      DateTime(2026, 1, 5),
      'en',
      ScripturePlan.beloved52,
    );

    expect(item.reference, 'Isaiah 41:10');
    expect(item.verse.trim(), isNotEmpty);
    expect(item.prayer.trim(), isNotEmpty);
  });
}
