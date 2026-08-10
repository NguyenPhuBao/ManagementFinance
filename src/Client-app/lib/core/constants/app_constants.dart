class AppConstants {
  // API
  // Web/Chrome: dùng localhost. Android emulator: đổi lại 10.0.2.2
  static const String baseUrl = 'http://localhost:3000/api';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Sync
  static const Duration syncDebounce = Duration(seconds: 3);
  static const Duration syncInterval = Duration(minutes: 15);

  // Storage keys
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey     = 'user_data';

  // Offline login cache keys
  static const String offlineUsernameKey     = 'offline_username';
  static const String offlinePasswordHashKey = 'offline_password_hash';
  static const String offlineUserDataKey     = 'offline_user_data';
}
