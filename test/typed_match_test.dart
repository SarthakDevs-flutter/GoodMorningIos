import 'package:flutter_test/flutter_test.dart';

import 'package:means_of_grace/utils/speech_match_utils.dart';

void main() {
  const koTarget = '태초에 하나님이 천지를 창조하시니라.';
  const enTarget = 'In the beginning God created the heavens.';

  group('typedMatchProgress — 문자 정렬 채점', () {
    test('공백 없이 맞게 타이핑한 만큼 퍼센트가 오른다(한국어)', () {
      // 입력 필드는 공백·부호를 걸러 글자만 남긴다 — 그 형태 그대로 채점.
      final p = SpeechMatchUtils.typedMatchProgress(koTarget, '태초에하나님이');
      expect(p, closeTo(7 / 16, 0.001));
    });

    test('전부 타이핑하면 100%', () {
      final p = SpeechMatchUtils.typedMatchProgress(
        koTarget,
        '태초에하나님이천지를창조하시니라',
      );
      expect(p, 1.0);
    });

    test('오타 자리만 감점, 이후 맞은 자리는 인정', () {
      // '님'을 '남'으로 오타 — 그 한 자리만 0점.
      final p = SpeechMatchUtils.typedMatchProgress(koTarget, '태초에하나남이');
      expect(p, closeTo(6 / 16, 0.001));
    });

    test('영어는 대소문자 무시', () {
      final p = SpeechMatchUtils.typedMatchProgress(enTarget, 'inthebeginning');
      expect(p, closeTo(14 / 34, 0.001));
    });

    test('canAdvanceTyped는 문턱값을 따른다', () {
      expect(
        SpeechMatchUtils.canAdvanceTyped(
          koTarget,
          '태초에하나님이',
          threshold: 0.4,
        ),
        isTrue,
      );
      expect(
        SpeechMatchUtils.canAdvanceTyped(
          koTarget,
          '태초에하나님이',
          threshold: 0.5,
        ),
        isFalse,
      );
    });
  });

  group('모드 전환 캐리', () {
    test('녹음→타이핑 시드: 시드한 만큼의 진행률이 그대로 나온다', () {
      final seed = SpeechMatchUtils.typedSeedForProgress(koTarget, 0.5);
      final p = SpeechMatchUtils.typedMatchProgress(koTarget, seed);
      expect(p, closeTo(0.5, 0.05));
    });

    test('타이핑→녹음 캐리: 공백 복원된 원문 접두가 나오고 음성 매처가 인정한다', () {
      final carried = SpeechMatchUtils.typedProgressTargetPrefix(
        koTarget,
        '태초에하나님이',
      );
      expect(carried, '태초에 하나님이');
      final voiceP = SpeechMatchUtils.voiceMatchProgress(koTarget, carried);
      expect(voiceP, greaterThanOrEqualTo(0.4));
    });

    test('빈 입력·빈 대상은 0', () {
      expect(SpeechMatchUtils.typedMatchProgress(koTarget, ''), 0);
      expect(SpeechMatchUtils.typedMatchProgress('', '아무거나'), 0);
      expect(SpeechMatchUtils.typedProgressTargetPrefix(koTarget, ''), '');
    });
  });
}
