/// Lời "tài khoản này không được dùng nữa" tới từ server, đã chuẩn hoá về một
/// kiểu duy nhất cho cả ba nguồn.
///
/// Dart **thuần**: không import Flutter, không import Dio. Nhờ vậy nó dùng được
/// ở cả tầng mạng lẫn tầng bloc mà không kéo theo phụ thuộc nào.
///
/// ## Luật một chiều
///
/// Đọc nhầm *đã xoá* thành *bị khoá* chỉ khiến máy **giữ lại** bản sao dữ liệu.
/// Đọc nhầm *bị khoá* thành *đã xoá* là **xoá mất** dữ liệu của người dùng.
/// Nên mọi giá trị lạ, thiếu, hoặc sai kiểu đều về [LyDoBuocDangXuat.biKhoa]
/// (spec cưỡng chế đăng xuất §3.1).
library;

/// Vì sao tài khoản bị đẩy ra.
enum LyDoBuocDangXuat {
  /// Admin vô hiệu hoá tạm thời (`ACCOUNT_INACTIVE`) — admin mở khoá lại được,
  /// nên dữ liệu cục bộ phải **giữ**.
  biKhoa,

  /// Tài khoản đã bị xoá (`ACCOUNT_DELETED`) — server đã ẩn danh hoá (xoá
  /// `note`, `images`), máy không được giữ bản rõ.
  daXoa,
}

/// Lời ấy tới bằng đường nào. Chỉ bước dọn SQLite của §3.5 đọc tới nó (§3.6b).
enum NguonBuocDangXuat {
  /// Sự kiện `account.force_logout` trên kênh thời gian thực.
  socket,

  /// Body 401 của một request thường.
  http,

  /// Body 401 của chính `/auth/refresh`.
  ///
  /// ⚠️ Nguồn này **không** được dùng để dọn SQLite: trên `main` @ `7675b35`,
  /// Lý do có ngoại lệ (CAN-LAM 17 §2.5): tới 2026-09-12 `/auth/refresh` chưa
  /// tách lỗi lược đồ thành 503, nên một sự cố phía server đội lốt được
  /// `ACCOUNT_DELETED`. Backend đã sửa trong `main` @ `cbbeeb4` (gộp 2026-09-12).
  /// Đo chiều cùng ngày: ca hợp lệ 200, ca bị khoá 401 + `ACCOUNT_INACTIVE`; còn ca
  /// **đã xoá** thì xoá qua admin **thu hồi refresh token**, nên `/auth/refresh` trả
  /// 401 **không mã** — đường này không bao giờ mang `daXoa` (G36, CAN-LAM 20 §2.7).
  /// Ngoại lệ vì thế gần như vô nghĩa nhưng vô hại; **giữ** để che ca lỗi lược đồ
  /// (backend đã trả 503, chưa đo) — gỡ là quyết định của người dùng — spec §3.6b.
  lamMoi,
}

/// Mã duy nhất được phép hiểu là "đã xoá". Mọi giá trị khác → [LyDoBuocDangXuat.biKhoa].
const _maDaXoa = 'ACCOUNT_DELETED';

class ThongBaoBuocDangXuat {
  const ThongBaoBuocDangXuat({
    required this.lyDo,
    required this.nguon,
    this.loiNhan = '',
    this.idaccount,
  });

  final LyDoBuocDangXuat lyDo;
  final NguonBuocDangXuat nguon;

  /// Câu server gửi. **Rỗng** thì tầng giao diện thay bằng câu mặc định — câu
  /// ấy phụ thuộc [lyDo] và thuộc về giao diện, nên cố ý không đặt ở đây.
  final String loiNhan;

  /// Mã tài khoản server nói tới. `null` khi server không gửi, hoặc gửi thứ
  /// không đọc được thành số.
  final int? idaccount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThongBaoBuocDangXuat &&
          other.lyDo == lyDo &&
          other.nguon == nguon &&
          other.loiNhan == loiNhan &&
          other.idaccount == idaccount;

  @override
  int get hashCode => Object.hash(lyDo, nguon, loiNhan, idaccount);

  @override
  String toString() => 'ThongBaoBuocDangXuat($lyDo, $nguon, '
      'idaccount: $idaccount, loiNhan: "$loiNhan")';
}

/// Đọc payload của `account.force_logout`.
///
/// Backend phát sự kiện này từ **một** hàm duy nhất (`core/socket.js:175-191`,
/// gọi từ `admin.service.js:140`, `:199` và `scheduler.service.js:116`) với
/// hình dạng `{ idaccount, reason, message }` — nên đọc payload ở đây an toàn,
/// khác hẳn `bank_transaction.incoming` (xem chú thích đầu `realtime_event.dart`).
///
/// **Không bao giờ trả `null`.** Bản thân sự kiện đã là lời đẩy người dùng ra;
/// payload dị dạng chỉ làm ta mất *chi tiết*, không làm mất *lời* ấy. Trả `null`
/// ở đây nghĩa là bỏ qua sự kiện và để người dùng ngồi lại trong app — đúng cái
/// hỏng im lặng mà mục này sinh ra để chặn. (Spec §3.1 ghi kiểu nullable; lệch
/// có chủ ý, người dùng duyệt 2026-09-12.)
ThongBaoBuocDangXuat tuSuKienSocket(Object? payload) {
  final map = payload is Map ? payload : const {};
  return ThongBaoBuocDangXuat(
    lyDo: _lyDoTu(map['code'] ?? map['reason']),
    nguon: NguonBuocDangXuat.socket,
    loiNhan: _cauTu(map['message']),
    idaccount: _idTu(map['idaccount']),
  );
}

/// Đọc body của một phản hồi **401**.
///
/// ⚠️ Nơi gọi phải tự chắc rằng `statusCode == 401` trước khi gọi. Body 400 của
/// repo này cũng mang `code` (ví dụ `VALIDATION_ERROR`), và đọc nó ở đây là hiện
/// hộp thoại "Tài khoản đã bị vô hiệu hoá" cho một lỗi nhập liệu.
///
/// Chỉ nhận `code` ở **cấp gốc** — hình dạng `ResponseHandler.unauthorized(res,
/// message, extra)` (`core/response-handler.js:32-42`). `code` nằm dưới `errors`
/// là hình dạng lối tắt `ResponseHandler.error(...)` mà `AUTH_401_BODY_CODE.md`
/// đã bác, còn 401 "Token expired" thật thì **không có** `code` — cả hai ca đều
/// trả `null` để interceptor đi đường làm mới token như cũ.
ThongBaoBuocDangXuat? tuBody401(
  Object? body, {
  required NguonBuocDangXuat nguon,
}) {
  if (body is! Map) return null;
  final ma = body['code'];
  if (ma is! String || ma.isEmpty) return null;
  return ThongBaoBuocDangXuat(
    lyDo: _lyDoTu(ma),
    nguon: nguon,
    loiNhan: _cauTu(body['message']),
    idaccount: _idTu(body['idaccount']),
  );
}

LyDoBuocDangXuat _lyDoTu(Object? ma) =>
    ma == _maDaXoa ? LyDoBuocDangXuat.daXoa : LyDoBuocDangXuat.biKhoa;

String _cauTu(Object? cau) => cau is String ? cau : '';

int? _idTu(Object? id) {
  if (id is int) return id;
  if (id is num) return id.toInt();
  if (id is String) return int.tryParse(id.trim());
  return null;
}
