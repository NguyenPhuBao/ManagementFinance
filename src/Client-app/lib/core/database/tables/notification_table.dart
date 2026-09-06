import 'package:drift/drift.dart';

/// Bảng Thông Báo — **cục bộ, KHÔNG đi qua đồng bộ**.
///
/// ⚠️ Tên bảng là `AppNotifications` chứ không phải `Notifications`: Drift sinh
/// data class ở dạng số ít, và `Notification` là lớp có thật trong
/// `package:flutter/widgets.dart` (cơ chế `NotificationListener`). Đặt tên kia
/// thì mọi file import cả `app_database.dart` lẫn `material.dart` đều vỡ, và
/// cách chữa duy nhất là rải `hide` khắp nơi. Dự án đã dính đúng vết này với
/// `Category` — xem `lib/core/sync/sync_engine.dart` dòng đầu.
///
/// ## Vì sao không có cột đồng bộ
///
/// Bảng này cố ý KHÔNG có `syncStatus` / `syncError` / `updatedAt` / `isDeleted`
/// như sáu bảng kia. Thông báo là dữ liệu **suy ra được** từ ngân sách, hoá đơn
/// và mục tiêu đang có sẵn trong máy — mỗi thiết bị tự tính lấy. Việc vắng mặt
/// những cột đó chính là tài liệu sống nói: đừng thêm bảng này vào
/// `SyncEntityType`, và đừng đụng `sync_payload_contract_test.dart` vì nó.
@TableIndex(name: 'idx_appnotif_feed', columns: {#idaccount, #createdAt})
class AppNotifications extends Table {
  TextColumn get id => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này. Bỏ sót là thông báo tài
  /// chính của tài khoản khác hiện ra trên máy dùng chung.
  IntColumn get idaccount => integer()();

  /// `budgetNearLimit` | `budgetOverspent` | `billDueSoon` | `billOverdue`
  /// | `goalCompleted` | `goalBehind` | `syncFailed` | `walletNegative`
  TextColumn get kind => text()();

  /// Khoá chống trùng — **trái tim của bảng này**.
  ///
  /// Gồm *loại + chủ thể + đơn vị lặp lại hợp lệ*, và **tuyệt đối không chứa
  /// giá trị biến thiên liên tục** (số đã chi, phần trăm thô). Nhét `spent` vào
  /// đây là biến mỗi giao dịch thành một thông báo mới.
  ///
  /// Cùng với `uniqueKeys` bên dưới và `InsertMode.insertOrIgnore`, đây là toàn
  /// bộ cơ chế chống trùng. Kiểm bằng Dart (`SELECT` rồi `INSERT`) không đủ:
  /// quét được kích hoạt từ nhiều nguồn, hai nguồn nổ gần nhau sẽ cùng đi qua
  /// nhánh "chưa có" trước khi bên nào kịp ghi.
  TextColumn get dedupeKey => text()();

  TextColumn get title => text()();
  TextColumn get body => text()();

  /// `info` | `warning` | `critical` — quyết định màu dải và biểu tượng.
  TextColumn get severity => text()();

  /// `budget` | `bill` | `goal` | `sync` | `wallet`
  TextColumn get subjectType => text().nullable()();

  /// Id bản ghi gốc, để huỷ lịch khi bản ghi đó bị xoá.
  TextColumn get subjectId => text().nullable()();

  /// Route go_router để điều hướng khi người dùng chạm vào.
  TextColumn get deeplink => text().nullable()();

  /// Mốc của **sự kiện**, không phải mốc quét.
  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get readAt => dateTime().nullable()();

  /// Xoá mềm. **Giữ hàng lại** vì chính hàng này là bản ghi khoá trùng — xoá
  /// hẳn thì lần quét sau sinh lại ngay, người dùng xoá mãi không hết.
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  /// Id đã cấp cho `flutter_local_notifications`, để huỷ lịch.
  IntColumn get osScheduledId => integer().nullable()();

  /// Đã bắn ra hệ điều hành chưa. null = mới chỉ tồn tại trong app.
  DateTimeColumn get osDeliveredAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {idaccount, dedupeKey}
      ];
}
