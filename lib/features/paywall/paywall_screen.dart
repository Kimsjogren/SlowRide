import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/core/constants/legal_links.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.reason});

  final PaywallReason? reason;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(SubscriptionService.instance.syncWebEntitlement(force: true));
    }
  }

  Future<void> _openWebCheckout() async {
    final uri = await SubscriptionService.instance
        .createWebCheckoutSessionUri();
    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (opened) {
      unawaited(SubscriptionService.instance.syncWebEntitlement(force: true));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Checkout opened. Pro is activated automatically after successful payment.',
          ),
          backgroundColor: Color(0xFF00913F),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Could not open web checkout right now.'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
        ),
      );
    }
  }

  Future<void> _showLoginRequired() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.paywallLoginRequiredTitle),
        content: Text(l10n.paywallLoginRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.paywallLoginRequiredAction),
          ),
        ],
      ),
    );
  }

  Future<void> _upgrade() async {
    if (SubscriptionService.instance.isWebCheckout &&
        AuthService.instance.userId.value == null) {
      await _showLoginRequired();
      return;
    }

    if (kIsWeb || SubscriptionService.instance.isWebCheckout) {
      await _openWebCheckout();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final purchased = await SubscriptionService.instance.purchaseProMonthly();
      if (!mounted) return;
      if (purchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallPurchaseSuccess),
            backgroundColor: const Color(0xFF00913F),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paywallPurchaseFailed),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paywallPurchaseFailed),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _restoring = true);
    try {
      final restored = await SubscriptionService.instance.restorePurchase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored ? l10n.paywallRestoreSuccess : l10n.paywallRestoreNotFound,
          ),
          backgroundColor: restored
              ? const Color(0xFF00913F)
              : Colors.white.withValues(alpha: 0.2),
        ),
      );
      if (restored) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final String? reasonTitle;
    final String? reasonBody;
    switch (widget.reason) {
      case PaywallReason.routeLimit:
        reasonTitle = l10n.paywallRouteLimitTitle;
        reasonBody = l10n.paywallRouteLimitBody;
      case PaywallReason.convoyLimit:
        reasonTitle = l10n.paywallConvoyLimitTitle;
        reasonBody = l10n.paywallConvoyLimitBody;
      case PaywallReason.memberLimit:
        reasonTitle = l10n.paywallMemberLimitTitle;
        reasonBody = l10n.paywallMemberLimitBody;
      case null:
        reasonTitle = null;
        reasonBody = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070F2B),
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1A4F), Color(0xFF070F2B)],
                  ),
                ),
              ),
            ),

            // Main content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                children: [
                  // Logo + PRO badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/logga_nobg.png',
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFB800,
                                ).withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            l10n.paywallProLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Reason banner (only when navigated due to a specific limit)
                  if (reasonTitle != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(
                            0xFFFFB800,
                          ).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFFFB800),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reasonTitle,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB800),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reasonBody ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Title
                  Text(
                    l10n.paywallTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.paywallSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Price pill (live Store price when available)
                  ValueListenableBuilder<String?>(
                    valueListenable:
                        SubscriptionService.instance.localizedPrice,
                    builder: (_, price, _) {
                      final isWebCheckout =
                          SubscriptionService.instance.isWebCheckout;
                      final priceText = (price != null && price.isNotEmpty)
                          ? l10n.settingsProPricePerMonth(price)
                          : (isWebCheckout
                                ? l10n.settingsProPricePerMonth(
                                    BackendConfig.webCheckoutDisplayPrice,
                                  )
                                : l10n.paywallPrice);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E6BFF), Color(0xFF0045CC)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1E6BFF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          priceText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Feature comparison table
                  _FeatureTable(l10n: l10n),

                  const SizedBox(height: 28),

                  // Upgrade button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _loading ? null : _upgrade,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.paywallUpgradeButton,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Restore
                  if (!kIsWeb) ...[
                    TextButton(
                      onPressed: _restoring ? null : _restore,
                      child: _restoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white38,
                              ),
                            )
                          : Text(
                              l10n.paywallRestoreButton,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 14,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Disclosure text: Apple for iOS/Google Play, Stripe for APK
                    ValueListenableBuilder<String?>(
                      valueListenable:
                          SubscriptionService.instance.localizedPrice,
                      builder: (_, price, _) {
                        final isWebCheckout =
                            SubscriptionService.instance.isWebCheckout;
                        final text = isWebCheckout
                            ? l10n.paywallDisclosureAndroid(
                                (price != null && price.isNotEmpty)
                                    ? price
                                    : BackendConfig.webCheckoutDisplayPrice,
                              )
                            : l10n.paywallDisclosure(price ?? '–');
                        return Text(
                          text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'Web version uses external checkout on cruizx.com.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Privacy Policy & Terms of Use links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => launchUrl(
                          Uri.parse(LegalLinks.privacyPolicy),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => launchUrl(
                          Uri.parse(LegalLinks.termsOfUse),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          'Terms of Use',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Close button — on top of scroll content so always tappable
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feature comparison table ─────────────────────────────────────────────────

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Header row
          _HeaderRow(l10n: l10n),
          _divider(),
          _FeatureRow(
            feature: l10n.paywallFeatureRoutes,
            freeValue: l10n.paywallFreeRouteLimit,
            proValue: l10n.paywallProRouteLimit,
          ),
          _divider(),
          _FeatureRow(
            feature: l10n.paywallFeatureConvoy,
            freeValue: l10n.paywallFreeConvoyLimit,
            proValue: l10n.paywallProConvoyLimit,
          ),
          _divider(),
          _FeatureRow(
            feature: l10n.paywallFeatureAds,
            freeValue: l10n.paywallFreeAds,
            proValue: l10n.paywallProAds,
            proIsGood: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.1));
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: Center(
              child: Text(
                l10n.paywallFreeLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.paywallProLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.freeValue,
    required this.proValue,
    this.proIsGood = false,
  });

  final String feature;
  final String freeValue;
  final String proValue;
  final bool proIsGood;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                freeValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                proValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: proIsGood
                      ? const Color(0xFF00C896)
                      : const Color(0xFFFFB800),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
