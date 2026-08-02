import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../l10n/app_localizations.dart';
import '../../services/alarm_notification_service.dart';
import '../../services/alarm_schedule_helper.dart';
import '../../services/native_alarm_service.dart';
import '../../theme/app_theme.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _pageController = PageController();

  bool _working = false;
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_working) return;
    if (_isLastPage) {
      await _allowAndContinue();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _allowAndContinue() async {
    if (_working) return;
    setState(() => _working = true);

    try {
      if (!kIsWeb) {
        // Request each permission explicitly and in a deterministic order so
        // the OS prompts appear one after another with clear intent, rather
        // than as implicit side-effects of scheduling.
        // 1) Notifications — alarm delivery and lock-screen backstops.
        await AlarmNotificationService.instance.ensurePermissions();
        // 2) AlarmKit (iOS 26+) — the primary lock-screen alarm engine that
        //    rings through silent mode and auto-presents over the lock screen.
        //    No-op and safe on Android / older iOS (guarded, idempotent).
        await NativeAlarmService.requestAuthorization();
        // 3) Schedule with whichever engine is now authorized.
        await AlarmScheduleHelper.ensureScheduled();
        // 4) Speech recognition — used by the reading mission.
        final speech = stt.SpeechToText();
        await speech.initialize(debugLogging: kDebugMode);
      }
      if (mounted) widget.onComplete();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _OnboardingSlide(
                    visual: _LogoMark(),
                    title: l10n.onboardingProductTitle,
                    body: l10n.onboardingProductBody,
                    points: [
                      _SlidePoint(
                        icon: Icons.menu_book_rounded,
                        text: l10n.onboardingProductPointOneVerse,
                      ),
                      _SlidePoint(
                        icon: Icons.wb_sunny_outlined,
                        text: l10n.onboardingProductPointFirstMinute,
                      ),
                    ],
                  ),
                  _OnboardingSlide(
                    icon: Icons.record_voice_over_outlined,
                    title: l10n.onboardingReadTitle,
                    body: l10n.onboardingReadBody,
                    points: [
                      _SlidePoint(
                        icon: Icons.keyboard_alt_outlined,
                        text: l10n.onboardingReadPointVoiceType,
                      ),
                      _SlidePoint(
                        icon: Icons.check_circle_outline,
                        text: l10n.onboardingReadPointAmen,
                      ),
                    ],
                  ),
                  _OnboardingSlide(
                    icon: Icons.alarm_on_outlined,
                    title: l10n.onboardingAlarmTitle,
                    body: l10n.onboardingAlarmBody,
                    points: [
                      _SlidePoint(
                        icon: Icons.phone_iphone_outlined,
                        text: l10n.onboardingAlarmPointClosed,
                      ),
                      _SlidePoint(
                        icon: Icons.restart_alt_rounded,
                        text: l10n.onboardingAlarmPointReturn,
                      ),
                    ],
                  ),
                  _OnboardingSlide(
                    icon: Icons.verified_user_outlined,
                    title: l10n.onboardingPermissionsTitle,
                    body: l10n.onboardingPermissionsBody,
                    children: [
                      _PermissionPoint(
                        icon: Icons.notifications_active_outlined,
                        title: l10n.permissionNotificationTitle,
                        body: l10n.permissionNotificationBody,
                      ),
                      const SizedBox(height: 12),
                      _PermissionPoint(
                        icon: Icons.mic_none_outlined,
                        title: l10n.permissionMicrophoneTitle,
                        body: l10n.permissionMicrophoneBody,
                      ),
                      const SizedBox(height: 12),
                      _PermissionPoint(
                        icon: Icons.alarm_on_outlined,
                        title: l10n.permissionAlarmKitTitle,
                        body: l10n.permissionAlarmKitBody,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accent
                          : AppTheme.textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _working ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _working
                            ? l10n.saving
                            : _isLastPage
                            ? l10n.onboardingEnableAndStart
                            : l10n.onboardingNext,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    this.icon,
    this.visual,
    required this.title,
    required this.body,
    this.points = const [],
    this.children = const [],
  });

  final IconData? icon;
  final Widget? visual;
  final String title;
  final String body;
  final List<_SlidePoint> points;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
      children: [
        const SizedBox(height: 12),
        Center(
          child:
              visual ??
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Icon(icon, size: 42, color: AppTheme.accent),
              ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: AppTheme.text,
            height: 1.14,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textMuted,
            height: 1.55,
          ),
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final point in points) ...[
            _OnboardingPoint(point: point),
            const SizedBox(height: 12),
          ],
        ],
        if (children.isNotEmpty) ...[const SizedBox(height: 28), ...children],
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset('assets/icon/splash_logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _SlidePoint {
  const _SlidePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({required this.point});

  final _SlidePoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(point.icon, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              point.text,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPoint extends StatelessWidget {
  const _PermissionPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
