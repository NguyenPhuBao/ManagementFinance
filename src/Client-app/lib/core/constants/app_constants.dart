import 'package:flutter/foundation.dart';

class AppConstants {
  // API
  // Web/Desktop: dùng localhost. Android emulator: 10.0.2.2 (alias đến localhost của máy host)
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

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
