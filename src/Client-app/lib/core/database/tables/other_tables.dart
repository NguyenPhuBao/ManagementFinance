import 'package:drift/drift.dart';

/// Bảng Ngân Sách (Budget)
class Budgets extends Table {
  TextColumn get id => text()();
  IntColumn  get idaccount  => integer()();
  TextColumn get categoryId => text().nullable()();
  // null = ngân sách tổng (không theo category)

  RealColumn   get amount     => real()();
  TextColumn   get period     => text().withDefault(const Constant('monthly'))();
  // 'weekly' | 'monthly' | 'yearly'

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate   => dateTime().nullable()();
  TextColumn     get note      => text().withDefault(const Constant(''))();
  BoolColumn     get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bảng Hoá Đơn / Dịch Vụ Định Kỳ (Bill)
class Bills extends Table {
  TextColumn get id => text()();
  IntColumn  get idaccount  => integer()();

  TextColumn get name       => text()();
  RealColumn get amount     => real()();
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isPaid      => boolean().withDefault(const Constant(false))();
  TextColumn get recurrence  => text().withDefault(const Constant('monthly'))();
  // 'once' | 'weekly' | 'monthly' | 'yearly'

  TextColumn get icon   => text().withDefault(const Constant('receipt'))();
  TextColumn get colour => text().withDefault(const Constant('#4CAF50'))();
  TextColumn get note   => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bảng Mục Tiêu Tài Chính (Goal)
class Goals extends Table {
  TextColumn get id => text()();
  IntColumn  get idaccount  => integer()();

  TextColumn   get name          => text()();
  RealColumn   get targetAmount  => real()();
  RealColumn   get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate  => dateTime()();
  TextColumn   get walletId => text().nullable()();
  TextColumn   get icon   => text().withDefault(const Constant('flag'))();
  TextColumn   get colour => text().withDefault(const Constant('#4CAF50'))();
  TextColumn   get note   => text().withDefault(const Constant(''))();
  BoolColumn   get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn   get isDeleted   => boolean().withDefault(const Constant(false))();

  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
