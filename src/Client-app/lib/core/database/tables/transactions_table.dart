import 'package:drift/drift.dart';
import 'wallets_table.dart';

/// Bảng Giao Dịch (Transaction)
///
/// Amount giữ dấu ±: dương (+) = tiền vào, âm (-) = tiền ra.
/// Provider: Manual / Casso / SMS / OCR.
class Transactions extends Table {
  // ── Primary key ──────────────────────────────────────────────────────────
  TextColumn get id => text()();

  // ── Relations ────────────────────────────────────────────────────────────
  TextColumn get walletId   => text().references(Wallets, #id)();
  IntColumn  get idaccount  => integer()();
  TextColumn get categoryId => text().nullable()();
  // nullable: giao dịch có thể chưa chọn category (transfer, webhook Casso)

  // ── Business fields ──────────────────────────────────────────────────────
  RealColumn   get amount  => real()();
  // ± dương = tiền vào, âm = tiền ra

  TextColumn   get type    => text()();
  // 'Transaction' | 'Transfer' (theo backend v2)

  /// Provider: nguồn tạo giao dịch
  /// 'Manual' | 'Casso' | 'SMS' | 'OCR'
  TextColumn get provider => text().withDefault(const Constant('Manual'))();

  TextColumn   get note    => text().withDefault(const Constant(''))();
  DateTimeColumn get date  => dateTime()();
  TextColumn   get images  => text().withDefault(const Constant('[]'))();
  // JSON array string của đường dẫn ảnh đính kèm

  // ── Transfer fields (DB v2) ───────────────────────────────────────────────
  /// walletTransfer: Wallet_Transfer — ví đích khi chuyển khoản nội bộ
  TextColumn get walletTransfer => text().nullable()();

  /// bankTranId: Bank_tran_id — ID giao dịch từ ngân hàng (Casso/SMS)
  /// Dùng để chống trùng (provider, bankTranId) phải unique
  TextColumn get bankTranId => text().nullable()();

  // ── Soft delete (DB v2) ───────────────────────────────────────────────────
  /// deletedAt: NULL = đang dùng, có giá trị = đã xóa mềm
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // ── Sync fields ──────────────────────────────────────────────────────────
  TextColumn     get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt  => dateTime()();
  BoolColumn     get isDeleted  => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
