/// Nhắc ghi sau khi dùng app ngân hàng — kênh tới tầng Kotlin (`MainActivity.kt`, kênh [kKenhPhienNganHang];
/// `PhienNganHang.kt`). Cùng khuôn `kenh_bien_dong.dart`: mọi lỗi thành giá trị "không biết" / bỏ qua chứ không ném —
/// trên web, test, iOS `MissingPluginException` là chuyện bình thường.
library;

import 'package:flutter/services.dart';

import 'phien_ngan_hang.dart';

const String kKenhPhienNganHang = 'flowmoney/phien_ngan_hang';

abstract class KenhPhienNganHang {
  /// Quyền *Truy cập dữ liệu sử dụng* (chỉ Android 10+; máy cũ hơn → `false`).
  Future<bool> coQuyen();

  /// Mở trang *Truy cập dữ liệu sử dụng* của hệ thống — app không tự cấp được.
  Future<void> moCaiDat();

  /// Sự kiện vào / ra màn hình của các app theo dõi, từ [tu] tới bây giờ. Thiếu quyền / lỗi → rỗng.
  Future<List<SuKienSuDung>> suKien(DateTime tu);

  /// Mốc của nút *Không có giao dịch* (theo máy); chưa bấm lần nào → `null`.
  Future<DateTime?> boDen();

  /// Cờ máy + mốc đã xét. Bật → đặt lịch WorkManager (KEEP); tắt → huỷ lịch và gỡ thông báo nhắc.
  Future<void> datBat(bool bat, {DateTime? daXetDen});

  /// Gỡ thông báo nhắc — lượt nhập vừa đưa các phiên thành dòng.
  Future<void> huyNhac();
}

class KenhPhienNganHangAndroid implements KenhPhienNganHang {
  const KenhPhienNganHangAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhPhienNganHang);

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
  Future<List<SuKienSuDung>> suKien(DateTime tu) async {
    try {
      final ds = await _kenh.invokeListMethod<Object?>('suKien', {'tu': tu.millisecondsSinceEpoch}) ?? const [];
      return [
        for (final m in ds)
          if (docSuKien(m) case final e?) e,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<DateTime?> boDen() async {
    try {
      final v = await _kenh.invokeMethod<int>('boDen');
      return v == null || v <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> datBat(bool bat, {DateTime? daXetDen}) async {
    try {
      await _kenh.invokeMethod<void>('datBat', {'bat': bat, 'daXetDen': daXetDen?.millisecondsSinceEpoch ?? 0});
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }

  @override
  Future<void> huyNhac() async {
    try {
      await _kenh.invokeMethod<void>('huyNhac');
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }
}

/// Nền tảng không có tầng Kotlin (web, iOS, test): không quyền, không sự kiện, không làm gì.
class KenhPhienNganHangTrong implements KenhPhienNganHang {
  const KenhPhienNganHangTrong();

  @override
  Future<bool> coQuyen() async => false;
  @override
  Future<void> moCaiDat() async {}
  @override
  Future<List<SuKienSuDung>> suKien(DateTime tu) async => const [];
  @override
  Future<DateTime?> boDen() async => null;
  @override
  Future<void> datBat(bool bat, {DateTime? daXetDen}) async {}
  @override
  Future<void> huyNhac() async {}
}
