import 'package:drift/drift.dart';

/// Bảng phản hồi tái phân bổ ngân sách — **cục bộ, KHÔNG đi qua đồng bộ**.
///
/// Mỗi dòng của một kế hoạch tái phân bổ (Edge-SLM Tầng 2, luật E3) ghi một
/// hàng khi người dùng quyết: chấp nhận / sửa số / từ chối. Đây là nguồn dữ
/// liệu **duy nhất** cho phần "học từ phản hồi" về sau (E4, hoãn) — không có
/// bảng này thì sáu tháng nữa vẫn trắng tay; và ngay bây giờ luật C3 đọc nó để
/// hạ trần cắt xuống 15 % cho danh mục đã bị cắt hai kỳ liền trước.
///
/// ## Vì sao không có cột đồng bộ
///
/// Cố ý KHÔNG có `syncStatus` / `syncError` / `updatedAt` / `isDeleted`, cùng lý
/// lẽ với `AppNotifications` (quy tắc 9 `CLAUDE.md`): phản hồi là quyết định
/// trên **một** máy về một kế hoạch chỉ máy ấy tính ra; server không có bảng
/// tương ứng và không nên có. Test quét thứ 15
/// (`test/features/ai_edge/ai_edge_cuc_bo_khong_dong_bo_test.dart`) cấm nó lọt
/// vào `SyncEntityType` và đường đồng bộ.
///
/// Thêm ở schema v24 (2026-09-19). Xoá theo tài khoản ở
/// `purgeDataForOtherAccounts` / `purgeDataForAccount`.
class AiRebalancingFeedbacks extends Table {
  TextColumn get id => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này.
  IntColumn get idaccount => integer()();

  /// Lúc người dùng quyết, không phải lúc kế hoạch được tính.
  DateTimeColumn get createdAt => dateTime()();

  TextColumn get deficitBudgetId => text()();
  TextColumn get donorBudgetId => text()();

  /// Giữ cả danh mục của nguồn bù: ngân sách có thể bị xoá, danh mục thì
  /// xoá mềm nên id còn.
  TextColumn get donorCategoryId => text()();

  RealColumn get suggestedAmount => real()();

  /// Số người dùng chốt: bằng [suggestedAmount] khi `accepted`, số họ sửa khi
  /// `modified`, `0` khi `rejected`.
  RealColumn get actualAmount => real()();

  /// `accepted` | `rejected` | `modified`.
  TextColumn get action => text()();

  /// Kỳ của ngân sách **nguồn bù** lúc bị cắt, biên `[from, to)` — luật C3 đếm
  /// "hai kỳ liền trước" bằng cặp này.
  DateTimeColumn get periodFrom => dateTime()();
  DateTimeColumn get periodTo => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
