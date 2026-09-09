/// Ba sự kiện thời gian thực backend phát tới room `account_<idaccount>`.
///
/// ## Vì sao chỉ có tên, không có dữ liệu
///
/// Client **không đọc bất kỳ trường nào** trong payload. `bank_transaction
/// .incoming` được phát từ hai đường với hai hình dạng khác nhau:
/// `workers/bank.worker.js` gửi snake_case (`date_transaction`,
/// `account_number`, `gateway`), còn `modules/notification/notification
/// .service.js` gửi camelCase kèm `title`/`message`. Cùng một tên sự kiện.
///
/// Đọc trường ở đây là tự chuốc lấy loại lỗi im lặng của quy tắc 4 `CLAUDE.md`.
/// Chọn không đọc gì cả thì cái bẫy ấy không còn tồn tại: chữ hiện ra là hằng
/// số tiếng Việt do client chọn, còn dữ liệu thật đi đường `/sync/pull` như mọi
/// khi.
enum RealtimeEvent {
  /// `bank_transaction.incoming`
  giaoDichNganHang,

  /// `ocr.completed`
  ocrXong,

  /// `ocr.duplicate`
  ocrTrung,
}

/// Dịch tên sự kiện của backend sang enum. Tên lạ trả `null` — backend thêm sự
/// kiện mới sẽ không làm vỡ bản client đang chạy.
RealtimeEvent? realtimeEventFromName(String name) {
  switch (name) {
    case 'bank_transaction.incoming':
      return RealtimeEvent.giaoDichNganHang;
    case 'ocr.completed':
      return RealtimeEvent.ocrXong;
    case 'ocr.duplicate':
      return RealtimeEvent.ocrTrung;
    default:
      return null;
  }
}

extension RealtimeEventX on RealtimeEvent {
  /// Sự kiện này có nghĩa "server vừa có dữ liệu mới" hay không.
  ///
  /// `ocr.duplicate` nói đúng điều ngược lại — không có gì được tạo — nên kéo
  /// dữ liệu về sau nó là một vòng mạng thừa.
  bool get canDongBoLai => this != RealtimeEvent.ocrTrung;

  /// Câu hiện trên toast. Hằng số, cố ý không nêu số liệu.
  String get loiNhan {
    switch (this) {
      case RealtimeEvent.giaoDichNganHang:
        return 'Vừa có giao dịch mới từ ngân hàng';
      case RealtimeEvent.ocrXong:
        return 'Đã bóc tách xong hoá đơn';
      case RealtimeEvent.ocrTrung:
        return 'Hoá đơn này đã được ghi nhận trước đó';
    }
  }
}
