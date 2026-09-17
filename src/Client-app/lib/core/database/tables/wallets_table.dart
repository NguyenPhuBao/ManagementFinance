import 'package:drift/drift.dart';

/// Bảng Ví (Wallet) — lưu local với sync status
///
/// Mỗi record có 3 cột bắt buộc cho offline-first sync:
/// - `id`: UUID tạo trên client
/// - `syncStatus`: 'pending' | 'synced' | 'conflict'
/// - `updatedAt`: timestamp để so sánh khi sync
class Wallets extends Table {
  // ── Primary key ──────────────────────────────────────────────────────────
  TextColumn get id => text()();

  // ── User ownership ────────────────────────────────────────────────────────
  /// idaccount từ backend — dùng để filter data của user hiện tại
  IntColumn get idaccount => integer()();

  // ── Business fields ──────────────────────────────────────────────────────
  TextColumn get name    => text()();
  TextColumn get type    => text().withDefault(const Constant('cash'))();
  // Kiểu ví — khoá của `WalletType`: 'cash' | 'bank' | 'saving' | 'banking'.
  // Ba loại đầu người dùng chọn được; 'banking' chỉ đến từ luồng liên kết ngân
  // hàng của server. PostgreSQL có `chk_wallet_type` chỉ nhận đúng bốn giá trị
  // ấy (viết hoa), nên giá trị lạ ở đây là bản ghi kẹt hàng đợi đẩy vĩnh viễn.

  RealColumn get balance  => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('VND'))();
  TextColumn get icon     => text().withDefault(const Constant('wallet'))();
  TextColumn get colour   => text().withDefault(const Constant('#4CAF50'))();
  BoolColumn get isDefault       => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted       => boolean().withDefault(const Constant(false))();
  /// Ví này được phép mang số dư **âm** — thẻ tín dụng, ví theo dõi nợ.
  ///
  /// Bật thì ví **không sinh cảnh báo số dư nào cả**: cả `walletNegative` lẫn
  /// `walletLowBalance`. Vế thứ hai dễ quên nhất và hỏng im lặng — một ví cho
  /// phép âm **luôn** nằm dưới mọi ngưỡng "sắp cạn", nên tắt mỗi cảnh báo âm
  /// là đổi một dòng nhiễu lấy một dòng nhiễu khác.
  ///
  /// ## Vì sao là một CỜ, không phải một loại ví
  ///
  /// Tới 2026-09-09 chỗ bám là `type == 'debt'`. Loại ấy **chết** cùng ngày:
  /// `debt` và `ewallet` vỡ `chk_wallet_type` của PostgreSQL và làm ví kẹt
  /// hàng đợi đẩy vĩnh viễn, nên `WalletType` thu về ba giá trị và ví cũ
  /// chuyển thành `bank`. Từ đó mọi ví âm bị nhắc mỗi ngày trở lại — **G27**.
  /// Khôi phục chuỗi `'debt'` là tái hiện đúng sự cố ấy; cờ riêng thì không
  /// đụng `chk_wallet_type` nào.
  ///
  /// ## ⚠️ CỘT CỤC BỘ — KHÔNG đi qua đồng bộ
  ///
  /// PostgreSQL **không có** cột tương ứng, nên cờ này **không** nằm trong
  /// payload đẩy (ví vẫn **13 trường**) và nhánh kéo về không đọc nó. Bật cờ
  /// trên máy A thì máy B không biết.
  ///
  /// Nói ra ở đây vì một bài học đã trả giá đúng trong bảng này: `status` từng
  /// là cột cục bộ và để lại **ba** chú thích ở ba tệp khác nói nó "đi ra máy
  /// khác qua `/sync/push`" (G28, mở lại 2026-09-14). Muốn mở đồng bộ thì cần
  /// một cột PostgreSQL mới và một tài liệu `docs/superpowers/backend/CAN-LAM/`
  /// — **không** tự thêm khoá vào payload.
  ///
  /// ## Vì sao KHÔNG có hàm thuần dùng chung
  ///
  /// Hai nơi đọc cờ này làm **hai việc khác nhau**: bộ luật thông báo bỏ qua
  /// hai loại cảnh báo, còn danh sách ví bỏ màu đỏ. Một vị từ chung sẽ phải
  /// mang hai nghĩa, nên ở đây cố ý đọc thẳng cột — khác `viTinhVaoTong`, nơi
  /// ba chỗ gọi hỏi đúng **một** câu.
  BoolColumn get allowNegative =>
      boolean().named('allow_negative').withDefault(const Constant(false))();

  /// Nếu true: số dư ví được cộng vào tổng tài sản trên dashboard
  BoolColumn get includeInTotal  => boolean().withDefault(const Constant(true))();
  
  TextColumn get bankCassoId => text().nullable()();
  TextColumn get status      => text().withDefault(const Constant('active'))();

  // ── Sync fields ──────────────────────────────────────────────────────────
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  // ── Trạng thái thất bại khi đẩy (G3) ──────────────────────────────────────
  // Cố ý KHÔNG đổi `syncStatus` sang 'failed' rồi loại bản ghi khỏi `getPending`:
  // nhiều lỗi hợp lệ chỉ tự khỏi SAU khi Pull xong (ví dụ giao dịch còn trỏ tới
  // ID danh mục mặc định cũ), nên loại vĩnh viễn sẽ giết luôn cơ chế thử lại đó.
  // Chặn theo THỜI GIAN: hết `syncBlockedUntil` là bản ghi tự quay lại hàng đợi.
  IntColumn      get syncRetryCount    => integer().withDefault(const Constant(0))();
  TextColumn     get syncError         => text().nullable()();
  DateTimeColumn get syncBlockedUntil  => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
