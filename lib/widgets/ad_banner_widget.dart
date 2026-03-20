import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/subscription_service.dart';

/// Loads and displays an AdMob banner. Hidden automatically for Pro users.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryInterval = Duration(seconds: 3);

  bool get _allowAdsForCurrentUser => !SubscriptionService.instance.isPro.value;

  @override
  void initState() {
    super.initState();
    if (_allowAdsForCurrentUser) {
      _loadAd();
    }
    SubscriptionService.instance.isPro.addListener(_onProChanged);
  }

  void _onProChanged() {
    if (!_allowAdsForCurrentUser) {
      _ad?.dispose();
      if (mounted) {
        setState(() {
          _ad = null;
          _loaded = false;
        });
      }
    } else {
      _retryCount = 0;
      _loadAd();
    }
  }

  void _loadAd() {
    _ad?.dispose();
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdBanner] Loaded ✅');
          if (mounted) {
            setState(() {
              _loaded = true;
              _retryCount = 0;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdBanner] Failed: ${error.code} – ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
          _retryCount++;
          // Keep retrying in release builds too; AdMob can be slow to return
          // the first fill on fresh installs/devices.
          Future.delayed(_retryInterval, () {
            if (mounted && _allowAdsForCurrentUser) {
              _loadAd();
            }
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    SubscriptionService.instance.isPro.removeListener(_onProChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_allowAdsForCurrentUser) {
      return const SizedBox.shrink();
    }

    if (_loaded && _ad != null) {
      return SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      );
    }
    return GestureDetector(
      onTap: _loadAd,
      child: Container(
        height: 50,
        color: const Color(0x22FFFFFF),
        alignment: Alignment.center,
        child: Text(
          _retryCount <= _maxRetries
              ? l10n.adBannerLoading
              : l10n.adBannerWaitingRetry,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }
}
