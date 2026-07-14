import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:slowride/services/subscription_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad unit IDs ──────────────────────────────────────────────────────────
  static const String _iosInterstitialConvoyId =
      'ca-app-pub-8409578758600641/2936933028';
  static const String _iosInterstitialRouteId =
      'ca-app-pub-8409578758600641/5874855772';
  static const String _iosBannerSettingsId =
      'ca-app-pub-8409578758600641/9243686032';
  static const String _iosBannerConvoyId =
      'ca-app-pub-8409578758600641/2783187067';

  static const String _androidInterstitialConvoyId =
      'ca-app-pub-8409578758600641/7389190997';
  static const String _androidInterstitialRouteId =
      'ca-app-pub-8409578758600641/6787527904';
  static const String _androidBannerSettingsId =
      'ca-app-pub-8409578758600641/8719270290';
  static const String _androidBannerConvoyId =
      'ca-app-pub-8409578758600641/4818867975';

  String get _interstitialConvoyId =>
      Platform.isIOS ? _iosInterstitialConvoyId : _androidInterstitialConvoyId;

  String get _interstitialRouteId =>
      Platform.isIOS ? _iosInterstitialRouteId : _androidInterstitialRouteId;

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
  InterstitialAd? _routeInterstitial;
  bool _routeAdLoading = false;

  Future<void> _requestConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) {
              debugPrint('[AdService] Consent form error: ${error.message}');
            }
            completer.complete();
          });
        } else {
          completer.complete();
        }
      },
      (FormError error) {
        debugPrint('[AdService] Consent request error: ${error.message}');
        completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> initialize() async {
    // Step 1: UMP consent (GDPR/EEA) – must run before MobileAds.initialize()
    await _requestConsent();

    // Step 2: Request POST_NOTIFICATIONS on Android 13+ (API 33+)
    if (Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }

    // Step 3: Request ATT permission on iOS 14+ before loading ads
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

    // Keep test device configuration strictly to debug builds.
    // In release, an empty config avoids forcing AdMob test mode.
    if (kReleaseMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: []),
      );
      debugPrint('[AdService] MobileAds initialized ✅ (release mode)');
    } else {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            '82b543d5d83ee2e55ab814b835fb505b', // Kim's iPhone17
          ],
        ),
      );
      debugPrint(
        '[AdService] MobileAds initialized ✅ (test devices configured)',
      );
    }

    _preloadConvoyInterstitial();
    _preloadRouteInterstitial();
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

  void _preloadRouteInterstitial() {
    if (_routeAdLoading || _routeInterstitial != null) return;
    _routeAdLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialRouteId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _routeInterstitial = ad;
          _routeAdLoading = false;
        },
        onAdFailedToLoad: (_) {
          _routeAdLoading = false;
        },
      ),
    );
  }

  /// Shows one interstitial between routes 2 and 4 for free users. If the ad
  /// is not ready before route 3, it remains eligible before route 4.
  Future<void> showRouteInterstitialIfNeeded() async {
    final subscriptions = SubscriptionService.instance;
    if (!subscriptions.shouldShowRouteInterstitial) return;

    final ad = _routeInterstitial;
    if (ad == null) {
      _preloadRouteInterstitial();
      return;
    }

    _routeInterstitial = null;
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        subscriptions.recordRouteInterstitialShown();
      },
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        finish();
        _preloadRouteInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        finish();
        _preloadRouteInterstitial();
      },
    );

    try {
      await ad.show();
      await completer.future;
    } catch (_) {
      ad.dispose();
      finish();
      _preloadRouteInterstitial();
    }
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
