import 'package:drift/drift.dart';

/// Phản hồi của người dùng với thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn (B2)
/// — **cục bộ, KHÔNG đi qua đồng bộ**, cùng khuôn `ai_feedback_table.dart`.
///
/// `bo_qua`: ẩn nhóm, mở lại khi có ≥ 3 khoản mới sau lần bỏ qua cuối (cùng
/// luật B1: bằng chứng mới thắng lời từ chối cũ). `da_tao`: ẩn **vĩnh viễn** —
/// cần vì người dùng có thể ĐỔI TÊN trong form tạo, khi ấy phép so tên với hoá
/// đơn đang sống không bắt được nữa. Luật đọc ở `chonDeXuatHoaDon`.
///
/// ## Vì sao không có cột đồng bộ
///
/// Cùng lý lẽ với `AppNotifications` (quy tắc 9 `CLAUDE.md`): gợi ý suy lại
/// được từ sổ giao dịch trên từng máy. Test quét 15 canh.
///
/// Thêm ở schema v27 (2026-09-29). Xoá theo tài khoản ở
/// `purgeDataForOtherAccounts` / `purgeDataForAccount`.
class GoiYHoaDonPhanHois extends Table {
  TextColumn get id => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này.
  IntColumn get idaccount => integer()();

  /// `KhoanLap.khoaNhom` — `'<ghi chú chuẩn hoá>|<categoryId>'`.
  TextColumn get khoaNhom => text()();

  /// `bo_qua` | `da_tao` (`kGoiYBoQua` / `kGoiYDaTao`).
  TextColumn get ketQua => text()();

  /// Lúc bấm — mốc để đếm "khoản mới sau lần Bỏ qua".
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
