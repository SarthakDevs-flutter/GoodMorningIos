import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../services/native_alarm_service.dart';
import '../services/premium_access_service.dart';
import '../services/store_subscription_service.dart';
import '../theme/app_theme.dart';

const _termsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const _privacyPolicyUrl = 'https://sites.google.com/view/god-morning-privacy';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.blocking = false, this.onUnlocked});

  final bool blocking;
  final VoidCallback? onUnlocked;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<StoreSubscriptionProduct> _products = const [];
  String _selectedProductId = StoreSubscriptionService.annualProductId;
  bool _loadingProducts = true;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await StoreSubscriptionService.products();
    if (!mounted) return;
    setState(() {
      _products = products;
      if (products.isNotEmpty &&
          !products.any((product) => product.id == _selectedProductId)) {
        _selectedProductId = products.first.id;
      }
      _loadingProducts = false;
    });
  }

  StoreSubscriptionProduct? _product(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishUnlock() async {
    await PremiumAccessService.markPremiumUnlockedForPurchase();
    await PremiumAccessService.refreshPremiumStatus();
    if (!mounted) return;
    widget.onUnlocked?.call();
    _showSnack(AppLocalizations.of(context).premiumPurchaseSuccess);
  }

  Future<void> _finishDeveloperUnlock() async {
    await PremiumAccessService.markDeveloperAccessUnlocked();
    if (!mounted) return;
    widget.onUnlocked?.call();
    _showSnack('Developer access enabled');
  }

  Future<void> _purchaseSelected() async {
    if (_loadingProducts || _purchasing) return;
    if (PremiumAccessService.betaAccessEnabled) {
      await _finishUnlock();
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (_product(_selectedProductId) == null) {
      _showSnack(l10n.premiumProductsUnavailable);
      return;
    }

    setState(() => _purchasing = true);
    final status = await StoreSubscriptionService.purchase(_selectedProductId);
    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (status) {
      case StorePurchaseStatus.success:
        await _finishUnlock();
      case StorePurchaseStatus.pending:
        _showSnack(l10n.premiumPurchasePending);
      case StorePurchaseStatus.cancelled:
        _showSnack(l10n.premiumPurchaseCancelled);
      case StorePurchaseStatus.unavailable:
        _showSnack(l10n.premiumProductsUnavailable);
      case StorePurchaseStatus.failed:
      case StorePurchaseStatus.unknown:
        _showSnack(l10n.premiumPurchaseFailed);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _restoring = true);
    final restored = await StoreSubscriptionService.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (restored) {
      await _finishUnlock();
    } else {
      _showSnack(l10n.premiumRestoreMissing);
    }
  }

  Future<void> _openSubscriptionManagement(BuildContext context) async {
    final opened = await NativeAlarmService.openSubscriptionManagement();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).premiumOpenSubscriptionFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final annual = _product(StoreSubscriptionService.annualProductId);
    final monthly = _product(StoreSubscriptionService.monthlyProductId);
    final productsUnavailable = !_loadingProducts && _products.isEmpty;

    return PopScope(
      canPop: !widget.blocking,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.blocking,
          backgroundColor: AppTheme.bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textMuted),
          title: Text(
            l10n.premiumTitle,
            style: const TextStyle(color: AppTheme.text),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              // 소개 히어로 + 기능 리스트 — 무엇을 여는 구독인지 먼저 보여 준다.
              Text(
                l10n.premiumHeroTitle,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.premiumHeroSubtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.alarm_rounded,
                text: l10n.premiumFeatureAlarm,
              ),
              _FeatureRow(
                icon: Icons.menu_book_rounded,
                text: l10n.premiumFeaturePlans,
              ),
              _FeatureRow(
                icon: Icons.language_rounded,
                text: l10n.premiumFeatureLanguages,
              ),
              _FeatureRow(
                icon: Icons.wb_sunny_outlined,
                text: l10n.premiumFeatureWeather,
              ),
              const SizedBox(height: 18),
              if (_loadingProducts)
                _LoadingProducts(message: l10n.premiumLoadingProducts)
              else ...[
                if (productsUnavailable) ...[
                  _UnavailableProducts(
                    message: l10n.premiumProductsUnavailable,
                  ),
                  const SizedBox(height: 12),
                ],
                _PlanCard(
                  title: l10n.premiumAnnualTitle,
                  price: annual?.displayPrice ?? l10n.premiumAnnualPrice,
                  terms: l10n.premiumAnnualTrialTerms,
                  highlighted: true,
                  selected:
                      _selectedProductId ==
                      StoreSubscriptionService.annualProductId,
                  onTap: annual == null && _products.isNotEmpty
                      ? null
                      : () => setState(
                          () => _selectedProductId =
                              StoreSubscriptionService.annualProductId,
                        ),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: l10n.premiumMonthlyTitle,
                  price: monthly?.displayPrice ?? l10n.premiumMonthlyPrice,
                  terms: l10n.premiumMonthlyTrialTerms,
                  highlighted: false,
                  selected:
                      _selectedProductId ==
                      StoreSubscriptionService.monthlyProductId,
                  onTap: monthly == null && _products.isNotEmpty
                      ? null
                      : () => setState(
                          () => _selectedProductId =
                              StoreSubscriptionService.monthlyProductId,
                        ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_purchasing ||
                          (_loadingProducts &&
                              !PremiumAccessService.betaAccessEnabled))
                      ? null
                      : _purchaseSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    disabledForegroundColor: AppTheme.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _purchasing ? l10n.saving : l10n.premiumStartTrial,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (PremiumAccessService.developerAccessEnabled) ...[
                TextButton(
                  onPressed: _purchasing ? null : _finishDeveloperUnlock,
                  child: const Text(
                    'Developer access',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              TextButton(
                onPressed: _restoring ? null : _restorePurchases,
                child: Text(
                  _restoring ? l10n.saving : l10n.premiumRestore,
                  style: const TextStyle(color: AppTheme.text),
                ),
              ),
              TextButton(
                onPressed: () => _openSubscriptionManagement(context),
                child: Text(
                  l10n.premiumManageSubscription,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _premiumTermsForPlatform(l10n),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              _LegalLinks(l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }

  String _premiumTermsForPlatform(AppLocalizations l10n) {
    final isKorean = l10n.locale.languageCode == 'ko';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return isKorean
          ? '결제는 Google Play 결제를 통해 청구됩니다. 7일 무료 체험과 구독 갱신은 Google Play에서 관리합니다. 구독 설정에서 언제든지 취소할 수 있습니다. 갱신을 피하려면 다음 결제일 최소 24시간 전에 취소하세요.'
          : 'Payment is charged through Google Play billing. The 7-day free trial and subscription renewal are managed by Google Play. Cancel anytime in your subscription settings. To avoid renewal, cancel at least 24 hours before the next billing date.';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return isKorean
          ? '결제는 Apple 인앱결제를 통해 청구됩니다. 7일 무료 체험과 구독 갱신은 Apple에서 관리합니다. 구독 설정에서 언제든지 취소할 수 있습니다. 갱신을 피하려면 다음 결제일 최소 24시간 전에 취소하세요.'
          : 'Payment is charged through Apple In-App Purchase. The 7-day free trial and subscription renewal are managed by Apple. Cancel anytime in your subscription settings. To avoid renewal, cancel at least 24 hours before the next billing date.';
    }
    return l10n.premiumTerms;
  }
}

class _LoadingProducts extends StatelessWidget {
  const _LoadingProducts({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableProducts extends StatelessWidget {
  const _UnavailableProducts({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, height: 1.45),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.terms,
    required this.highlighted,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String terms;
  final bool highlighted;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlighted
              ? AppTheme.accent.withValues(alpha: 0.13)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : highlighted
                ? AppTheme.accent.withValues(alpha: 0.62)
                : AppTheme.surfaceLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: AppTheme.accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    price,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    terms,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
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

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.l10n});

  final AppLocalizations l10n;

  Future<void> _open(BuildContext context, String url) async {
    final opened = await NativeAlarmService.openExternalUrl(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.openLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: [
        TextButton(
          onPressed: () => _open(context, _termsOfUseUrl),
          child: Text(
            l10n.termsOfUse,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => _open(context, _privacyPolicyUrl),
          child: Text(
            l10n.privacyPolicy,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

/// 페이월 상단의 기능 소개 한 줄.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
