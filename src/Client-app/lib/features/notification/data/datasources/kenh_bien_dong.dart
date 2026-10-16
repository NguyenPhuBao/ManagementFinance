/// D1 — kênh nói chuyện với tầng Kotlin của tính năng đọc biến động số dư
/// (`MainActivity.kt`, kênh [kKenhBienDong]; dịch vụ `BienDongListenerService.kt`).
///
/// Cùng khuôn `nguon_ly_do_thoat.dart`: mọi lỗi thành giá trị "không biết" / bỏ
/// qua chứ không ném — trên nền tảng không có kênh (web, test, iOS) thì
/// `MissingPluginException` là chuyện bình thường, và không đường nào ở đây được
/// phép chặn khởi động hay chặn lượt quét.
library;

import 'package:flutter/services.dart';

const String kKenhBienDong = 'flowmoney/bien_dong';

abstract class KenhBienDong {
  /// Người dùng đã cấp quyền "Truy cập thông báo" cho app chưa (Cài đặt hệ thống).
  Future<bool> coQuyen();

  /// Mở màn Cài đặt "Truy cập thông báo" của Android — app không tự cấp được.
  Future<void> moCaiDat();

  /// Mở **trang thông tin ứng dụng** — nơi ColorOS đặt "Mức sử dụng pin → Cho phép hoạt động dưới nền" (MIUI và
  /// hãng khác có mục tương tự). Không dùng hộp thoại xin miễn tối ưu pin: nó đòi quyền
  /// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, thứ Google Play giới hạn.
  Future<void> moCaiDatPin();

  /// App có được **miễn tối ưu pin** không (`PowerManager.isIgnoringBatteryOptimizations`). Đo đối chứng Realme
  /// 2026-09-30: công tắc "Cho phép hoạt động dưới nền" của ColorOS CHÍNH là trạng thái này (tắt → rời danh sách
  /// miễn), tắt thì Hans đóng băng app ~12 giây sau khi về nền, bật thì không. Không biết → `false` (hiện gợi ý).
  Future<bool> duocChayNen();

  /// Lần mở app này có đến từ cú chạm thông báo tóm tắt không. Đọc là **tiêu**:
  /// hỏi lần hai trả `false`.
  Future<bool> moTuThongBao();

  /// Gỡ thông báo tóm tắt (sau khi đã nhập hàng chờ).
  Future<void> huyTomTat();

  /// Bật / tắt dịch vụ Kotlin (cờ `SharedPreferences` phía native). Tắt thì dịch
  /// vụ thôi đọc dù quyền hệ thống vẫn còn.
  Future<void> datBat(bool bat);

  /// Chia sẻ biên lai (2026-10-02): máy đang có tài khoản đăng nhập không (cờ phía native). `NhanBienLaiActivity`
  /// chỉ nhận ảnh khi cờ bật — hàng chờ gắn máy, không có phiên thì không biết biên lai thuộc về ai.
  Future<void> datCoPhien(bool co);
}

class KenhBienDongAndroid implements KenhBienDong {
  const KenhBienDongAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhBienDong);

  @override
  Future<bool> coQuyen() async {
    try {
      return await _kenh.invokeMethod<bool>('coQuyen') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> moCaiDat() async {
    try {
      await _kenh.invokeMethod<void>('moCaiDat');
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  @override
  Future<void> moCaiDatPin() async {
    try {
      await _kenh.invokeMethod<void>('moCaiDatPin');
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  @override
  Future<bool> duocChayNen() async {
    try {
      return await _kenh.invokeMethod<bool>('duocChayNen') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> moTuThongBao() async {
    try {
      return await _kenh.invokeMethod<bool>('moTuThongBao') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> huyTomTat() async {
    try {
      await _kenh.invokeMethod<void>('huyTomTat');
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  @override
  Future<void> datBat(bool bat) async {
    try {
      await _kenh.invokeMethod<void>('datBat', {'bat': bat});
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  @override
  Future<void> datCoPhien(bool co) async {
    try {
      await _kenh.invokeMethod<void>('datCoPhien', {'co': co});
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }
}

/// Nền tảng không có tầng Kotlin (web, máy ảo không phải Android, test): không
/// quyền, không mở gì, không làm gì.
class KenhBienDongTrong implements KenhBienDong {
  const KenhBienDongTrong();

  @override
  Future<bool> coQuyen() async => false;
  @override
  Future<void> moCaiDat() async {}
  @override
  Future<void> moCaiDatPin() async {}
  @override
  Future<bool> duocChayNen() async => true;
  @override
  Future<bool> moTuThongBao() async => false;
  @override
  Future<void> huyTomTat() async {}
  @override
  Future<void> datBat(bool bat) async {}
  @override
  Future<void> datCoPhien(bool co) async {}
}
