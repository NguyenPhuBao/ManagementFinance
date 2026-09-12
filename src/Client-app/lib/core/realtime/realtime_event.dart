/// Bốn sự kiện thời gian thực backend phát tới room `account_<idaccount>`.
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

  /// `sync.completed` — backend phát sau mỗi `/sync/push` thành công
  /// (`core/socket.js` `emitSyncCompleted`, phòng `account_<id>`).
  ///
  /// Giá trị của nó là kéo thay đổi từ **máy khác** về ngay thay vì chờ chu kỳ
  /// 15 phút (G34). Nó **im lặng** — không toast — vì máy vừa đẩy cũng nằm
  /// trong phòng ấy nên nhận lại chính sự kiện của mình, mà payload là hộp đen
  /// nên không phân biệt được máy gửi: một toast "máy khác vừa đổi dữ liệu" sẽ
  /// nói sai trên đúng máy vừa ghi, sau mỗi lần ghi. Kết quả đồng bộ đã có dải
  /// riêng ở bậc cao nhất (spec socket §6.3).
  dongBoXong,
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
    case 'sync.completed':
      return RealtimeEvent.dongBoXong;
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
  ///
  /// `null` nghĩa là **không hiện toast** — đây là định nghĩa duy nhất của
  /// "sự kiện im lặng"; `AppToast` chỉ đọc getter này, không tự liệt kê.
  String? get loiNhan {
    switch (this) {
      case RealtimeEvent.giaoDichNganHang:
        return 'Vừa có giao dịch mới từ ngân hàng';
      case RealtimeEvent.ocrXong:
        return 'Đã bóc tách xong hoá đơn';
      case RealtimeEvent.ocrTrung:
        return 'Hoá đơn này đã được ghi nhận trước đó';
      case RealtimeEvent.dongBoXong:
        return null;
    }
  }
}
