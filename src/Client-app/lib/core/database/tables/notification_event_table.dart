import 'package:drift/drift.dart';

/// Nhật ký thông báo — **cục bộ, KHÔNG đi qua đồng bộ, CHỈ THÊM HÀNG** (B5a).
///
/// Mỗi hàng là một sự kiện quanh một thông báo: người dùng phản ứng (mở, gạt,
/// hoãn…) hoặc app đặt / huỷ một lịch với hệ điều hành. B5a chỉ ghi; B5b mới đọc
/// để học giờ nhắc. Chín mã ở `SuKienThongBao` (`nhat_ky_thong_bao.dart`).
///
/// ## Vì sao không có cột đồng bộ
///
/// Cùng lý lẽ với `AppNotifications` (quy tắc 9 `CLAUDE.md`): phản ứng xảy ra
/// trên **một** máy với thông báo chỉ máy ấy hiện. Test quét 15 canh.
///
/// ## Vì sao không lưu `kind`
///
/// Cú chạm hệ điều hành chỉ mang `dedupeKey`; nhóm thông báo suy từ tiền tố
/// khoá lúc đọc. Giờ trong ngày cũng suy từ [luc].
///
/// Thêm ở schema v26 (2026-09-29). Giữ 180 ngày (`NotificationScanner.giuSuKien`).
/// Xoá theo tài khoản ở `purgeDataForOtherAccounts` / `purgeDataForAccount`.
class AppNotificationEvents extends Table {
  TextColumn get id => text()();

  /// Mọi truy vấn đọc **bắt buộc** lọc theo cột này.
  IntColumn get idaccount => integer()();

  /// Đúng chuỗi payload đã giao cho hệ điều hành.
  TextColumn get dedupeKey => text()();

  /// Một trong chín mã của `SuKienThongBao`.
  TextColumn get suKien => text()();

  /// Lúc xảy ra. Riêng `dat_lich`: **mốc hẹn nổ**, không phải lúc đặt.
  DateTimeColumn get luc => dateTime()();

  /// `osScheduledId(dedupeKey)` — chỉ `dat_lich` / `huy_lich`, để `huy_lich`
  /// tra ngược khoá từ id (lời gọi `cancel` chỉ có id).
  IntColumn get osId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
