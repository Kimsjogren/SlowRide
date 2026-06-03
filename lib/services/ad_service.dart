import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:slowride/services/subscription_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad unit IDs ──────────────────────────────────────────────────────────
  static const String _iosInterstitialConvoyId =
      'ca-app-pub-8409578758600641/2936933028';
  static const String _iosBannerSettingsId =
      'ca-app-pub-8409578758600641/9243686032';
  static const String _iosBannerConvoyId =
      'ca-app-pub-8409578758600641/2783187067';

  static const String _androidInterstitialConvoyId =
      'ca-app-pub-8409578758600641/7389190997';
  static const String _androidBannerSettingsId =
      'ca-app-pub-8409578758600641/8719270290';
  static const String _androidBannerConvoyId =
      'ca-app-pub-8409578758600641/4818867975';

  String get _interstitialConvoyId =>
      Platform.isIOS ? _iosInterstitialConvoyId : _androidInterstitialConvoyId;

  String get _bannerSettingsId =>
      Platform.isIOS ? _iosBannerSettingsId : _androidBannerSettingsId;

  String get _bannerConvoyId =>
      Platform.isIOS ? _iosBannerConvoyId : _androidBannerConvoyId;

  // Public getters so widgets can use them
  String get bannerSettingsUnitId => _bannerSettingsId;
  String get bannerConvoyUnitId => _bannerConvoyId;

  /// Google sample ad units should always be allowed during QA, even if the
  /// local account is marked as Pro.
  bool isGoogleTestAdUnit(String adUnitId) {
    return adUnitId.startsWith('ca-app-pub-3940256099942544/');
  }

  // ── Interstitial: convoy tab ─────────────────────────────────────────────
  InterstitialAd? _convoyInterstitial;
  bool _convoyAdLoading = false;

  Future<void> initialize() async {
    // Request ATT permission on iOS 14+ before loading ads
    if (Platform.isIOS) {
      try {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        debugPrint('[AdService] ATT status: $status');

        if (status == TrackingStatus.notDetermined) {
          // Small delay recommended by Apple before showing ATT prompt
          await Future.delayed(const Duration(milliseconds: 500));
          final newStatus =
              await AppTrackingTransparency.requestTrackingAuthorization();
          debugPrint('[AdService] ATT requested, new status: $newStatus');
        }
      } catch (e) {
        debugPrint('[AdService] ATT error: $e');
      }
    }

    debugPrint('[AdService] Initializing MobileAds...');
    await MobileAds.instance.initialize();

    // Register test devices for development (required for test ads on real devices)
    // Add device IDs from console logs here during testing
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [
          'dcf7da2138fb5c5cd5b04c95cf08fccd', // Kim's iPhone17
          // Add more test device IDs here as needed
        ],
      ),
    );
    debugPrint('[AdService] MobileAds initialized ✅ (test devices configured)');

    _preloadConvoyInterstitial();
  }

  void _preloadConvoyInterstitial() {
    if (_convoyAdLoading) return;
    _convoyAdLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialConvoyId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _convoyInterstitial = ad;
          _convoyAdLoading = false;
        },
        onAdFailedToLoad: (_) {
          _convoyAdLoading = false;
        },
      ),
    );
  }

  /// Shows the convoy interstitial if the user is on the free tier.
  /// [onDone] is called after the ad closes (or immediately if ad is not
  /// available or user is Pro).
  Future<void> showConvoyInterstitial({required void Function() onDone}) async {
    if (SubscriptionService.instance.isPro.value) {
      onDone();
      return;
    }

    final ad = _convoyInterstitial;
    if (ad == null) {
      onDone();
      _preloadConvoyInterstitial();
      return;
    }

    _convoyInterstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onDone();
        _preloadConvoyInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        onDone();
        _preloadConvoyInterstitial();
      },
    );
    await ad.show();
  }
}
