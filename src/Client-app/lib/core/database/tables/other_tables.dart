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
  // Spent: đã chi tiêu.
  //
  // Backend KHÔNG tự cập nhật cột này (không có tác vụ nền tính lại), và giao
  // dịch thì người dùng ghi được khi offline. `BudgetRepositoryImpl` vì thế
  // cộng lại từ bảng `transactions` mỗi lần đọc rồi ghi xuống đây bằng
  // `cacheSpent()` — chỉ để lần đẩy sau gửi đúng số, KHÔNG phải nguồn sự thật.
  //
  // Đã bỏ ở v11: `remaining` và `percent_spent`. Cả hai chỉ là amount - spent
  // và spent / amount, lưu lại chỉ tạo thêm một bản sao có thể lệch; backend
  // cũng không có cột nào tương ứng nên chúng không bao giờ được đồng bộ. Nay
  // tính ở `BudgetEntity`.

  TextColumn get overSpending => text().withDefault(const Constant('Over'))();
  // OverSpending: 'Stop' | 'Over' — hành vi khi vượt ngân sách

  RealColumn get overAmount   => real().nullable()();
  // OverAmount: số tiền vượt ngân sách (nullable)

  // ── Threshold warning fields ─────────────────────────────────────────────
  RealColumn get thresholdWarningAmount  => real().nullable()();
  // Threshold_Warning_Amount: số tiền còn lại chạm ngưỡng cảnh báo

  /// Threshold_Warning_Percent: tỉ lệ đã tiêu chạm ngưỡng cảnh báo, đơn vị
  /// **phần trăm 0–100** (không phải 0.0–1.0) để khớp `Decimal(15,2)` bên
  /// backend. `BudgetEntity` quy về tỉ lệ khi so sánh.
  ///
  /// Thêm ở v11. Backend đã có cột này từ đợt DB v2 nhưng client thì chưa, nên
  /// mọi ngưỡng cảnh báo theo phần trăm người dùng đặt trên một máy đều không
  /// sang được máy khác.
  RealColumn get thresholdWarningPercent => real().nullable()();

  // ── Time fields ───────────────────────────────────────────────────────────
  DateTimeColumn get startDate  => dateTime()();
  DateTimeColumn get endDate    => dateTime().nullable()();

  // ── Recurrence (DB v2) ────────────────────────────────────────────────────
  BoolColumn get recurrence     => boolean().withDefault(const Constant(false))();
  // Recurrence: có lặp lại định kỳ không

  /// Time_recurrence: 'Week' | 'Month' | 'Quarter' | 'Year', hoặc **null**.
  ///
  /// null = ngân sách **không theo chu kỳ** nào: người dùng chọn "Ngày cụ thể"
  /// và tự đặt ngày kết thúc. Backend biểu diễn đúng như vậy — ràng buộc
  /// `chk_budget_time_recurrence` là `IS NULL OR IN (...)`.
  ///
  /// Thành nullable ở v12. Trước đó cột là `NOT NULL DEFAULT 'Month'` nên
  /// trạng thái "không chu kỳ" không lưu nổi ở client dù backend vẫn nhận.
  TextColumn get timeRecurrence => text().nullable()();

  // Đã bỏ ở v11: `period` ('weekly'/'monthly'/'yearly'). Đây là cột của lược
  // đồ trước DB v2, bị `time_recurrence` ('Week'/'Month'/'Quarter'/'Year') thay
  // thế hoàn toàn. Không nơi nào trong `lib/` đọc nó, và nó không nằm trong
  // payload đẩy — giữ lại chỉ khiến người viết mã sau phải đoán cột nào mới là
  // thật.

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

  /// generatedFromBillId: hoá đơn kỳ TRƯỚC, khi hàng này được sinh ra lúc trả
  /// hoá đơn ấy. NULL với mọi hoá đơn do người dùng tự tạo.
  ///
  /// ⚠️ **Cột CỤC BỘ — không nằm trong hợp đồng đồng bộ**, cùng lý do với
  /// `transactions.goalId`/`transactions.billId`.
  ///
  /// Vì sao cần: **hoàn tác thanh toán** phải gỡ luôn kỳ kế tiếp mà lần trả đã
  /// sinh ra, nếu không người dùng còn lại hai kỳ cùng mở và trả lại lần nữa
  /// sẽ đẻ thêm một kỳ trùng. Tìm kỳ ấy bằng cách so tên và ngày là quay lại
  /// đúng lối so bằng tên mà cột `goalId` sinh ra để thay thế.
  TextColumn get generatedFromBillId => text().nullable()();

  /// autoPayEnabled: app tự thanh toán hoá đơn này khi tới ngày đến hạn, trừ
  /// từ chính [walletId] của nó (DB v17, 2026-09-06).
  ///
  /// ⚠️ **Cột CỤC BỘ — không nằm trong hợp đồng đồng bộ**, cùng khuôn với
  /// `generatedFromBillId` và ba cột trích tự động của `Goals`. Hệ quả chấp
  /// nhận có chủ ý: cấu hình không theo người dùng sang máy khác — và đó cũng
  /// là lý do KHÔNG mượn một cột đang có: hai máy cùng bật, cùng offline, cùng
  /// trả một kỳ là hai khoản chi trừ hai ví, cờ đã trả đồng bộ theo LWW không
  /// chặn được. Xin cột phía backend ở việc D của
  /// `2026-09-06-bill-chuoi-ky-va-an-han.md`.
  ///
  /// Không có cột "lần chạy cuối" như mục tiêu: mỗi kỳ hoá đơn là **một hàng
  /// riêng**, nên cờ đã trả (`isPaid`/`payStatus`) chính là chốt chống trả hai
  /// lần. Kỳ kế tiếp kế thừa cờ này khi được sinh ra lúc trả kỳ trước.
  BoolColumn get autoPayEnabled => boolean().withDefault(const Constant(false))();

  /// anchorDay: **ngày trong tháng mà người dùng thật sự chọn** khi tạo hoá
  /// đơn — 1..31 (DB v18, 2026-09-08).
  ///
  /// Vì sao cần: chuỗi hoá đơn nối đuôi nhau (ngày bắt đầu kỳ sau = ngày đến
  /// hạn kỳ trước) nên số ngày gốc **biến mất** sau kỳ thứ hai. Nhìn vào một
  /// mốc 28/02 đơn độc thì không biết nó từ 31/01 kẹp xuống hay do người dùng
  /// tự chọn — hai ý định khác hẳn nhau, và bản trước phải **đoán** bằng "quy
  /// tắc ngày cuối tháng". Cú đoán ấy sai với người đăng ký lần đầu vào 28/02:
  /// họ muốn ngày 28 hàng tháng và nhận về 31/03. Người dùng báo 2026-09-08.
  ///
  /// Lưu ngày gốc là thay một phép đoán bằng một sự kiện. Xem
  /// `core/bill/bill_recurrence.dart`.
  ///
  /// ⚠️ **Cột CỤC BỘ — không nằm trong hợp đồng đồng bộ**, cùng khuôn với
  /// `autoPayEnabled` và `generatedFromBillId`. Hàng kéo từ server luôn để
  /// trống, và khi trống thì `nextBillDueDate` neo vào ngày của chính mốc hiện
  /// tại — tức chuỗi tạo trên máy khác vẫn có thể tụt dần. Tài liệu xin cột
  /// phía backend: `docs/superpowers/backend/CAN-LAM/BILL_ANCHOR_DAY.md`.
  ///
  /// NULL với mọi hoá đơn tạo trước v18; migration suy nó từ ngày đến hạn đang
  /// lưu để **không đổi hạn** của hoá đơn cũ.
  IntColumn get anchorDay => integer().nullable()();

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
  ///
  /// ⚠️ Cột này đồng bộ hai chiều nhưng **client chưa bao giờ ghi**. Bộ trích
  /// tự động cố ý KHÔNG dùng nó làm mốc chạy: nó là cột dùng chung với
  /// backend/Admin-web, và đổi ý nghĩa một cột dùng chung mà phía kia chưa
  /// đồng ý là cách hỏng im lặng nhất. Mốc chạy nằm ở [autoDepositLastRun].
  DateTimeColumn get timeCycleTakeMoney => dateTime().nullable()();

  // ── Trích tiền tự động (DB v15) ───────────────────────────────────────────
  //
  // ✅ Ba cột dưới đây ĐÃ ĐỒNG BỘ từ 2026-09-07, khi backend thêm
  // `auto_deposit_amount` / `auto_deposit_wallet_id` / `auto_deposit_last_run`
  // vào bảng `goal`. Trước đó chúng là cục bộ và G21 ghi lại hệ quả: bật trích
  // ở máy này thì máy kia không trích gì cả.
  //
  // ⚠️ **Ba cột phải đi cùng nhau trong payload.** `autoDepositLastRun` là cột
  // chặn trích hai lần; đẩy hai cột đầu mà bỏ nó thì mỗi máy giữ một mốc riêng
  // và **cả hai cùng chuyển tiền** khi tới kỳ — hỏng nặng hơn hẳn hiện trạng
  // cũ. `sync_payload_contract_test.dart` khoá đúng bộ khoá của payload mục
  // tiêu nên nó bắt được ngay nếu một cột rơi ra.
  //
  // Khe hở còn lại, chấp nhận được: hai máy cùng mở, cùng tới kỳ, cùng chưa kịp
  // kéo `last_run` của nhau thì vẫn trích hai lần. Vá triệt để cần một khoá
  // phía máy chủ trên `(Idgoal, kỳ trích)`.

  /// autoDepositAmount: số tiền trích mỗi kỳ. NULL = không bật trích tự động.
  RealColumn get autoDepositAmount => real().nullable()();

  /// autoDepositWalletId: ví NGUỒN của khoản trích. Ví nhận luôn là
  /// [walletId] của chính mục tiêu.
  ///
  /// Không khai khoá ngoại — cùng lý do với `walletTransfer` (bẫy 4.1) — nên
  /// nơi chạy phải tự kiểm ví còn tồn tại.
  TextColumn get autoDepositWalletId => text().nullable()();

  /// autoDepositLastRun: mốc của kỳ **gần nhất đã trích xong**.
  ///
  /// NULL nghĩa là chưa bật. Được đặt bằng "bây giờ" tại đúng lúc người dùng
  /// bật công tắc, nên kỳ đầu tiên rơi vào một chu kỳ sau đó. Lấy ngày tạo mục
  /// tiêu làm mốc thay thế là bật công tắc hôm nay rồi bị trích ngược lại sáu
  /// kỳ cùng một lúc.
  DateTimeColumn get autoDepositLastRun => dateTime().nullable()();

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
