import '../models/transaction_entity.dart';

abstract class TransactionRepository {
  /// Giao dịch trong khoảng `[from, to)`. Biên `to` **mở** — xem
  /// `TransactionDao.watchKhoang`.
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  );

  /// Danh sách Sổ giao dịch: khoản riêng + khoản của nhà TÔI ghi trong `[from, to)` (spec 2026-11-16). CHỈ cho danh sách —
  /// tổng đi `summarizeTransactions` (bỏ hàng có `idhousehold`); thống kê đọc [watchKhoang].
  Stream<List<TransactionEntity>> watchKhoangKemNha(int idaccount, DateTime from, DateTime to);

  /// Danh sách "Giao dịch gần đây" ở Trang chủ — như [watchKhoangKemNha] trên cả sổ.
  Stream<List<TransactionEntity>> watchAllKemNha(int idaccount);

  /// Mọi giao dịch của tài khoản (bỏ hàng `deletedAt`, mới nhất trước) — cho Thêm giao dịch (nhắc trùng, ví hay dùng)
  /// và Trang chủ.
  Future<List<TransactionEntity>> getAll(int idaccount);

  /// Như [getAll], dạng stream — Trang chủ và thẻ "chưa có danh mục" của Sổ giao dịch.
  Stream<List<TransactionEntity>> watchAll(int idaccount);

  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });

  /// A5 mục 11.4 — một khoản chi đã TÁCH theo danh mục: ghi cả N giao dịch hoặc không giao dịch nào (một giao tác),
  /// số dư tính lại một lần. Chỉ cho khoản thu / chi (không chuyển ví).
  Future<void> addTransactions(List<TransactionEntity> transactions);

  /// Sửa một giao dịch đã lưu: hoàn hệ quả của [before] lên ví, áp hệ quả của
  /// [after], ghi [after] đè lên hàng cũ (cùng `id`) và đánh dấu đẩy lại.
  Future<void> updateTransaction(
    TransactionEntity before,
    TransactionEntity after,
  );
}
