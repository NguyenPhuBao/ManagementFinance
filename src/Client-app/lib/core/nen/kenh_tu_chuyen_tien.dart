/// Kênh tới tầng Kotlin của tự chuyển tiền chạy nền (`TuChuyenTien.kt`, `MainActivity.kt`) — spec
/// `2026-10-10-tu-chuyen-tien-chay-nen-design.md`. Cùng khuôn `kenh_phien_ngan_hang.dart`: lỗi nuốt, nền tảng không
/// có Kotlin (web, iOS, test) dùng bản trống.
library;

import 'package:flutter/services.dart';

import 'lich_nen.dart';

/// Engine của APP: Dart → Kotlin `henNen`; Kotlin → Dart `quetNgay` (worker tới giờ khi app đang mở).
const String kKenhTuChuyenTien = 'flowmoney/tu_chuyen_tien';

/// Engine NỀN (headless): Dart → Kotlin `nenXong` khi lượt nền xong.
const String kKenhNen = 'flowmoney/tu_chuyen_tien_nen';

/// Tên entrypoint Dart mà worker chạy — phải khớp `TuChuyenTien.kt` (test nối dây canh).
const String kEntrypointNen = 'chayNenTuChuyenTien';

/// Payload của `henNen` / `nenXong`. `moc` là mili-giây epoch, `0` = không có mốc.
Map<String, Object?> lichSangKenh(LichNenKeTiep l) =>
    {'moc': l.moc?.millisecondsSinceEpoch ?? 0, 'coTuDong': l.coTuDong};

abstract class KenhTuChuyenTien {
  /// Hẹn lượt một-lần theo `moc` (`null` → huỷ), lượt định kỳ 6 giờ theo `coTuDong` (`false` → huỷ).
  Future<void> henNen(LichNenKeTiep l);
}

class KenhTuChuyenTienAndroid implements KenhTuChuyenTien {
  const KenhTuChuyenTienAndroid();

  static const MethodChannel _kenh = MethodChannel(kKenhTuChuyenTien);

  @override
  Future<void> henNen(LichNenKeTiep l) async {
    try {
      await _kenh.invokeMethod<void>('henNen', lichSangKenh(l));
    } catch (_) {
      // Bỏ qua có chủ ý.
    }
  }
}

/// Nền tảng không có tầng Kotlin: không hẹn gì.
class KenhTuChuyenTienTrong implements KenhTuChuyenTien {
  const KenhTuChuyenTienTrong();

  @override
  Future<void> henNen(LichNenKeTiep l) async {}
}
