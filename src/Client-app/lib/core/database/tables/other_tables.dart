import 'package:drift/drift.dart';

/// Bảng Ngân Sách (Budget)
///
/// idcategory NULL = ngân sách tổng (không theo category cụ thể)
class Budgets extends Table {
  TextColumn get id          => text()();
  IntColumn  get idaccount   => integer()();
  TextColumn get categoryId  => text().nullable()();
  // null = ngân sách tổng (không theo category)

  // ── Budget amount fields (DB v2) ──────────────────────────────────────────
  RealColumn get amount       => real()();
  // TotalAmount: tổng ngân sách đặt ra

  RealColumn get spent        => real().withDefault(const Constant(0.0))();
  // Spent: đã chi tiêu

  RealColumn get remaining    => real().nullable()();
  // Remaining: còn lại (nullable, tính = amount - spent)

  IntColumn  get percentSpent => integer().withDefault(const Constant(0))();
  // PercentSpent: 0-100

  TextColumn get overSpending => text().withDefault(const Constant('Over'))();
  // OverSpending: 'Stop' | 'Over' — hành vi khi vượt ngân sách

  RealColumn get overAmount   => real().nullable()();
  // OverAmount: số tiền vượt ngân sách (nullable)

  // ── Threshold warning fields ─────────────────────────────────────────────
  RealColumn get thresholdWarningAmount  => real().nullable()();
  // Threshold_Warning_Amount: số tiền còn lại chạm ngưỡng cảnh báo

  // ── Time fields ───────────────────────────────────────────────────────────
  DateTimeColumn get startDate  => dateTime()();
  DateTimeColumn get endDate    => dateTime().nullable()();

  // ── Recurrence (DB v2) ────────────────────────────────────────────────────
  BoolColumn get recurrence     => boolean().withDefault(const Constant(false))();
  // Recurrence: có lặp lại định kỳ không

  TextColumn get timeRecurrence => text().withDefault(const Constant('Month'))();
  // Time_recurrence: 'Week' | 'Month' | 'Quarter' | 'Year'

  /// period: giữ backward compat với schema cũ (weekly/monthly/yearly)
  TextColumn get period => text().withDefault(const Constant('monthly'))();

  TextColumn get note      => text().withDefault(const Constant(''))();

  /// nextTimeRecurrence: thời điểm bắt đầu chu kỳ ngân sách tiếp theo
  DateTimeColumn get nextTimeRecurrence => dateTime().nullable()();
  // Nexttime_recurrence từ backend

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();

  // ── Trạng thái thất bại khi đẩy (G3) ──────────────────────────────────────
  // Cố ý KHÔNG đổi `syncStatus` sang 'failed' rồi loại bản ghi khỏi `getPending`:
  // nhiều lỗi hợp lệ chỉ tự khỏi SAU khi Pull xong (ví dụ giao dịch còn trỏ tới
  // ID danh mục mặc định cũ), nên loại vĩnh viễn sẽ giết luôn cơ chế thử lại đó.
  // Chặn theo THỜI GIAN: hết `syncBlockedUntil` là bản ghi tự quay lại hàng đợi.
  IntColumn      get syncRetryCount    => integer().withDefault(const Constant(0))();
  TextColumn     get syncError         => text().nullable()();
  DateTimeColumn get syncBlockedUntil  => dateTime().nullable()();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bảng Hoá Đơn / Dịch Vụ Định Kỳ (Bill)
///
/// Idwallet & Idcategory bắt buộc theo backend v2.
class Bills extends Table {
  TextColumn get id         => text()();
  IntColumn  get idaccount  => integer()();

  // ── Relations (DB v2) ─────────────────────────────────────────────────────
  /// walletId: ví thanh toán bill (BẮT BUỘC theo backend v2)
  TextColumn get walletId   => text().nullable()();
  // nullable trên client để backward compat — cần set khi tạo mới

  /// categoryId: danh mục bill (BẮT BUỘC theo backend v2)
  TextColumn get categoryId => text().nullable()();
  // nullable trên client để backward compat

  // ── Business fields ───────────────────────────────────────────────────────
  TextColumn get name       => text()();
  RealColumn get amount     => real()();

  /// startDate: ngày bắt đầu tính hoá đơn (Start_date từ backend)
  DateTimeColumn get startDate => dateTime().nullable()();

  DateTimeColumn get dueDate => dateTime()();

  /// payStatus: trạng thái thanh toán — 'Pending' | 'Payed' | 'Overdue'
  /// Thay thế isPaid (boolean) để biểu diễn đủ 3 trạng thái từ backend
  TextColumn get payStatus => text().withDefault(const Constant('Pending'))();

