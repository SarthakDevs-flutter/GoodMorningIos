import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Branded splash shown while launch state is prepared.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _logoAsset = 'assets/icon/splash_logo.png';

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.92).clamp(320.0, 520.0);
    final logoRadius = logoSize * 0.13;

    return Material(
      color: AppTheme.bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(logoRadius),
              child: Image.asset(
                SplashScreen._logoAsset,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
