import 'dong_ho_khoi_dong_stub.dart' if (dart.library.ffi) 'dong_ho_khoi_dong_ffi.dart' as impl;

/// Thời gian từ lúc máy KHỞI ĐỘNG, tính cả lúc máy ngủ (`CLOCK_BOOTTIME`) — đồng hồ đơn điệu, người dùng không chỉnh được
/// bằng Cài đặt giờ. `null` = nền tảng này không đọc được (web, Windows, iOS…): luật tự khoá khi đó chỉ còn giờ tường.
///
/// Tự khoá đo thời gian ở nền bằng ĐỒNG HỒ NÀY chứ không chỉ giờ tường: chỉnh giờ máy lùi về sau mốc rời app là vượt khoá
/// (review toàn nhánh I1). ⚠️ Đừng thay bằng `Stopwatch` — nó đọc `CLOCK_MONOTONIC`, đứng khi máy ngủ: tắt màn hình
/// 10 phút đo được vài giây, hỏng theo chiều MỞ.
typedef DongHoKhoiDong = Duration? Function();

/// Bản thật của nền tảng hiện tại (import có điều kiện: `dart:ffi` không có trên web).
Duration? docThoiGianKhoiDong() => impl.docThoiGianKhoiDong();
