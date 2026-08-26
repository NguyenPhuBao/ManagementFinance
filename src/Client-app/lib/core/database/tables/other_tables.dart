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

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
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
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isPaid      => boolean().withDefault(const Constant(false))();

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
  DateTimeColumn get targetDate  => dateTime()();
  TextColumn   get walletId      => text().nullable()();
  // Idwallet nullable: chưa gán ví đích tiết kiệm

  TextColumn   get icon   => text().withDefault(const Constant('flag'))();
  TextColumn   get colour => text().withDefault(const Constant('#4CAF50'))();
  TextColumn   get note   => text().withDefault(const Constant(''))();
  BoolColumn   get isCompleted => boolean().withDefault(const Constant(false))();

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
