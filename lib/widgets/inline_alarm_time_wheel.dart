import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 아침 알람 편집기의 인라인 시간 휠 — 아침·저녁 설정이 같은 형식을 쓰도록
/// 공용으로 추출했다(저녁만 다이얼로그라 이질적이라는 사용자 피드백).
class InlineAlarmTimeWheel extends StatefulWidget {
  const InlineAlarmTimeWheel({
    super.key,
    required this.initialTime,
    required this.use24Hour,
    required this.onChanged,
    this.onInteractionEnd,
  });

  final TimeOfDay initialTime;
  final bool use24Hour;

  /// 칸(디텐트)마다 호출 — 부모는 여기서 setState 없이 값만 기억할 것.
  /// 돌리는 중 리빌드가 걸리면 실기기에서 휠이 앞뒤로 튕긴다.
  final ValueChanged<TimeOfDay> onChanged;

  /// 휠이 한 칸에 정착해 스크롤이 끝난 뒤 1회 호출 — 라벨 갱신용
  /// setState는 여기서.
  final VoidCallback? onInteractionEnd;

  @override
  State<InlineAlarmTimeWheel> createState() => _InlineAlarmTimeWheelState();
}

class _InlineAlarmTimeWheelState extends State<InlineAlarmTimeWheel> {
  late int _hour;
  late int _minute;
  late int _periodIndex;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  // 진단용(널뛰기 추적): 분 휠 스크롤의 방향 반전을 기록한다.
  double? _dbgLastPx;
  int _dbgLastDir = 0;
  int _dbgRevCount = 0;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _periodIndex = _hour >= 12 ? 1 : 0;
    _hourController = FixedExtentScrollController(
      initialItem: widget.use24Hour ? _hour : _displayHour(_hour) - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _periodController = FixedExtentScrollController(initialItem: _periodIndex);
    _minuteController.addListener(_dbgMinuteListener);
  }

  void _dbgMinuteListener() {
    if (!_minuteController.hasClients) return;
    final px = _minuteController.position.pixels;
    final last = _dbgLastPx;
    _dbgLastPx = px;
    if (last == null) return;
    final delta = px - last;
    if (delta.abs() < 0.5) return;
    final dir = delta > 0 ? 1 : -1;
    if (_dbgLastDir != 0 && dir != _dbgLastDir) {
      _dbgRevCount++;
      debugPrint(
        '[WHEEL] minute REVERSAL #$_dbgRevCount px=${px.toStringAsFixed(1)} '
        'delta=${delta.toStringAsFixed(2)}',
      );
    }
    _dbgLastDir = dir;
  }

  @override
  void didUpdateWidget(covariant InlineAlarmTimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.use24Hour != widget.use24Hour) {
      _rebuildControllers();
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _rebuildControllers() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    _hourController = FixedExtentScrollController(
      initialItem: widget.use24Hour ? _hour : _displayHour(_hour) - 1,
    );
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _minuteController.addListener(_dbgMinuteListener);
    _periodController = FixedExtentScrollController(initialItem: _periodIndex);
  }

  void _emit() {
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  // 주의: 여기서 setState를 부르면 안 된다. build()는 _hour/_minute/
  // _periodIndex를 읽지 않는데(라벨은 index 기반, 위치는 컨트롤러 소유),
  // 돌리는 중 칸마다 리빌드가 걸리면 스크롤 시뮬레이션과 재구성이 싸워
  // 휠이 앞뒤로 튕긴다. 순수 대입 + 부모 통지만 한다.
  void _setHourFromWheel(int index) {
    final hourIndex = _loopedIndex(index, widget.use24Hour ? 24 : 12);
    if (widget.use24Hour) {
      _hour = hourIndex;
    } else {
      final displayHour = hourIndex + 1;
      _hour = _periodIndex == 1 ? displayHour % 12 + 12 : displayHour % 12;
    }
    _emit();
  }

  void _setMinuteFromWheel(int index) {
    _minute = _loopedIndex(index, 60);
    _emit();
  }

  void _setPeriodFromWheel(int index) {
    _periodIndex = index;
    final displayHour = _displayHour(_hour);
    _hour = _periodIndex == 1 ? displayHour % 12 + 12 : displayHour % 12;
    _emit();
  }

  int _displayHour(int hour) {
    final display = hour % 12;
    return display == 0 ? 12 : display;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  int _loopedIndex(int index, int itemCount) {
    return ((index % itemCount) + itemCount) % itemCount;
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onSelectedItemChanged,
    bool looping = false,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 46,
      magnification: 1.08,
      squeeze: 1.05,
      useMagnifier: true,
      looping: looping,
      backgroundColor: Colors.transparent,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: AppTheme.accent.withValues(alpha: 0.12),
      ),
      onSelectedItemChanged: onSelectedItemChanged,
      children: List.generate(itemCount, (index) {
        return Center(
          child: Text(
            labelBuilder(index),
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        widget.onInteractionEnd?.call();
        return false;
      },
      child: _body(),
    );
  }

  Widget _body() {
    return Container(
      height: 188,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.bg.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _wheel(
              controller: _hourController,
              itemCount: widget.use24Hour ? 24 : 12,
              labelBuilder: (index) =>
                  widget.use24Hour ? _twoDigits(index) : '${index + 1}',
              onSelectedItemChanged: _setHourFromWheel,
              looping: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ':',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: _wheel(
              controller: _minuteController,
              itemCount: 60,
              labelBuilder: _twoDigits,
              onSelectedItemChanged: _setMinuteFromWheel,
              looping: true,
            ),
          ),
          if (!widget.use24Hour) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _wheel(
                controller: _periodController,
                itemCount: 2,
                labelBuilder: (index) => index == 0 ? 'AM' : 'PM',
                onSelectedItemChanged: _setPeriodFromWheel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
