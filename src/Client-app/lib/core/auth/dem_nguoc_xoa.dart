/// Số ngày chờ xoá tài khoản còn lại — hàm thuần, không import gì.
///
/// Vì sao client tự tính (spec cưỡng chế đăng xuất §4.2): không endpoint nào trả
/// `countdown` mới — `/auth/profile` không có trường này, còn JWT mang
/// `countdown` **lúc cấp** và `/auth/refresh` cấp lại đúng payload cũ. Backend
/// trừ `Countdown` đi 1 lúc 00:00 giờ Việt Nam mỗi ngày (`scheduler.service.js`),
/// nên phép tính đếm theo **ngày lịch UTC+7**. Xin backend trả `countdown` ở
/// `/auth/profile`: CAN-LAM 19 (`docs/superpowers/backend/CAN-LAM/AUTH_PROFILE_COUNTDOWN.md`).
library;

/// Ngày lịch ở UTC+7 cố định (Việt Nam không đổi giờ), dạng `DateTime.utc(y, m, d)`
/// để phép trừ ngày không lệch theo múi giờ của máy.
DateTime ngayVN(DateTime thoiDiem) {
  final vn = thoiDiem.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(vn.year, vn.month, vn.day);
}

/// `null` khi không có số để hiện: thiếu [countdown] hoặc thiếu mốc nhận.
int? soNgayConLai({
  required int? countdown,
  required DateTime? nhanLuc,
  required DateTime now,
}) {
  if (countdown == null || nhanLuc == null) return null;
  var daQua = ngayVN(now).difference(ngayVN(nhanLuc)).inDays;
  // Đồng hồ máy lùi về trước mốc nhận: không được hiện nhiều hơn countdown.
  if (daQua < 0) daQua = 0;
  final con = countdown - daQua;
  return con < 0 ? 0 : con;
}

/// Ngày (lịch Việt Nam) tài khoản bị xoá vĩnh viễn; `null` khi thiếu dữ liệu.
DateTime? ngayXoaVinhVien({required int? countdown, required DateTime? nhanLuc}) {
  if (countdown == null || nhanLuc == null) return null;
  return ngayVN(nhanLuc).add(Duration(days: countdown));
}
