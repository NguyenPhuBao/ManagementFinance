import 'package:flutter/foundation.dart';

import 'dia_chi_may_chu.dart';

class AppConstants {
  // API
  // Đổi địa chỉ LÚC BUILD, không sửa tay tệp này (2026-10-24):
  //   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api          (máy thật qua `adb reverse`)
  //   flutter build apk --release --dart-define=API_BASE_URL=https://managementfinance.onrender.com/api
  // Không truyền thì dùng mặc định dưới. Bản phát hành gọi máy chủ CÔNG KHAI qua http là ném lỗi ngay ở đây —
  // `chonDiaChiMayChu` / `kiemDiaChiMayChu` (`dia_chi_may_chu.dart`); địa chỉ nội bộ vẫn cho http.
  static String get baseUrl => chonDiaChiMayChu(
        tuBuild: const String.fromEnvironment('API_BASE_URL'),
        macDinh: _macDinh,
        phatHanh: kReleaseMode,
      );

  // Mặc định kết nối Backend Cloud Render (hoạt động thật):
  static String get _macDinh => 'https://managementfinance.onrender.com/api';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Sync
  static const Duration syncDebounce = Duration(seconds: 3);
  static const Duration syncInterval = Duration(minutes: 15);

  // Storage keys
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey     = 'user_data';

  // Bộ nhớ đệm người dùng của phiên (đọc khi mở app không mạng).
  static const String offlineUserDataKey     = 'offline_user_data';
  // Hai khoá CŨ — từ 2026-10-24 không ghi nữa (băm SHA-256 không salt của mật khẩu thật, không ai đọc); chỉ còn để
  // `AuthRepositoryImpl` xoá trên máy đã cài bản trước.
  static const String offlineUsernameKey     = 'offline_username';
  static const String offlinePasswordHashKey = 'offline_password_hash';
}
