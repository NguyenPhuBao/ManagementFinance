/// Sáu giá trị (mười hai tên) sự kiện thời gian thực client còn quan tâm, trong số những sự kiện
/// backend phát tới room `account_<idaccount>` (riêng `emitPermissionsUpdated` — `account.permissions_updated` /
/// `account.upgraded` — phát tới MỌI socket).
///
/// ## Vì sao chỉ có tên, không có dữ liệu
///
/// Client **không đọc bất kỳ trường nào** trong payload. Một tên sự kiện
/// không bảo đảm một hình dạng payload: backend phát qua EventBus từ nhiều
/// chỗ, và client không biết bản backend đang chạy trên máy chủ dựng payload
/// bằng khoá gì.
///
/// Đọc trường ở đây là tự chuốc lấy loại lỗi im lặng của quy tắc 4 `CLAUDE.md`.
/// Chọn không đọc gì cả thì cái bẫy ấy không còn tồn tại: chữ hiện ra là hằng
/// số tiếng Việt do client chọn, còn dữ liệu thật đi đường `/sync/pull` như mọi
/// khi.
///
/// Hai ngoại lệ, mỗi cái một cửa riêng trên `RealtimeChannel` — không bao giờ
/// vào enum này: `account.force_logout` (`buocDangXuat`) và `system.broadcast`
/// (`tinHeThong`, đọc qua `docTinHeThong` — 2026-10-26). Cả hai chỉ phát từ một
/// hàm phía backend.
///
/// ⚠️ `bank_transaction.incoming` **cố ý không nằm ở đây**. Backend vẫn phát
/// nó (SePay webhook → `workers/bank.worker.js`), nhưng nhóm đã bỏ liên kết
/// ngân hàng khỏi sản phẩm ngày 2026-09-18, nên client bỏ qua nó đúng như với
/// mọi tên lạ — xem [realtimeEventFromName].
enum RealtimeEvent {
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

  /// `account.upgraded` (và `account.permissions_updated`) — backend phát khi webhook PayOS xác nhận đã trả
  /// (`handlePayOSWebhook`) và khi người dùng đồng ý nâng cấp đơn chuyển thừa (`confirmUpgrade`) — cả hai ở
  /// `payment.service.js`, qua `emitToAccount` — và tới MỌI socket khi admin đổi ma trận quyền (`emitPermissionsUpdated` ở
  /// `core/socket.js`). **Tín hiệu**: client không đọc payload, `GoiRepository` gọi lại `/payment/subscription-info` (spec
  /// Premium 2026-10-06 mục 6.5). Im — máy vừa trả có màn Thành công; máy khác đổi thẻ ở tab Cá nhân. Không kéo đồng bộ:
  /// lên gói không sinh dữ liệu đồng bộ mới.
  taiKhoanNangCap,

  /// `account.downgraded` — backend phát từ job hết hạn Premium lúc 00:00 giờ VN (`runDailyPremiumExpirationTask` ở
  /// `scheduler.service.js`, qua `emitToAccount`). **Tín hiệu**: `GoiRepository` làm mới gói (spec G89 mục 6.1). Im, không
  /// kéo đồng bộ. Màn Nâng cấp / Chờ thanh toán KHÔNG nghe (đó là luồng [taiKhoanNangCap]). Giữa lúc hết hạn và 0 giờ
  /// server đã trả 403 `FEATURE_DISABLED` — đường ấy do interceptor trạng thái máy chủ báo (mục 6.2).
  taiKhoanHaCap,

  /// `payment.overpaid_confirmation` · `payment.underpaid_warning` · `payment.refunded` · `payment.success` ·
  /// `payment.order_expired` · `payment.order_cancelled` — backend phát tới phòng tài khoản khi trạng thái một đơn
  /// thanh toán đổi (`payment.service.js`). **Tín hiệu**: màn Chờ / Chi tiết đơn / Lịch sử mua / Nâng cấp đang mở hỏi
  /// lại server; không đọc payload (cam kết hộp đen), không toast (người dùng chốt 2026-10-18), không kéo đồng bộ.
  /// `GoiRepository` KHÔNG làm mới gói theo nó — gói chỉ theo `account.upgraded` (spec G94 2026-10-18 mục 5.8).
  donThanhToanDoi,
}

/// Dịch tên sự kiện của backend sang enum. Tên lạ trả `null` — backend thêm sự
/// kiện mới sẽ không làm vỡ bản client đang chạy.
///
/// `bank_transaction.incoming` rơi vào nhánh `null` như một tên lạ, dù nó là
/// một sự kiện có thật của backend: liên kết ngân hàng đã bị bỏ khỏi sản phẩm.
RealtimeEvent? realtimeEventFromName(String name) {
  switch (name) {
    case 'ocr.completed':
      return RealtimeEvent.ocrXong;
    case 'ocr.duplicate':
      return RealtimeEvent.ocrTrung;
    case 'sync.completed':
      return RealtimeEvent.dongBoXong;
    case 'account.upgraded':
    case 'account.permissions_updated':
      return RealtimeEvent.taiKhoanNangCap;
    case 'account.downgraded':
      return RealtimeEvent.taiKhoanHaCap;
    case 'payment.overpaid_confirmation':
    case 'payment.underpaid_warning':
    case 'payment.refunded':
    case 'payment.success':
    case 'payment.order_expired':
    case 'payment.order_cancelled':
      return RealtimeEvent.donThanhToanDoi;
    default:
      return null;
  }
}

extension RealtimeEventX on RealtimeEvent {
  /// Sự kiện này có nghĩa "server vừa có dữ liệu mới" hay không.
  ///
  /// `ocr.duplicate` nói đúng điều ngược lại — không có gì được tạo — nên kéo
  /// dữ liệu về sau nó là một vòng mạng thừa. `account.upgraded` cũng không:
  /// lên gói là chuyện của bảng `account`, không bảng nào client đồng bộ đổi; `account.downgraded` (hạ gói) cùng lý do.
  bool get canDongBoLai =>
      this != RealtimeEvent.ocrTrung &&
      this != RealtimeEvent.taiKhoanNangCap &&
      this != RealtimeEvent.taiKhoanHaCap &&
      this != RealtimeEvent.donThanhToanDoi;

  /// Câu hiện trên toast. Hằng số, cố ý không nêu số liệu.
  ///
  /// `null` nghĩa là **không hiện toast** — đây là định nghĩa duy nhất của
  /// "sự kiện im lặng"; `AppToast` chỉ đọc getter này, không tự liệt kê.
  String? get loiNhan {
    switch (this) {
      case RealtimeEvent.ocrXong:
        return 'Đã bóc tách xong hoá đơn';
      case RealtimeEvent.ocrTrung:
        return 'Hoá đơn này đã được ghi nhận trước đó';
      case RealtimeEvent.dongBoXong:
        return null;
      case RealtimeEvent.taiKhoanNangCap:
        return null;
      case RealtimeEvent.taiKhoanHaCap:
        return null;
      case RealtimeEvent.donThanhToanDoi:
        return null;
    }
  }
}
