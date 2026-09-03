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

  /// status: trạng thái giao dịch — 'Pending' | 'Confirmed' | 'Rejected' | 'Fail'
  /// Mặc định 'Confirmed' (khớp backend default)
  TextColumn get status => text().withDefault(const Constant('Confirmed'))();

  /// provider: nguồn tạo giao dịch
  /// Backend values: 'Manual' | 'BankSync' | 'SMS' | 'ORC' | 'Bill'
  /// Client legacy:  'Manual' | 'Casso'   | 'SMS' | 'OCR'
  /// Sync mapper sẽ chuẩn hoá: Casso→BankSync, OCR→ORC
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

  // ── Trạng thái thất bại khi đẩy (G3) ──────────────────────────────────────
  // Cố ý KHÔNG đổi `syncStatus` sang 'failed' rồi loại bản ghi khỏi `getPending`:
  // nhiều lỗi hợp lệ chỉ tự khỏi SAU khi Pull xong (ví dụ giao dịch còn trỏ tới
  // ID danh mục mặc định cũ), nên loại vĩnh viễn sẽ giết luôn cơ chế thử lại đó.
  // Chặn theo THỜI GIAN: hết `syncBlockedUntil` là bản ghi tự quay lại hàng đợi.
  IntColumn      get syncRetryCount    => integer().withDefault(const Constant(0))();
  TextColumn     get syncError         => text().nullable()();
  DateTimeColumn get syncBlockedUntil  => dateTime().nullable()();
  DateTimeColumn get updatedAt  => dateTime()();
  BoolColumn     get isDeleted  => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
