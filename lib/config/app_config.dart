class AppConfig {
  // Production API endpoint is live at https://vibekla.jambohub.org/api.
  // Override with the API_BASE_URL environment variable for local/dev testing.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://vibekla.jambohub.org/api',
  );

  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT',
    defaultValue: 10,
  );

  static const bool debugApi = bool.fromEnvironment('DEBUG_API');

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String appName = 'VibeKLA';
  static const String appVersion = '1.0.0';
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  static const bool enableMaps = bool.fromEnvironment(
    'ENABLE_MAPS',
    defaultValue: false,
  );
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: true,
  );
  static const bool enableNotifications = bool.fromEnvironment(
    'ENABLE_NOTIFICATIONS',
    defaultValue: false,
  );
}
