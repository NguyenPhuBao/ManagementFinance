import 'package:flutter/foundation.dart';

class AppConstants {
  // API
  // Web/Desktop: 127.0.0.1 (xem lý do bên dưới). Android emulator: 10.0.2.2.
  static String get baseUrl {
    // ── LOCAL DEV ──────────────────────────────────────────────────────────
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api'; // Android emulator → host machine
    }
    // Dùng 127.0.0.1 chứ KHÔNG dùng `localhost`: trên Windows, `localhost`
    // thường phân giải thành ::1 (IPv6) trước, trong khi backend Express nghe
    // ở 0.0.0.0:3000 — tức CHỈ IPv4. Trình duyệt nối tới ::1, bị từ chối ngay
    // ở tầng TCP, và Dio báo lại bằng thông báo "XMLHttpRequest onError" kèm
    // một đoạn giải thích về CORS gây hiểu nhầm — trong khi CORS hoàn toàn
    // bình thường. 127.0.0.1 luôn tới đúng socket IPv4 nên chạy được ở mọi máy.
    //
    // Vẫn MỞ TRANG bằng http://localhost:9090 — CORS_ORIGIN phía backend đang
    // là `http://localhost:9090`, mở bằng 127.0.0.1:9090 sẽ bị CORS chặn thật.
    return 'http://127.0.0.1:3000/api'; // Web / Desktop

    // ── CLOUD (Render) — bỏ comment khi deploy ──────────────────────────
    // ignore: dead_code
    // return 'https://managementfinance.onrender.com/api';
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
