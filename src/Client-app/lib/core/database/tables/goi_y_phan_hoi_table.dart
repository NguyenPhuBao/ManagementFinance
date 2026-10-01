import 'package:drift/drift.dart';

/// Bảng phản hồi thẻ *"Gợi ý danh mục"* của màn Thêm giao dịch — **cục bộ, KHÔNG đi qua đồng bộ**.
///
/// B1 (spec `2026-09-28-goi-y-danh-muc-hoc-tu-ghi-chu-design.md` mục 3.3). Mỗi lần người dùng phân xử một gợi ý
/// đang hiện — bấm *Chọn* (`chon`), bấm *Bỏ qua* (`bo_qua`), hay chọn danh mục khác rồi lưu (`khac`) — ghi một hàng.
/// Thẻ bị huỷ vì đổi ghi chú / đổi đoạn thì KHÔNG ghi: đó không phải phán xét của người dùng.
///
/// Dùng vào hai việc: đo tỉ lệ gợi ý đúng thật, và **thôi gợi ý** một cặp (cụm, danh mục) nguồn học đã bị bỏ qua hai
/// lần (`tatCapTu`, mở lại sau ba giao dịch mới).
///
/// ## Vì sao không có cột đồng bộ
///
/// Cố ý KHÔNG có `syncStatus` / `syncError` / `updatedAt` / `isDeleted`, cùng lý lẽ với `AppNotifications` và
/// `AiRebalancingFeedbacks` (quy tắc 9 `CLAUDE.md`): phản hồi là quyết định trên **một** máy về một gợi ý chỉ máy
/// ấy tính ra; mỗi máy tự học từ sổ đã đồng bộ nên kết quả gần như nhau. Test quét thứ 15
/// (`test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart`) cấm nó lọt vào đường đồng bộ.
///
/// Thêm ở schema v25 (2026-09-29). Xoá theo tài khoản ở `purgeDataForOtherAccounts` / `purgeDataForAccount`.
class GoiYDanhMucPhanHois extends Table {
  TextColumn get id => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này (quy tắc 2).
  IntColumn get idaccount => integer()();

  /// Lúc người dùng phân xử — luật mở lại đếm giao dịch có ngày SAU mốc này.
  DateTimeColumn get createdAt => dateTime()();

  /// `hoc` | `tu_khoa` | `de_xuat_tu_khoa`.
  TextColumn get nguon => text()();

  /// Cụm âm tiết đã bỏ dấu (nguồn `hoc`, và cụm được đề xuất làm từ khoá — nguồn `de_xuat_tu_khoa`), hoặc từ khoá khớp
  /// (nguồn `tu_khoa`).
  TextColumn get amTietChinh => text()();

  TextColumn get goiYCategoryId => text()();

  /// `chon` | `bo_qua` | `khac`.
  TextColumn get ketQua => text()();

  /// Danh mục cuối cùng lưu cùng giao dịch; `null` khi bỏ qua mà không lưu.
  TextColumn get chonCategoryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
