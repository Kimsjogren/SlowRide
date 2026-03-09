class BackendConfig {
  const BackendConfig._();

  static const String routingProvider = String.fromEnvironment(
    'ROUTING_PROVIDER',
    defaultValue: 'osrm_public',
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