  /// isPaid: giữ backward compat — TRUE = Payed, FALSE = Pending
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();

  /// timeNotification: số ngày nhắc trước khi đến hạn — '1' | '3' | '5' | '7'
  TextColumn get timeNotification => text().nullable()();

  // ── Recurrence (DB v2: tách thành bool + time) ───────────────────────────
  /// isRecurrence: có lặp lại định kỳ không (DB v2: Recurrence bool)
  BoolColumn get isRecurrence => boolean().withDefault(const Constant(false))();

  /// timeRecurrence: 'Week' | 'Month' | 'Quarter' | 'Year' (DB v2)
  TextColumn get timeRecurrence => text().withDefault(const Constant('Month'))();

  /// recurrence: giữ backward compat — text cũ ('once'/'weekly'/'monthly'...)
  TextColumn get recurrence => text().withDefault(const Constant('monthly'))();

  TextColumn get icon   => text().withDefault(const Constant('receipt'))();
  TextColumn get colour => text().withDefault(const Constant('#4CAF50'))();
  TextColumn get note   => text().withDefault(const Constant(''))();

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();

  // ── Trạng thái thất bại khi đẩy (G3) ──────────────────────────────────────
  // Cố ý KHÔNG đổi `syncStatus` sang 'failed' rồi loại bản ghi khỏi `getPending`:
  // nhiều lỗi hợp lệ chỉ tự khỏi SAU khi Pull xong (ví dụ giao dịch còn trỏ tới
  // ID danh mục mặc định cũ), nên loại vĩnh viễn sẽ giết luôn cơ chế thử lại đó.
  // Chặn theo THỜI GIAN: hết `syncBlockedUntil` là bản ghi tự quay lại hàng đợi.
  IntColumn      get syncRetryCount    => integer().withDefault(const Constant(0))();
  TextColumn     get syncError         => text().nullable()();
  DateTimeColumn get syncBlockedUntil  => dateTime().nullable()();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bảng Mục Tiêu Tài Chính (Goal)
///
/// Idwallet nullable — chưa gán ví đích.
class Goals extends Table {
  TextColumn get id         => text()();
  IntColumn  get idaccount  => integer()();

  TextColumn   get name          => text()();
  RealColumn   get targetAmount  => real()();
  RealColumn   get currentAmount => real().withDefault(const Constant(0.0))();

  /// startDate: ngày bắt đầu tích luỹ (Start_date từ backend)
  DateTimeColumn get startDate => dateTime().nullable()();

  DateTimeColumn get targetDate  => dateTime()();
  TextColumn   get walletId      => text().nullable()();
  // Idwallet nullable: chưa gán ví đích tiết kiệm

  /// cycleTakeMoney: chu kỳ trích tiền — 'Day'|'Week'|'Month'|'Quarter'|'Year'
  TextColumn get cycleTakeMoney => text().nullable()();

  /// timeCycleTakeMoney: thời điểm cụ thể trích tiền trong chu kỳ
  DateTimeColumn get timeCycleTakeMoney => dateTime().nullable()();

  /// recurrence: tự động lặp lại mục tiêu sau khi hoàn thành
  BoolColumn get recurrence => boolean().withDefault(const Constant(false))();

  /// timeRecurrence: chu kỳ lặp lại — 'Day'|'Week'|'Month'|'Quarter'|'Year'
  TextColumn get timeRecurrence => text().nullable()();

  TextColumn   get icon   => text().withDefault(const Constant('flag'))();
  TextColumn   get colour => text().withDefault(const Constant('#4CAF50'))();
  TextColumn   get note   => text().withDefault(const Constant(''))();
  BoolColumn   get isCompleted => boolean().withDefault(const Constant(false))();

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();

  // ── Trạng thái thất bại khi đẩy (G3) ──────────────────────────────────────
  // Cố ý KHÔNG đổi `syncStatus` sang 'failed' rồi loại bản ghi khỏi `getPending`:
  // nhiều lỗi hợp lệ chỉ tự khỏi SAU khi Pull xong (ví dụ giao dịch còn trỏ tới
  // ID danh mục mặc định cũ), nên loại vĩnh viễn sẽ giết luôn cơ chế thử lại đó.
  // Chặn theo THỜI GIAN: hết `syncBlockedUntil` là bản ghi tự quay lại hàng đợi.
  IntColumn      get syncRetryCount    => integer().withDefault(const Constant(0))();
  TextColumn     get syncError         => text().nullable()();
  DateTimeColumn get syncBlockedUntil  => dateTime().nullable()();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
