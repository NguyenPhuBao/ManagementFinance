import 'package:drift/drift.dart';

/// Giao dịch có danh mục do AI (Gemma) chọn mà người dùng lưu NGUYÊN — **cục bộ, KHÔNG đi qua đồng bộ**.
///
/// Vòng lặp học sai (mục 5d `CATEGORY_RATIONALE.md`): danh mục AI đoán sai (*"xăng" → Ăn uống*) mà người dùng lưu luôn
/// thành mẫu của B1; B1 đứng TRƯỚC mô hình nên lần sau nó nói lại đúng cái sai ấy và cái sai bị khoá lại. Người dùng
/// chốt 2026-10-16: đánh dấu những giao dịch ấy, B1 bỏ chúng khỏi mẫu học; mở Sửa giao dịch rồi Lưu là gỡ dấu.
///
/// ## Vì sao bảng riêng, không cột trên `transactions`
///
/// Không đụng bảng đồng bộ (payload giao dịch 13 trường, kéo về `insertAllOnConflictUpdate`) — cùng lý lẽ với các bảng
/// AI cục bộ v25–v30: dấu là phán đoán của **một** máy về một lần nó điền form. Máy khác không có dấu thì B1 ở đó học
/// từ giao dịch ấy — chấp nhận, vì máy ấy không phải nơi AI đã đoán. Test quét thứ 15 cấm bảng lọt vào đường đồng bộ.
///
/// Thêm ở schema v31 (2026-10-16). Xoá theo tài khoản ở `purgeDataForOtherAccounts` / `purgeDataForAccount`.
class DanhMucAiDoans extends Table {
  TextColumn get transactionId => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này (quy tắc 2).
  IntColumn get idaccount => integer()();

  /// Danh mục AI chọn lúc lưu — để đọc lại khi cần đo, không dùng trong phép lọc.
  TextColumn get categoryId => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {transactionId};
}
