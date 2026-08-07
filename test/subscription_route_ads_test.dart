import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/services/subscription_service.dart';

void main() {
  group('Free route advertising', () {
    test('shows ads between every route after the first', () {
      expect(
        SubscriptionService.routeInterstitialEligible(
          isPro: false,
          routesToday: 0,
        ),
        isFalse,
      );
      expect(
        SubscriptionService.routeInterstitialEligible(
          isPro: false,
          routesToday: 1,
        ),
        isTrue,
      );
      expect(
        SubscriptionService.routeInterstitialEligible(
          isPro: false,
          routesToday: 20,
        ),
        isTrue,
      );
      expect(
        SubscriptionService.routeInterstitialEligible(
          isPro: true,
          routesToday: 20,
        ),
        isFalse,
      );
    });

    test('offers Pro once per day after two routes', () {
      expect(
        SubscriptionService.dailyRouteUpgradePromptEligible(
          isPro: false,
          routesToday: 1,
          lastPromptDate: null,
          today: '2026-08-07',
        ),
        isFalse,
      );
      expect(
        SubscriptionService.dailyRouteUpgradePromptEligible(
          isPro: false,
          routesToday: 2,
          lastPromptDate: null,
          today: '2026-08-07',
        ),
        isTrue,
      );
      expect(
        SubscriptionService.dailyRouteUpgradePromptEligible(
          isPro: false,
          routesToday: 5,
          lastPromptDate: '2026-08-07',
          today: '2026-08-07',
        ),
        isFalse,
      );
      expect(
        SubscriptionService.dailyRouteUpgradePromptEligible(
          isPro: false,
          routesToday: 2,
          lastPromptDate: '2026-08-07',
          today: '2026-08-08',
        ),
        isTrue,
      );
      expect(
        SubscriptionService.dailyRouteUpgradePromptEligible(
          isPro: true,
          routesToday: 2,
          lastPromptDate: null,
          today: '2026-08-07',
        ),
        isFalse,
      );
    });
  });
}
