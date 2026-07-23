import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:means_of_grace/widgets/inline_alarm_time_wheel.dart';

/// 저녁 설정 화면 구조를 복제한 하네스 — ListView(Bouncing) 안에 휠 위
/// 큰 시계 라벨 + 1초 펄스 애니메이션 + (신규) 정착 시점 커밋.
/// 실기기에서 분 휠이 앞뒤로 튕기던 조건의 회귀 감시.
class _Harness extends StatefulWidget {
  const _Harness({required this.commitPerDetent});

  /// true = 수리 전 방식(칸마다 부모 setState), false = 현재 방식.
  final bool commitPerDetent;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  TimeOfDay _time = const TimeOfDay(hour: 21, minute: 30);
  late final ValueNotifier<TimeOfDay> _timeListenable = ValueNotifier(_time);
  late AnimationController _pulse;
  InlineAlarmTimeWheel? _wheelCache;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timeListenable.dispose();
    super.dispose();
  }

  Widget _wheel() {
    if (widget.commitPerDetent) {
      return InlineAlarmTimeWheel(
        initialTime: _time,
        use24Hour: false,
        onChanged: (next) => setState(() => _time = next),
      );
    }
    // 실제 화면과 동일: 돌리는 중 라벨은 노티파이어로 실시간 진실,
    // 화면 setState는 정착 시 1회.
    _wheelCache ??= InlineAlarmTimeWheel(
      initialTime: _time,
      use24Hour: false,
      onChanged: (next) {
        _time = next;
        _timeListenable.value = next;
      },
      onInteractionEnd: () {
        if (mounted) setState(() {});
      },
    );
    return _wheelCache!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_pulse),
              child: const Icon(Icons.nightlight_round, size: 40),
            ),
            ValueListenableBuilder<TimeOfDay>(
              valueListenable: _timeListenable,
              builder: (context, time, _) => Text(
                '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                key: const ValueKey('label'),
                style: const TextStyle(fontSize: 64),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Padding(
                key: const ValueKey('wheel'),
                padding: const EdgeInsets.only(top: 16),
                child: _wheel(),
              ),
            ),
            const SizedBox(height: 600),
          ],
        ),
      ),
    );
  }
}

Future<List<String>> _flingMinutes(
  WidgetTester tester, {
  required bool commitPerDetent,
}) async {
  final log = <String>[];
  final prior = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) log.add(message);
  };
  try {
    await tester.pumpWidget(_Harness(commitPerDetent: commitPerDetent));
    await tester.pump(const Duration(milliseconds: 300));

    // 분 휠(위젯 가운데 열)을 위로 세게 플링 → 4초 프레임 펌프로 정착 관찰.
    await tester.fling(
      find.byType(InlineAlarmTimeWheel),
      const Offset(0, -260),
      2400,
      warnIfMissed: false,
    );
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    debugPrint = prior;
  }
  return log;
}

void main() {
  testWidgets('현재 구조(정착 시 커밋): 플링에 방향 반전 0 + 정착 후 값 커밋', (tester) async {
    final log = await _flingMinutes(tester, commitPerDetent: false);
    final reversals = log.where((l) => l.contains('REVERSAL')).toList();
    expect(reversals, isEmpty);
    // 정착 후 라벨이 실제로 갱신됐는지(21:30에서 벗어남) 확인.
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('label')),
    );
    expect(label.data, isNot('21:30'));
  });

  testWidgets('수리 전 구조(칸마다 커밋): 물리 시뮬레이션 반전 관찰(참고용)', (tester) async {
    final log = await _flingMinutes(tester, commitPerDetent: true);
    final reversals = log.where((l) => l.contains('REVERSAL')).length;
    // ignore: avoid_print
    print('legacy per-detent reversals=$reversals');
  });
}
