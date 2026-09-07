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
  // 'chi' | 'thu' | 'transfer' — bộ giá trị NỘI BỘ của client, KHÔNG phải
  // 'Transaction' | 'Transfer' của backend. `SyncPayloadNormalizer` quy đổi:
  // chi/thu → Transaction với dấu amount, transfer → Transfer. Chiều tiền của
  // giao dịch gắn danh mục vay/nợ cũng nằm ở đây (người dùng chọn trên form).

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

  /// goalId: mục tiêu tiết kiệm mà giao dịch này thuộc về. NULL với mọi giao
  /// dịch thường.
  ///
  /// ✅ **ĐÃ ĐỒNG BỘ từ 2026-09-07**, khi backend thêm cột `transaction.Idgoal`.
  /// Tên trong payload là **`idgoal`**, KHÔNG phải `goal_id` — `goal_id` là tên
  /// cột Drift và vẫn nằm trong danh sách *cấm rò rỉ* của
  /// `sync_payload_contract_test.dart`. Hai cái tên chỉ khác nhau ở đúng chỗ
  /// này, và gửi nhầm thì backend bỏ qua **trong im lặng**.
  ///
  /// ⚠️ Nhánh kéo về dùng `Value.absent()` khi server không gửi `idgoal`, chứ
  /// KHÔNG ghi đè null. Mọi hàng đã nằm sẵn trên server đều mang NULL cho tới
  /// khi client đẩy lại từng hàng, nên ghi đè thẳng là xoá sạch liên kết cục bộ
  /// ngay ở chu kỳ đồng bộ đầu tiên. Có test canh đúng ca này.
  ///
  /// Vì hàng cũ trên server vẫn trống cột này, nơi đọc
  /// (`TransactionDao.watchByGoal`) **vẫn phải giữ** nhánh tra theo ghi chú —
  /// nó chỉ teo dần khi từng hàng được đẩy lại, chứ không hết ngay.
  ///
  /// Vì sao cần: trước đây lịch sử tích luỹ tra bằng
  /// `note LIKE '%Tích lũy mục tiêu: <tên>%'`. Tên mục tiêu không duy nhất, và
  /// tệ hơn, một tên là **tiền tố** của tên khác ("Mua" với "Mua xe") thì nuốt
  /// luôn lịch sử của mục tiêu kia.
  TextColumn get goalId => text().nullable()();

  /// billId: hoá đơn mà giao dịch này là khoản trả cho. NULL với mọi giao dịch
  /// thường.
  ///
  /// ⚠️ **Cột CỤC BỘ — cùng lý do và cùng ràng buộc với [goalId] ở trên.**
  ///
  /// Vì sao cần: trước đây khoản trả hoá đơn chỉ nhận ra được bằng **tiền tố
  /// ghi chú** (`kGhiChuTraHoaDon`), nên (1) người dùng gõ trùng tiền tố thì bị
  /// chặn xoá oan, và (2) không có đường nào lần từ hoá đơn ngược về đúng
  /// khoản chi nó đã sinh ra — thứ mà luồng **hoàn tác thanh toán** bắt buộc
  /// phải có để hoàn đúng số tiền vào đúng ví.
  ///
  /// Hàng kéo về từ server và hàng do bản app cũ tạo đều để trống cột này, nên
  /// hoàn tác chỉ làm được với khoản trả ghi từ bản 2026-09-06 trở đi;
  /// `BillRepositoryImpl.undoPayment` từ chối có thông báo rõ thay vì đoán.
  TextColumn get billId => text().nullable()();

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
