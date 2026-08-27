import 'package:drift/drift.dart';

/// Bảng Danh Mục (Category)
///
/// Gồm 2 loại: danh mục mặc định (isDefault = true) và danh mục tuỳ chỉnh của user.
/// Danh mục mặc định được seed từ backend khi đăng nhập lần đầu.
class Categories extends Table {
  // ── Primary key ──────────────────────────────────────────────────────────
  TextColumn get id => text()();

  // ── Ownership ────────────────────────────────────────────────────────────
  IntColumn  get idaccount  => integer()();
  // Với danh mục default: idaccount = 0 (không thuộc ai)
  
  // ── Business fields ──────────────────────────────────────────────────────
  TextColumn get name      => text()();
  TextColumn get classify  => text()();
  // 'thu' | 'chi' | 'vay_no' | 'transfer'

  TextColumn get icon    => text().withDefault(const Constant('category'))();
  TextColumn get colour  => text().withDefault(const Constant('#4CAF50'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm (đồng bộ với backend)
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // ── Sync fields ──────────────────────────────────────────────────────────
  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryKeywords extends Table {
  TextColumn get id => text()();
  IntColumn get idaccount => integer()();
  TextColumn get categoryId => text()();
  TextColumn get keyword => text()();
  TextColumn get normalizedKeyword => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {idaccount, categoryId, normalizedKeyword},
  ];
}

class CategoryGroupMemberships extends Table {
  TextColumn get id => text()();
  IntColumn get idaccount => integer()();
  TextColumn get groupId => text()();
  TextColumn get categoryId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {idaccount, categoryId},
  ];
}
