// lib/features/ai_edge/data/cong_tac_ai.dart
/// Công tắc **"Dùng AI trên máy"** — thứ gác việc màn Trợ lý AI có gọi mô
/// hình hay không (lối B, người dùng chốt 2026-09-21).
///
/// ⚠️ **Kế hoạch P3 viết khoá này là `SharedPreferences`, nhưng dự án KHÔNG có
/// gói ấy** (đo `pubspec.yaml` ngày 2026-09-22). Nơi lưu tuỳ chọn của dự án là
/// `flutter_secure_storage` — đúng lý lẽ đã ghi ở
/// `SecureStorageNotificationPrefsStore`: *"gói đã có sẵn trong dự án cho
/// access/refresh token, chạy cả trên web, nên không phải thêm phụ thuộc"*.
/// Tên khoá giữ nguyên `ai_tren_may_bat` để Task 8 đọc đúng chỗ.
///
/// **Một khoá cho cả máy, không theo tài khoản** — khác
/// `NotificationPrefsStore`. Cố ý: thứ công tắc này gác là **tệp mô hình 2,41
/// GB**, tài sản của *máy* chứ không của *tài khoản*; và cờ này không mang
/// một mẩu dữ liệu tài chính nào nên người dùng chung máy không lộ gì.
///
/// Mọi thao tác **nuốt lỗi**: mất cờ chỉ đưa người dùng về mặc định, còn ném
/// ra ngoài thì làm đổ cả màn Cài đặt AI vì một lần đọc kho tuỳ chọn hỏng.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kKhoaCongTacAi = 'ai_tren_may_bat';

class CongTacAi {
  const CongTacAi([this._kho = const FlutterSecureStorage()]);

  final FlutterSecureStorage _kho;

  /// Mặc định **bật**: người đã bỏ công tải 2,41 GB về thì mong nó được dùng.
  /// Máy chưa có mô hình thì cờ bật cũng không gây ra gì — đường sinh câu tự
  /// rơi về mẫu câu.
  Future<bool> doc() async {
    try {
      final raw = await _kho.read(key: kKhoaCongTacAi);
      if (raw == null || raw.isEmpty) return true;
      return raw == 'true';
    } catch (_) {
      return true;
    }
  }

  Future<void> ghi(bool bat) async {
    try {
      await _kho.write(key: kKhoaCongTacAi, value: bat ? 'true' : 'false');
    } catch (_) {
      // Xem chú thích đầu lớp.
    }
  }
}
