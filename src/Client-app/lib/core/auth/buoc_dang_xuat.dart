/// Lời "tài khoản này không được dùng nữa" tới từ server, đã chuẩn hoá về một
/// kiểu duy nhất cho cả ba nguồn.
///
/// Dart **thuần**: không import Flutter, không import Dio. Nhờ vậy nó dùng được
/// ở cả tầng mạng lẫn tầng bloc mà không kéo theo phụ thuộc nào.
///
/// ## Giá trị lạ về `biKhoa`
///
/// Mọi giá trị lạ, thiếu, hoặc sai kiểu đều về [LyDoBuocDangXuat.biKhoa] (spec cưỡng chế đăng xuất §3.1). Từ G89 (2026-10-20)
/// hai lý do chỉ khác nhau ở CHỮ hộp thoại — không lý do nào dọn SQLite nữa — nên giá trị lạ về `biKhoa` chỉ ảnh hưởng
/// chữ hộp thoại, không còn bất đối xứng mất dữ liệu.
library;

/// Vì sao tài khoản bị đẩy ra.
enum LyDoBuocDangXuat {
  /// Admin vô hiệu hoá tạm thời (`ACCOUNT_INACTIVE`) — admin mở khoá lại được,
  /// nên dữ liệu cục bộ phải **giữ**.
  biKhoa,

  /// Tài khoản đã bị xoá (`ACCOUNT_DELETED`). Dữ liệu cục bộ vẫn GIỮ tới khi tài khoản khác
  /// đăng nhập trên máy (G89, người dùng chốt 2026-10-20).
  daXoa,
}

/// Lời ấy tới bằng đường nào. Từ G89 (2026-10-20) không chỗ nào trong `lib/` rẽ nhánh theo nguồn — giữ để
/// log và test phân biệt ba đường.
enum NguonBuocDangXuat {
  /// Sự kiện `account.force_logout` trên kênh thời gian thực.
  socket,

  /// Body 401 của một request thường.
  http,

  /// Body 401 của chính `/auth/refresh`.
  ///
  /// Lý do có ngoại lệ (CAN-LAM 17 §2.5): tới 2026-09-12 `/auth/refresh` chưa
  /// tách lỗi lược đồ thành 503, nên một sự cố phía server đội lốt được
  /// `ACCOUNT_DELETED`. Backend đã sửa trong `main` @ `cbbeeb4` (gộp 2026-09-12).
  ///
  /// ✅ **Đo đầu-cuối 2026-09-13, ba ca qua API admin — đường này CÓ mang
  /// `daXoa`** (G36 đóng): tài khoản `Active` → 200; admin khoá
  /// (`PATCH /admin/updatestatus`, kèm `reason_inactive` bắt buộc) → **401 +
  /// `ACCOUNT_INACTIVE`** kèm `idaccount` và `reason_inactive` ở cấp gốc; admin
  /// xoá mềm (`DELETE /admin/deleteuser`) → **401 + `ACCOUNT_DELETED`** kèm
  /// `idaccount`, **dù cả 4/4 refresh token của tài khoản đã bị thu hồi**. Đó
  /// chính là thứ CAN-LAM 20 §2.7 sửa: nhánh token thu hồi nay gọi
  /// `getAccountValidity` trước khi ném.
  ///
  /// Câu cũ ở đây — *"xoá qua admin thu hồi refresh token nên `/auth/refresh`
  /// trả 401 không mã, đường này không bao giờ mang `daXoa`"* — đúng cho tới
  /// bản `7779999` và **sai từ đó**; sửa 2026-09-13. Hệ quả: ngoại lệ §3.6b
  /// *không* còn vô nghĩa — nó nay chặn đúng ca thật (tài khoản bị xoá, phát
  /// hiện qua nhánh làm mới) chứ không chỉ che ca lỗi lược đồ.
  ///
  /// Ngoại lệ "không dọn SQLite" của nguồn này (G36, 2026-09-13) mở rộng ra cả ba nguồn ngày 2026-10-20 (G89).
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
/// Backend phát sự kiện này từ **một** hàm duy nhất (`emitForceLogout` ở
/// `core/socket.js`, gọi từ `admin.service.js` và `scheduler.service.js`) với
/// hình dạng `{ idaccount, reason, message }` — nên đọc payload ở đây an toàn,
/// khác hẳn các sự kiện đi qua EventBus của backend, thứ mà client không biết
/// bản đang chạy dựng payload bằng khoá gì (xem chú thích đầu
/// `realtime_event.dart`).
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

/// Đọc lỗi `connect_error` của bắt tay socket (spec G89 mục 5). Backend từ chối vì TÀI KHOẢN bằng
/// `Object.assign(new Error(...), {data: {code, idaccount, reason_inactive}})` trong middleware xác thực bắt tay
/// (`initSocket` ở `core/socket.js`); lỗi lược đồ / token / nội bộ là `Error` KHÔNG có `data` → `null` → nơi gọi giãn cách
/// nối lại như cũ.
///
/// Dạng đo 2026-10-20 (`socket.io` 4.8.3 + `socket_io_client` 3.1.6): handler nhận nguyên `data` của gói `CONNECT_ERROR` —
/// `Map` `{message, data: {code, …}}`. Nhánh `code` ở cấp gốc là dạng của giao thức 3 cũ (`err.data || err.message`), giữ cho
/// chắc. Câu của server nằm ở `message` cấp ngoài (*"Authentication error: …"*) — cố ý KHÔNG đọc: `loiNhan` rỗng → hộp thoại
/// dùng câu mặc định.
ThongBaoBuocDangXuat? tuLoiBatTaySocket(Object? loi) {
  if (loi is! Map) return null;
  final data = loi['data'];
  if (data is Map) return tuBody401(data, nguon: NguonBuocDangXuat.socket);
  return tuBody401(
    <String, Object?>{'code': loi['code'], 'idaccount': loi['idaccount']},
    nguon: NguonBuocDangXuat.socket,
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
