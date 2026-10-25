/// Mốc kéo về (`since` của `/sync/pull`) suy từ phản hồi của server — **G67**.
///
/// Trước đây mốc là `update_at` lớn nhất trong dữ liệu vừa kéo, mà `update_at` là
/// giờ ghi **của máy** (cũng là khoá LWW). Bản ghi của một máy offline lâu rồi đẩy
/// muộn mang giờ ghi cũ, rơi dưới mốc của máy khác và **không bao giờ** được kéo —
/// im lặng, không tự lành. Từ migration 20 (+ 21 sửa đồng hồ) server lọc và sắp
/// theo cột giờ-server `Server_update_at`, và trả `maxSince` từng bảng.
library;

/// Khoảng lùi an toàn trước giờ server lúc trả lời.
///
/// Server truy vấn sáu bảng **tuần tự**, không bọc giao tác, và giờ-server của một
/// hàng là lúc ghi chứ không phải lúc commit. Một hàng commit trong lúc server đang
/// kéo có thể mang giờ nhỏ hơn mốc lớn nhất — kể cả khi bảng của nó trả 0 hàng
/// (không có khoá trong `maxSince`). Nhưng giờ của nó luôn gần `pulledAt`, nên mốc
/// không bao giờ vượt `pulledAt − khoảng này` là đủ để nó được hỏi lại ở lượt sau;
/// hai phút bao cả độ trễ commit lẫn lệch đồng hồ giữa máy chủ Node và CSDL.
const kLuiAnToanKeoVe = Duration(minutes: 2);

/// Mốc mới từ `maxSince` (bảng → ISO) và `pulledAt` của phản hồi `/sync/pull`.
///
/// `null` = **giữ nguyên mốc cũ** (không bảng nào có hàng, hoặc giá trị rác).
/// Người gọi phân biệt "server cũ, không có `maxSince`" bằng chính sự vắng mặt của
/// khoá trước khi gọi hàm này.
///
/// - Lấy **lớn nhất** giữa các bảng: mọi hàng mang giờ ≤ mốc ấy đã nằm trong chính
///   phản hồi này (cùng một `since` cho cả sáu bảng). ⚠️ **Đừng đổi sang nhỏ nhất**:
///   nghiệm thu hai máy ảo 2026-10-08 đo được bản ấy neo mốc vào bảng lâu không đổi
///   (mục tiêu sửa từ 05/10) — mỗi lượt kéo lại gần hết dữ liệu. Hàng ghi xen giữa
///   hai truy vấn đã có phép kẹp ngay dưới che.
/// - Kẹp về `pulledAt − kLuiAnToanKeoVe` khi dữ liệu còn "nóng".
/// - Khi đã nguội (mốc ≤ `pulledAt − kLuiAnToanKeoVe`) thì cộng **1 ms**: giờ-server
///   lưu tới micro giây mà JSON chỉ mang mili giây, nên mốc cắt cụt luôn nhỏ hơn
///   hàng cuối và hàng ấy bị kéo lại ở **mọi** chu kỳ. An toàn vì mọi hàng mang giờ
///   tới mốc ấy đã commit trước lúc server truy vấn (độ trễ commit < khoảng lùi), nên
///   đã nằm trong chính phản hồi này.
DateTime? mocTuMaxSince(
  Object? maxSince, {
  Object? pulledAt,
  Duration lui = kLuiAnToanKeoVe,
}) {
  if (maxSince is! Map) return null;
  DateTime? lonNhat;
  for (final v in maxSince.values) {
    if (v == null) continue;
    final t = DateTime.tryParse(v.toString())?.toUtc();
    if (t == null) continue;
    if (lonNhat == null || t.isAfter(lonNhat)) lonNhat = t;
  }
  if (lonNhat == null) return null;

  final gioServer =
      pulledAt == null ? null : DateTime.tryParse(pulledAt.toString())?.toUtc();
  if (gioServer == null) return lonNhat;
  final tran = gioServer.subtract(lui);
  if (tran.isBefore(lonNhat)) return tran;
  final coLe = lonNhat.add(const Duration(milliseconds: 1));
  return coLe.isAfter(tran) ? tran : coLe;
}

/// Mốc đã lưu, hoặc `null` nếu nó nằm ở **tương lai**.
///
/// `null` ở đây kéo theo một lần full pull (`since = 1970`), đúng thứ cần cho
/// một máy đang kẹt: mốc hỏng che mất đúng khoảng dữ liệu bị bỏ lỡ, nên kẹp
/// nó về "bây giờ" vẫn không lấy lại được phần ấy.
///
/// Đường chạy thật dùng nó ở `ApDuLieuKeoVe.napMoc` / `napMocNeuChuaCo`. Hàm chuyển tiếp `SyncEngine.mocPullConDungKhong`
/// (0 chỗ gọi) gỡ 2026-10-20; tệp này là nội bộ của `core/sync` (quét 35).
DateTime? mocPullConDungKhong(DateTime? daLuu, DateTime bayGio) {
  if (daLuu == null) return null;
  return daLuu.isAfter(bayGio) ? null : daLuu;
}

/// Kẹp một mốc **sắp ghi** về không quá hiện tại.
///
/// Khác [mocPullConDungKhong] ở chỗ nó *kẹp* thay vì *vứt*: ở đường ghi ta
/// vừa nhận xong dữ liệu, nên "bây giờ" là mốc đúng — không có khoảng nào bị
/// bỏ lỡ để mà phải kéo lại.
DateTime? kepVeHienTai(DateTime? moc) {
  if (moc == null) return null;
  final bayGio = DateTime.now().toUtc();
  return moc.isAfter(bayGio) ? bayGio : moc;
}

/// Tìm `update_at` mới nhất trong toàn bộ payload pull (mọi loại thực thể).
///
/// Chỉ còn là đường lùi cho server **chưa** trả `maxSince` (trước migration 20)
/// — xem [mocTuMaxSince] và G67.
DateTime? newestUpdateAt(Map<String, dynamic> payloadData) {
  DateTime? newest;
  for (final value in payloadData.values) {
    if (value is! List) continue;
    for (final row in value) {
      if (row is! Map) continue;
      final raw = (row['update_at'] ?? row['updated_at'])?.toString();
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw)?.toUtc();
      if (parsed == null) continue;
      if (newest == null || parsed.isAfter(newest)) newest = parsed;
    }
  }
  return newest;
}
