/// Cổng đọc tuỳ chọn "Nhắc trước" (Cài đặt thông báo) cho mảng hoá đơn — hai nghĩa:
///
/// - **Mặc định cho hoá đơn mới** (người dùng chốt 2026-10-17): form Thêm hoá đơn chọn sẵn chip theo số này
///   (`mucNhacChonSan`, `bill_nhac_truoc.dart`).
/// - **Ngưỡng nhãn "Sắp đến hạn"** của hoá đơn tắt nhắc (`timeNotification` NULL — không có số ngày riêng)
///   (`billLeadDays`). Trang danh sách, trang chi tiết, bảng Thanh toán và tool AI `danh_sach_hoa_don` cùng đọc.
///
/// Tuỳ chọn nằm ở mảng thông báo, nên mảng hoá đơn chỉ khai cổng này; DI truyền hàm đọc thật
/// (`injection_container.dart`) — không thêm cạnh `bill/data` / `bill/presentation` → `notification/`
/// (quét 29 chỉ canh `domain/`; cạnh `bill/application` → `notification` có từ trước, cố ý).
library;

import '../domain/bill_nhac_truoc.dart';

class SoNgayNhacNguon {
  const SoNgayNhacNguon(this._doc);

  final Future<int> Function(int idaccount) _doc;

  /// Số ngày "Nhắc trước" của [idaccount]; kho hỏng thì [mocNhacMacDinh] — một nhãn trạng thái
  /// không đáng làm trang đổ lỗi.
  Future<int> doc(int idaccount) async {
    try {
      return await _doc(idaccount);
    } catch (_) {
      return mocNhacMacDinh;
    }
  }
}
