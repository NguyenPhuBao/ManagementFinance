import 'package:drift/drift.dart';
import 'wallets_table.dart';

/// Bảng Giao Dịch (Transaction)
class Transactions extends Table {
  // ── Primary key ──────────────────────────────────────────────────────────
  TextColumn get id => text()();

  // ── Relations ────────────────────────────────────────────────────────────
  TextColumn get walletId   => text().references(Wallets, #id)();
  IntColumn  get idaccount  => integer()();
  TextColumn get categoryId => text().nullable()();
  // nullable: giao dịch có thể chưa chọn category (transfer, điều chỉnh số dư)

  // ── Business fields ──────────────────────────────────────────────────────
  RealColumn   get amount  => real()();
  TextColumn   get type    => text()();
  // 'thu' | 'chi' | 'transfer' | 'adjustment'

  TextColumn   get note    => text().withDefault(const Constant(''))();
  DateTimeColumn get date  => dateTime()();
  TextColumn   get images  => text().withDefault(const Constant('[]'))();
  // JSON array string của đường dẫn ảnh đính kèm

  // ── Sync fields ──────────────────────────────────────────────────────────
  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();
  BoolColumn     get isDeleted  => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
