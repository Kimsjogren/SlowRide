import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:slowride/services/subscription_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad unit IDs ──────────────────────────────────────────────────────────
  // 🔧 TEST MODE: using Google's test IDs until AdMob account is activated.
  // TODO: swap these back to real IDs when https://admob.google.com shows "Active"
  //
  // Real IDs (restore when AdMob account is approved):
  //   _interstitialConvoyId   = 'ca-app-pub-8409578758600641/2936933028'
  //   _interstitialNavId      = 'ca-app-pub-8409578758600641/3991359355'
  //   _bannerSettingsId       = 'ca-app-pub-8409578758600641/9243686032'
  //   _bannerConvoyId         = 'ca-app-pub-8409578758600641/2783187067'
  static const String _interstitialConvoyId =
      'ca-app-pub-3940256099942544/4411468910'; // Google test interstitial (iOS)
  static const String _interstitialNavigationId =
      'ca-app-pub-3940256099942544/4411468910'; // Google test interstitial (iOS)
  static const String _bannerSettingsId =
      'ca-app-pub-3940256099942544/2934735716'; // Google test banner (iOS)
  static const String _bannerConvoyId =
      'ca-app-pub-3940256099942544/2934735716'; // Google test banner (iOS)

  // Public getters so widgets can use them
  String get bannerSettingsUnitId => _bannerSettingsId;
  String get bannerConvoyUnitId => _bannerConvoyId;
  String get interstitialNavigationUnitId => _interstitialNavigationId;

  /// Google sample ad units should always be allowed during QA, even if the
  /// local account is marked as Pro.
  bool isGoogleTestAdUnit(String adUnitId) {
    return adUnitId.startsWith('ca-app-pub-3940256099942544/');
  }

  // ── Interstitial: convoy tab ─────────────────────────────────────────────
  InterstitialAd? _convoyInterstitial;
  bool _convoyAdLoading = false;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
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
