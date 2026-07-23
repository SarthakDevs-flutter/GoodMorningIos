import 'package:flutter/material.dart';

/// Step dots + chevrons for horizontal prayer step navigation.
class PrayerStepNavBar extends StatelessWidget {
  const PrayerStepNavBar({
    super.key,
    required this.stepIndex,
    required this.stepCount,
    required this.stepLabel,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final int stepIndex;
  final int stepCount;
  final String stepLabel;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    const active = Colors.white;
    const inactive = Color(0xFF444444);
    const labelColor = Color(0xFFB0B0B0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: canGoBack ? onBack : null,
                icon: Icon(
                  Icons.chevron_left,
                  size: 32,
                  color: canGoBack ? active : inactive,
                ),
              ),
              Expanded(
                child: Text(
                  stepLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: canGoForward ? onForward : null,
                icon: Icon(
                  Icons.chevron_right,
                  size: 32,
                  color: canGoForward ? active : inactive,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stepCount, (i) {
              final current = i == stepIndex;
              return Container(
                width: current ? 10 : 6,
                height: current ? 10 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current ? active : inactive,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
