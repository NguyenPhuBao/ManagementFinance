import 'package:drift/drift.dart';

/// Giây xem theo (tài khoản, ngày, cụm khối) của trang Phân tích — **cục bộ,
/// KHÔNG đi qua đồng bộ** (quy tắc 9 `CLAUDE.md`, test quét 15). Dự án C việc
/// ba, spec 2026-10-05 mục 4.2. Thêm ở schema v29.
///
/// `ngay` là chuỗi `yyyy-MM-dd` theo giờ máy (`maNgay`) — so chuỗi đúng thứ tự
/// ngày. `cum` là `CumKhoi.ma`; mã lạ đọc lên thì **bỏ qua**. Hàng cũ hơn 90
/// ngày bị dọn mỗi lần ghi. Xoá theo tài khoản ở hai hàm purge.
class PhanTichGiayXems extends Table {
  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này.
  IntColumn get idaccount => integer()();
  TextColumn get ngay => text()();
  TextColumn get cum => text()();
  IntColumn get giay => integer()();

  @override
  Set<Column> get primaryKey => {idaccount, ngay, cum};
}

/// Nhật ký phản hồi thẻ "đưa lên đầu trang": `dua_len` · `bo_qua` ·
/// `ve_mac_dinh`. Thứ tự hiện tại **suy** từ bảng này (`thuTuTu`) — không lưu
/// riêng. Cục bộ, cùng lý lẽ với bảng trên.
class PhanTichThuTuPhanHois extends Table {
  TextColumn get id => text()();
  IntColumn get idaccount => integer()();

  /// `CumKhoi.ma`; chuỗi rỗng với `ve_mac_dinh`.
  TextColumn get cum => text()();
  TextColumn get ketQua => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
