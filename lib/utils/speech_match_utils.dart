/// Shared speech-to-text locale selection and prayer text matching.
class SpeechMatchUtils {
  SpeechMatchUtils._();

  /// ~80% of words in order — enough for STT errors, still requires reading aloud.
  static const matchThreshold = 0.80;

  /// Long pause tolerance while reading a prayer aloud.
  static const listenFor = Duration(minutes: 5);

  /// Wait up to 20s of silence before ending a listen segment (auto-resumes).
  static const pauseFor = Duration(seconds: 20);

  static bool textHasKorean(String text) => RegExp(r'[가-힣]').hasMatch(text);

  static bool textHasCyrillic(String text) =>
      RegExp(r'[а-яА-ЯёЁ]').hasMatch(text);

  static bool textHasLatin(String text) =>
      RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(text);

  /// CJK ideographs (Chinese, and kanji within Japanese).
  static bool textHasHan(String text) =>
      RegExp(r'[一-鿿]').hasMatch(text);

  /// Hiragana/katakana — present in any Japanese sentence, never in Chinese.
  static bool textHasKana(String text) =>
      RegExp(r'[぀-ヿ]').hasMatch(text);

  /// Languages without reliable word spacing match by character 2-grams.
  static bool usesChunkMatching(String text) =>
      textHasKorean(text) ||
      textHasCyrillic(text) ||
      textHasHan(text) ||
      textHasKana(text);

  static String combineTranscript(String committed, String partial) {
    final c = committed.trim();
    final p = partial.trim();
    if (c.isEmpty) return p;
    if (p.isEmpty) return c;
    return '$c $p';
  }

  static String appendFinalTranscript(String committed, String finalWords) {
    final trimmed = finalWords.trim();
    if (trimmed.isEmpty) return committed.trim();
    if (committed.trim().isEmpty) return trimmed;

    final committedLower = committed.toLowerCase();
    final trimmedLower = trimmed.toLowerCase();
    if (trimmedLower.startsWith(committedLower)) return trimmed;
    if (committedLower.contains(trimmedLower)) return committed.trim();

    final committedWords = committed.trim().split(RegExp(r'\s+'));
    final finalWordsList = trimmed.split(RegExp(r'\s+'));
    final committedNorm = committedWords.map(_normalizeWord).toList();
    final finalNorm = finalWordsList.map(_normalizeWord).toList();
    final maxOverlap = committedNorm.length < finalNorm.length
        ? committedNorm.length
        : finalNorm.length;
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      var matches = true;
      for (var i = 0; i < overlap; i++) {
        if (committedNorm[committedNorm.length - overlap + i] != finalNorm[i]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        final merged = [
          ...committedWords,
          ...finalWordsList.skip(overlap),
        ].join(' ');
        return merged.trim();
      }
    }

    return '$committed $trimmed'.trim();
  }

  /// Android/iOS speech partials are not guaranteed to be cumulative. After a
  /// pause, a new partial can replace "The Lord is" with "my shepherd". In
  /// that case the UI must commit the old partial before displaying the new
  /// one, otherwise the first spoken words appear to disappear.
  static bool shouldCommitPartialBeforeReplacing(
    String previousPartial,
    String nextPartial,
  ) {
    final previousWords = _normalizedWords(previousPartial);
    final nextWords = _normalizedWords(nextPartial);
    if (previousWords.length < 2 || nextWords.isEmpty) return false;

    final previous = previousWords.join(' ');
    final next = nextWords.join(' ');
    if (previous == next) return false;
    if (next.startsWith(previous) || next.contains(previous)) return false;
    if (previous.startsWith(next) || previous.contains(next)) {
      // 새 부분 인식이 이전의 일부만 남기는 경우: 소폭 축소는 인식 엔진의
      // 수정(교체 허용), 대폭 축소(4단어 이상 손실)는 같은 단어로 시작하는
      // "새 문장"일 가능성이 높다 — 이전 내용을 커밋해 잃지 않는다.
      return previousWords.length - nextWords.length >= 4;
    }
    if (_orderedOverlapRatio(previousWords, nextWords) >= 0.65) return false;

    final minLength = previousWords.length < nextWords.length
        ? previousWords.length
        : nextWords.length;
    var commonPrefix = 0;
    while (commonPrefix < minLength &&
        previousWords[commonPrefix] == nextWords[commonPrefix]) {
      commonPrefix++;
    }
    if (commonPrefix / minLength >= 0.55) return false;

    return true;
  }

