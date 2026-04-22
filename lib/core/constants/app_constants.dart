class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'My Flutter App';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = 'https://api.yourapp.com/v1';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int firstPage = 1;

  // Cache
  static const Duration cacheMaxAge = Duration(hours: 1);
  static const Duration cacheStaleTime = Duration(minutes: 30);

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String onboardingKey = 'onboarding_completed';
}
