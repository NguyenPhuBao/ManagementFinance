/// Sự kiện của một lượt hỏi trợ lý online (SSE của backend, spec 2026-10-11 §3.2).
/// Dart thuần: datasource phát, trang và luật rơi tiêu thụ.
library;

sealed class SuKienOnline {
  const SuKienOnline();

  /// Sự kiện kết thúc lượt ([XongOnline] / [DuPhongOnline] / [LoiOnline]); luồng dừng đọc tại đây.
  bool get laKet => true;
}

/// `event: delta` — một mẩu chữ (có thể cắt giữa từ; nối thẳng, không chèn gì).
class ChuOnline extends SuKienOnline {
  const ChuOnline(this.text);
  final String text;

  @override
  bool get laKet => false;
}

/// `event: tool` — máy chủ đang chạy công cụ [ten] nên luồng chữ tạm dừng; chỉ để hiện trạng thái.
class CongCuOnline extends SuKienOnline {
  const CongCuOnline(this.ten, {required this.dangChay});
  final String ten;
  final bool dangChay;

  @override
  bool get laKet => false;
}

const String kCongCuTraCuuKienThuc = 'tra_cuu_kien_thuc';

/// Chữ trạng thái cho người dùng; công cụ khác (kể cả công cụ backend thêm sau này) đều là đọc số liệu của họ.
String nhanCongCuOnline(String ten) =>
    ten == kCongCuTraCuuKienThuc ? 'Đang tra cứu kiến thức…' : 'Đang xem số liệu của bạn…';

/// `event: done` không `fallback`.
class XongOnline extends SuKienOnline {
  const XongOnline({this.responseTimeMs});
  final int? responseTimeMs;
}

/// `event: done` với `fallback: true` — server không có câu trả lời thật (thiếu khoá
/// Gemini, circuit breaker mở…); chữ trước đó (nếu có) là câu thông báo của server, vì thế luật rơi bỏ phần ấy.
class DuPhongOnline extends SuKienOnline {
  const DuPhongOnline(this.reason);
  final String reason;
}

/// `event: error`, HTTP ≠ 200, hết giờ, mất mạng, huỷ. [http] `null` = không có phản hồi.
class LoiOnline extends SuKienOnline {
  const LoiOnline({this.http, required this.lyDo});
  final int? http;
  final String lyDo;
}

/// Một tin trong `history` gửi lên: `role` là `'user'` hoặc `'model'` (hợp đồng backend).
typedef TinLichSu = ({String role, String text});
