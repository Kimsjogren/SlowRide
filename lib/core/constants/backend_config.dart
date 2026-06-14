class BackendConfig {
  const BackendConfig._();

  static const String routingProvider = String.fromEnvironment(
    'ROUTING_PROVIDER',
    defaultValue: 'valhalla',
  );

  static const String osrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String openRouteServiceBaseUrl = String.fromEnvironment(
    'ORS_BASE_URL',
    defaultValue: 'https://api.openrouteservice.org',
  );

  static const String openRouteServiceApiKey = String.fromEnvironment(
    'ORS_API_KEY',
    defaultValue: '',
  );

  /// GraphHopper routing API
  static const String graphhopperBaseUrl = String.fromEnvironment(
    'GH_BASE_URL',
    defaultValue: 'https://graphhopper.com/api/1',
  );

  static const String graphhopperApiKey = String.fromEnvironment(
    'GH_API_KEY',
    defaultValue: '52178d6d-1ee2-4d38-bb96-3700da1afd5b',
  );

  /// Valhalla self-hosted routing API
  static const String valhallaBaseUrl = String.fromEnvironment(
    'VALHALLA_BASE_URL',
    defaultValue: 'https://api.cruizx.com',
  );

  /// Mapbox access token (pk.) used for map tiles and future SDK features
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue:
        'pk.eyJ1Ijoia2ltc2pvZ3JlbjE5ODciLCJhIjoiY21taXQ0dDB3MWJlMzJxczUzc2tvZDN2NyJ9.-eZcy-sIG46WBe_y05rUeQ',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bgdtzxmcnydvracgqaht.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_8Fh1-rylojT88X9hpD2iFA_8CwxJXXG',
  );

  static const bool strictSlowVehicleRouting = true;

  /// Force Pro mode for testing. Default is false (free version).
  /// Build with: flutter run --dart-define=FORCE_PRO=true
  static const bool forcePro = bool.fromEnvironment(
    'FORCE_PRO',
    defaultValue: false,
  );

  /// Force Free mode for testing (clears any saved Pro status).
  /// Build with: flutter run --dart-define=FORCE_FREE=true
  static const bool forceFree = bool.fromEnvironment(
    'FORCE_FREE',
    defaultValue: false,
  );

  /// External checkout used by the web app (kept separate from native stores).
  /// Build with: --dart-define=WEB_CHECKOUT_URL=https://your-checkout-url
  static const String webCheckoutUrl = String.fromEnvironment(
    'WEB_CHECKOUT_URL',
    defaultValue: 'https://cruizx.com/get-app',
  );

  /// Force web (Stripe) checkout instead of native store IAP.
  /// Set to true when building the sideloaded APK.
  /// Build with: flutter build apk --dart-define=WEB_CHECKOUT_ONLY=true
  static const bool webCheckoutOnly = bool.fromEnvironment(
    'WEB_CHECKOUT_ONLY',
    defaultValue: false,
  );

  /// Fallback price label shown for web/Stripe checkout when no store price
  /// exists (for example in sideloaded APK builds).
  /// Build with: --dart-define=WEB_CHECKOUT_DISPLAY_PRICE=39\ kr
  static const String webCheckoutDisplayPrice = String.fromEnvironment(
    'WEB_CHECKOUT_DISPLAY_PRICE',
    defaultValue: '39 kr',
  );

  /// Public worker endpoint for reading the active Stripe web/APK price.
  static const String webPricingUrl = String.fromEnvironment(
    'WEB_PRICING_URL',
    defaultValue: 'https://cruizx.com/api/web/pricing',
  );

  /// Public worker endpoint that creates a Stripe Checkout Session for APK/web.
  static const String webCheckoutSessionUrl = String.fromEnvironment(
    'WEB_CHECKOUT_SESSION_URL',
    defaultValue: 'https://cruizx.com/api/web/checkout-session',
  );
}
