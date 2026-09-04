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
  ///
  /// ⚠️ **Cột này KHÔNG đi qua đồng bộ theo chiều nào cả**, và **không có mapper
  /// chuẩn hoá nào**. Payload đẩy (`sync_engine.dart`, `_collectPendingOps`)
  /// gồm 11 trường và không có `provider`; nhánh kéo về cũng không đọc nó. Nên
  /// mọi hàng client đẩy lên đều nằm trên server với `Provider = 'Manual'`, kể
  /// cả giao dịch do ngân hàng tạo rồi kéo về máy này.
  ///
  /// Chú thích cũ ở đây từng hứa "sync mapper sẽ chuẩn hoá Casso→BankSync,
  /// OCR→ORC". **Hành vi đó chưa bao giờ tồn tại** — đã kiểm ngày 2026-09-04.
  ///
  /// Trước khi thêm cột này vào payload đẩy, đọc `docs/superpowers/backend/
  /// 2026-09-04-ocr-classify-review.md` mục 7: backend đang có
  /// `@@unique([provider, bank_tran_id])` **không tách theo tài khoản**, và
  /// ràng buộc đó hiện chỉ trơ vì client gửi lên toàn NULL.
  TextColumn get provider => text().withDefault(const Constant('Manual'))();

  TextColumn   get note    => text().withDefault(const Constant(''))();
  DateTimeColumn get date  => dateTime()();
  TextColumn   get images  => text().withDefault(const Constant('[]'))();
  // JSON array string của đường dẫn ảnh đính kèm

  // ── Transfer fields (DB v2) ───────────────────────────────────────────────
  /// walletTransfer: Wallet_Transfer — ví đích khi chuyển khoản nội bộ
  TextColumn get walletTransfer => text().nullable()();

  /// bankTranId: Bank_tran_id — ID giao dịch từ ngân hàng (Casso/SMS)
  ///
  /// ⚠️ **Bảng này KHÔNG khai `uniqueKeys`**, nên `(provider, bankTranId)`
  /// **không** duy nhất ở SQLite — chú thích cũ hứa như vậy là sai. Phía
  /// PostgreSQL thì có `uq_transaction_external`, nhưng nó ràng buộc trên
  /// **toàn bảng** chứ không theo từng tài khoản.
  ///
  /// ⚠️ Cột này cũng **không đi qua đồng bộ theo chiều nào**, giống `provider`.
  /// Hiện chưa nơi nào trong app gán giá trị cho nó, nên nó luôn NULL.
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