  static double _orderedOverlapRatio(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          final up = dp[i - 1][j];
          final left = dp[i][j - 1];
          dp[i][j] = up > left ? up : left;
        }
      }
    }
    final shorter = a.length < b.length ? a.length : b.length;
    return dp[a.length][b.length] / shorter;
  }

  /// Pick STT locale from the text being read, not only app UI language.
  static String speechLocalePrefix(String text, {String appLang = 'en'}) {
    if (textHasKorean(text)) return 'ko';
    // Kana before Han: Japanese sentences contain kanji, Chinese has no kana.
    if (textHasKana(text)) return 'ja';
    if (textHasHan(text)) return 'zh';
    if (textHasCyrillic(text)) return 'ru';
    if (textHasLatin(text)) {
      return switch (appLang) {
        'de' => 'de',
        'es' => 'es',
        'pt' => 'pt',
        _ => 'en',
      };
    }
    return switch (appLang) {
      'ko' => 'ko',
      'ru' => 'ru',
      'de' => 'de',
      'es' => 'es',
      'pt' => 'pt',
      'zh' => 'zh',
      'ja' => 'ja',
      _ => 'en',
    };
  }

  // listen을 재시작할 때마다 기기 전체 로케일 목록을 플러그인 왕복으로
  // 조회하면 첫 인식이 그만큼 늦는다 — prefix별로 한 번만 조회해 캐시.
  static final Map<String, String> _localeIdCache = {};

  static Future<String> resolveLocaleId({
    required Future<List<dynamic>> Function() fetchLocales,
    required String text,
    String appLang = 'en',
    String fallback = 'en_US',
  }) async {
    final prefix = speechLocalePrefix(text, appLang: appLang);
    final cacheKey = '$prefix|$fallback';
    final cached = _localeIdCache[cacheKey];
    if (cached != null) return cached;
    final locales = await fetchLocales();
    final matched = locales.where(
      (locale) => (locale.localeId as String).startsWith(prefix),
    );
    final resolved = matched.isNotEmpty
        ? matched.first.localeId as String
        : (prefix == 'en'
              ? fallback
              : (locales.isNotEmpty
                    ? locales.first.localeId as String
                    : fallback));
    _localeIdCache[cacheKey] = resolved;
    return resolved;
  }

  static bool canAdvance(String target, String spoken, {double? threshold}) {
    final min = threshold ?? matchThreshold;
    return matchProgress(target, spoken) >= min;
  }

  // ── 타이핑 채점(문자 정렬) ─────────────────────────────────────────
  // 타이핑 필드는 글자·숫자만 입력받아 대상의 '입력 가능 문자' 순서열에
  // 위치별로 비교한다(공백·부호는 자동 통과). 채점도 같은 규칙이어야
  // 화면 강조와 퍼센트가 일치한다. 단어(공백) 기반 음성 매처에 공백 없는
  // 타이핑 입력을 넣으면 통째로 한 토큰이 되어 전 언어 0%가 된다 — 금지.
  static final RegExp _typableCharPattern = RegExp(
    r'[\p{L}\p{N}]',
    unicode: true,
  );

  static List<String> _typableCharList(String value) {
    final chars = <String>[];
    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      if (_typableCharPattern.hasMatch(ch)) chars.add(ch);
    }
    return chars;
  }

  /// 타이핑 진행률: 맞게 타이핑한 문자 수 ÷ 대상의 입력 가능 문자 수.
  /// 위치 정렬·대소문자 무시 — 오타 자리는 0점, 이후 맞은 자리는 그대로 인정.
  static double typedMatchProgress(String target, String typed) {
    final targetChars = _typableCharList(target);
    if (targetChars.isEmpty) return 0;
    final typedChars = _typableCharList(typed);
    final compared = typedChars.length < targetChars.length
        ? typedChars.length
        : targetChars.length;
    var correct = 0;
    for (var i = 0; i < compared; i++) {
      if (typedChars[i].toLowerCase() == targetChars[i].toLowerCase()) {
        correct++;
      }
    }
    return correct / targetChars.length;
  }

  static bool canAdvanceTyped(
    String target,
    String typed, {
    double? threshold,
  }) {
    return typedMatchProgress(target, typed) >= (threshold ?? matchThreshold);
  }

  /// 진행률에 해당하는 '입력 가능 문자' 접두를 이어붙인 시드 — 녹음→타이핑
  /// 전환 시 타이핑 필드를 그 지점부터 이어가게 채운다.
  static String typedSeedForProgress(String target, double progress) {
    final targetChars = _typableCharList(target);
    final count = (targetChars.length * progress.clamp(0.0, 1.0)).round();
    return targetChars.take(count).join();
  }

  /// 타이핑으로 맞힌 분량에 해당하는 원문 접두(공백·부호 포함) — 타이핑→녹음
  /// 전환 시 음성 매처가 이해하는 형태로 진행률을 넘긴다.
  static String typedProgressTargetPrefix(String target, String typed) {
    final targetChars = _typableCharList(target);
    if (targetChars.isEmpty) return '';
    final typedChars = _typableCharList(typed);
    final compared = typedChars.length < targetChars.length
        ? typedChars.length
        : targetChars.length;
    var correct = 0;
    for (var i = 0; i < compared; i++) {
      if (typedChars[i].toLowerCase() == targetChars[i].toLowerCase()) {
        correct++;
      }
    }
    if (correct == 0) return '';
    final buffer = StringBuffer();
    var consumed = 0;
    for (final rune in target.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(ch);
      if (_typableCharPattern.hasMatch(ch)) {
        consumed++;
        if (consumed >= correct) break;
      }
    }
    return buffer.toString().trim();
  }

  static bool matches(String target, String spoken, {double? threshold}) =>
      canAdvance(target, spoken, threshold: threshold);

  static double matchProgress(String target, String spoken) {
    if (usesChunkMatching(target)) {
      return _chunkMatchRatio(target, spoken);
    }
    return _wordMatchRatio(target, spoken);
  }

  static bool canAdvanceVoice(
    String target,
    String spoken, {
    double? threshold,
  }) {
    final min = threshold ?? matchThreshold;
    return voiceMatchProgress(target, spoken) >= min;
  }

  /// Voice recognition is noisier than typing. Score against the original
  /// target text, accepting close STT variants so the UI fills calmly instead
  /// of punishing tiny recognition errors.
  /// 시편 표제 등 낭독 대상이 아닌 대괄호 구간을 매칭 타깃에서 제거한다.
  /// 예: "[다윗의 믹담] 하나님이여..." → "하나님이여..." (화면 표시는 그대로).
  static String stripUnreadableMarkers(String text) {
    return text
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double voiceMatchProgress(String target, String spoken) {
    final strictProgress = matchProgress(target, spoken);
    if (usesChunkMatching(target)) return strictProgress;

    final softProgress = _softWordMatchRatio(target, spoken);
    final phraseProgress = _phraseMatchRatio(target, spoken);
    return [
      strictProgress,
      softProgress,
      phraseProgress,
    ].reduce((a, b) => a > b ? a : b);
  }

  /// Phrase bank used by the voice matcher. The current speech_to_text plugin
  /// does not expose Apple's contextualStrings API, so these phrase hints are
  /// applied in-app when correcting the recognized transcript.
  static List<String> speechHintPhrases(String target, {int maxPhrases = 80}) {
    final words = _latinWords(target);
    if (words.isEmpty) return const [];

    final phrases = <String>{target.trim()};
    for (final size in [4, 3, 2]) {
      for (var i = 0; i <= words.length - size; i++) {
        phrases.add(words.sublist(i, i + size).join(' '));
        if (phrases.length >= maxPhrases) return phrases.toList();
      }
    }
    return phrases.toList();
  }

  /// Words must appear in reading order inside the spoken transcript.
  static double _wordMatchRatio(String target, String spoken) {
    final targetWords = _latinWords(target);
    final spokenWords = _latinWords(spoken);
    if (targetWords.isEmpty) return 0;
    if (spokenWords.isEmpty) return 0;

    var searchFrom = 0;
    var matched = 0;

    for (final word in targetWords) {
      final idx = _indexOfCloseWord(spokenWords, word, searchFrom);
      if (idx >= 0) {
        matched++;
        searchFrom = idx + 1;
      }
    }

    return matched / targetWords.length;
  }

  static double _softWordMatchRatio(String target, String spoken) {
    final targetWords = _latinWords(target);
    final spokenWords = _latinWords(spoken);
    if (targetWords.isEmpty || spokenWords.isEmpty) return 0;

    var searchFrom = 0;
    var matched = 0;

    for (final targetWord in targetWords) {
      final idx = _indexOfSoftWord(spokenWords, targetWord, searchFrom);
      if (idx >= 0) {
        matched++;
        searchFrom = idx + 1;
      }
    }

    return matched / targetWords.length;
  }

  static double _phraseMatchRatio(String target, String spoken) {
    final targetWords = _latinWords(target);
    final spokenWords = _latinWords(spoken);
    if (targetWords.length < 2 || spokenWords.length < 2) return 0;

    final spokenPhrases = <String>{};
    for (final size in [4, 3, 2]) {
      for (var i = 0; i <= spokenWords.length - size; i++) {
        spokenPhrases.add(spokenWords.sublist(i, i + size).join(' '));
      }
    }

    var total = 0;
    var matched = 0;
    for (final size in [4, 3, 2]) {
      for (var i = 0; i <= targetWords.length - size; i++) {
        total++;
        final phrase = targetWords.sublist(i, i + size).join(' ');
        if (spokenPhrases.contains(phrase)) matched++;
      }
    }
    if (total == 0) return 0;

    // Phrase matches are a confidence boost, not the whole score. Blend them
    // with spoken coverage so a few exact phrases cannot unlock the mission.
    final spokenCoverage = (spokenWords.length / targetWords.length)
        .clamp(0.0, 1.0)
        .toDouble();
    return (matched / total) * spokenCoverage;
  }

  static int _indexOfCloseWord(
    List<String> words,
    String target,
    int startIndex,
  ) {
    for (var i = startIndex; i < words.length; i++) {
      final spoken = words[i];
      if (spoken == target) return i;

      // STT often drops possessive/apostrophe endings or adds a tiny suffix.
      // Accept close containment for longer words, but keep short words exact.
      if (target.length >= 4 &&
          spoken.length >= 4 &&
          (spoken.contains(target) || target.contains(spoken))) {
        return i;
      }
    }
    return -1;
  }

  static int _indexOfSoftWord(
    List<String> words,
    String target,
    int startIndex,
  ) {
    for (var i = startIndex; i < words.length; i++) {
      final spoken = words[i];
      if (_voiceWordsMatch(target, spoken)) return i;

      // Apple Speech sometimes splits a Bible word into two nearby tokens.
      if (i + 1 < words.length &&
          _voiceWordsMatch(target, '$spoken${words[i + 1]}')) {
        return i + 1;
      }
    }
    return -1;
  }

  static bool _voiceWordsMatch(String target, String spoken) {
    if (spoken == target) return true;
    if (target.length <= 3 || spoken.length <= 3) return false;

    if (spoken.contains(target) || target.contains(spoken)) {
      final short = spoken.length < target.length
          ? spoken.length
          : target.length;
      final long = spoken.length > target.length
          ? spoken.length
          : target.length;
      return short / long >= 0.70;
    }

    final similarity = _wordSimilarity(target, spoken);
    if (target.length <= 5) return similarity >= 0.80;
    return similarity >= 0.74;
  }

  static double _wordSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshteinDistance(a, b);
    final maxLength = a.length > b.length ? a.length : b.length;
    return 1 - (distance / maxLength);
  }

  static int _levenshteinDistance(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final substitutionCost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final substitute = previous[j] + substitutionCost;
        current[j + 1] = _min3(insert, delete, substitute);
      }
      for (var j = 0; j < previous.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  static int _min3(int a, int b, int c) {
    final minAB = a < b ? a : b;
    return minAB < c ? minAB : c;
  }

  static String _normalizeWord(String word) => word.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );

  static List<String> _normalizedWords(String text) => text
      .split(RegExp(r'\s+'))
      .map(_normalizeWord)
      .where((word) => word.isNotEmpty)
      .toList();

  static List<String> _latinWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 2)
        .toList();
  }

  static double _chunkMatchRatio(String target, String spoken) {
    final normalizedTarget = target.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
    final normalizedSpoken = spoken.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );

    if (normalizedTarget.isEmpty) return 0;
    if (normalizedSpoken.contains(normalizedTarget)) return 1;

    final chunks = <String>[];
    for (var i = 0; i < normalizedTarget.length - 1; i++) {
      chunks.add(normalizedTarget.substring(i, i + 2));
    }
    if (chunks.isEmpty) return 0;

    var searchFrom = 0;
    var matched = 0;
    for (final chunk in chunks) {
      final idx = normalizedSpoken.indexOf(chunk, searchFrom);
      if (idx >= 0) {
        matched++;
        searchFrom = idx + 1;
      }
    }
    return matched / chunks.length;
  }
}
