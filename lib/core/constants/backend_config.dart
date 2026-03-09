class BackendConfig {
  const BackendConfig._();

  static const String routingProvider = String.fromEnvironment(
    'ROUTING_PROVIDER',
    defaultValue: 'graphhopper',
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
}
