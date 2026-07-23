import 'morning_devotional_content.dart';

/// 자녀 축복 시간 (아론의 축복, 민수기 6:24-26) — 8개 언어,
/// 아침 말씀과 동일한 공개도메인 번역본에서 가져온 실제 본문.
/// (en WEB · ko 개역한글 · de Elberfelder 1905 · ru Синодальный ·
///  es Sagradas Escrituras 1569 · pt Bíblia Livre · zh 和合本 · ja 口語訳)
class EveningBlessingContent {
  EveningBlessingContent._();

  static const title = 'Bless before you rest';

  static const guide = 'Place your hand on your child and pray:';

  static const Map<String, String> _prayers = {
    'en':
        'May the Lord bless you and keep you; may the Lord make his face shine '
        'upon you and be gracious to you; may the Lord turn his face toward you '
        'and give you peace.',
    'ko':
        '여호와는 네게 복을 주시고 너를 지키시기를 원하며 여호와는 그 얼굴로 네게 비취사 은혜 베푸시기를 원하며 여호와는 그 얼굴을 네게로 향하여 드사 평강주시기를 원하노라 아버지와 아들과 성령의 이름으로 축복하며 기도합니다. 아멘',
    'de':
        'Jehova segne dich und behüte dich! Jehova lasse sein Angesicht über dir leuchten und sei dir gnädig! Jehova erhebe sein Angesicht auf dich und gebe dir Frieden!',
    'ru':
        'да благословит тебя Господь и сохранит тебя! да призрит на тебя Господь светлым лицем Своим и помилует тебя! да обратит Господь лице Свое на тебя и даст тебе мир!',
    'es':
        'Jehová te bendiga, y te guarde: Haga resplandecer Jehová su rostro sobre ti, y haya de ti misericordia: Jehová alce a ti su rostro, y ponga en ti paz.',
    'pt':
        'O SENHOR te abençoe, e te guarde: Faça resplandecer o SENHOR seu rosto sobre ti, e tenha de ti misericórdia: O SENHOR levante a ti seu rosto, e ponha em ti paz.',
    'zh':
        '『愿耶和华赐福给你，保护你。 愿耶和华使他的脸光照你，赐恩给你。 愿耶和华向你仰脸，赐你平安。』',
    'ja':
        '「願わくは主があなたを祝福し、あなたを守られるように。 願わくは主がみ顔をもってあなたを照し、あなたを恵まれるように。 願わくは主がみ顔をあなたに向け、あなたに平安を賜わるように」』。',
  };

  static const Map<String, String> _references = {
    'en': 'Numbers 6:24-26',
    'ko': '민수기 6:24-26',
    'de': '4. Mose 6,24-26',
    'ru': 'Числа 6:24-26',
    'es': 'Números 6:24-26',
    'pt': 'Números 6:24-26',
    'zh': '民数记 6:24-26',
    'ja': '民数記 6:24-26',
  };

  /// 현재 앱 언어의 축복 본문.
  static String prayerFor(String languageCode) {
    final code = MorningDevotionalLocalization.normalize(languageCode);
    return _prayers[code] ?? _prayers['en']!;
  }

  static String referenceFor(String languageCode) {
    final code = MorningDevotionalLocalization.normalize(languageCode);
    return _references[code] ?? _references['en']!;
  }

  static String translationLabelFor(String languageCode) {
    final code = MorningDevotionalLocalization.normalize(languageCode);
    // 영어는 공개도메인 축도문(전통 축복) — 특정 번역본 라벨을 붙이지 않는다.
    if (code == 'en') return 'Traditional blessing';
    return MorningDevotionalLocalization.translationLabel(code);
  }

  /// 하위호환: 기존 호출부(영문 고정)용.
  static String get prayer => _prayers['en']!;

  static const reference = 'Numbers 6:24-26';
}
