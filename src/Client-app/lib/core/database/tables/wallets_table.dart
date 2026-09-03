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
  // Kiểu ví: 'cash' | 'bank' | 'ewallet' | 'investment' | 'debt'

  RealColumn get balance  => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('VND'))();
  TextColumn get icon     => text().withDefault(const Constant('wallet'))();
  TextColumn get colour   => text().withDefault(const Constant('#4CAF50'))();
  BoolColumn get isDefault       => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted       => boolean().withDefault(const Constant(false))();
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
