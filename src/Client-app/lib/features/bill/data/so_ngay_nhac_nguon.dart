/// Cổng đọc tuỳ chọn "Nhắc trước" (Cài đặt thông báo) cho nhãn "Sắp đến hạn" của trang Hoá đơn.
///
/// Hoá đơn tắt nhắc (`timeNotification` NULL) không có số ngày riêng, nhưng trang vẫn cần một
/// ngưỡng để hiện "Sắp đến hạn" — lấy từ tuỳ chọn chung (`billLeadDays`, `bill_nhac_truoc.dart`).
/// Tuỳ chọn nằm ở mảng thông báo, nên mảng hoá đơn chỉ khai cổng này; DI truyền hàm đọc thật
/// (`injection_container.dart`) — không thêm cạnh `bill/data` / `bill/presentation` → `notification/`
/// (quét 29 chỉ canh `domain/`; cạnh `bill/application` → `notification` có từ trước, cố ý). Trang
/// danh sách, trang chi tiết và bảng Thanh toán cùng đọc qua đây.
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
