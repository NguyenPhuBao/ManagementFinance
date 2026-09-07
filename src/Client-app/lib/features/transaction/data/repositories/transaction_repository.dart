import '../../../../core/database/daos/wallet_dao.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_entity.dart';

abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  );
  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  });

  /// Sửa một giao dịch đã lưu: hoàn hệ quả của [before] lên ví, áp hệ quả của
  /// [after], ghi [after] đè lên hàng cũ (cùng `id`) và đánh dấu đẩy lại.
  Future<void> updateTransaction(
    TransactionEntity before,
    TransactionEntity after,
  );
}

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource localDataSource;
  final WalletDao walletDao;
  final SyncEngine syncEngine;

  TransactionRepositoryImpl({
    required this.localDataSource,
    required this.walletDao,
    required this.syncEngine,
  });

  @override
  Stream<List<TransactionEntity>> watchTransactionsByMonth(
    int idaccount,
    int year,
    int month,
  ) {
    return localDataSource.watchTransactionsByMonth(idaccount, year, month);
  }

  @override
  Future<void> addTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    await localDataSource.addTransaction(transaction);
    await _applyBalances(transaction, destinationWalletId: destinationWalletId);
    syncEngine.scheduleSync();
  }

  @override
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    await localDataSource.deleteTransaction(transaction.id);
    await _applyBalances(
      transaction,
      sign: -1,
      destinationWalletId: destinationWalletId,
    );
    syncEngine.scheduleSync();
  }

  @override
  Future<void> updateTransaction(
    TransactionEntity before,
    TransactionEntity after,
  ) async {
    // Hoàn trọn hệ quả cũ rồi áp trọn hệ quả mới, thay vì tính phần chênh:
    // đổi ví, đổi chiều, đổi ví đích đều rơi vào cùng một đường, không có
    // nhánh riêng nào để quên.
    await _applyBalances(before, sign: -1);
    await _applyBalances(after);
    await localDataSource.updateTransaction(after.copyWith(
      // Phía server so `update_at` (LWW): giữ mốc cũ là bản sửa bị bỏ qua.
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    ));
    syncEngine.scheduleSync();
  }

  Future<void> _adjust(String walletId, double delta) async {
    final w = await walletDao.getById(walletId);
    if (w != null) await walletDao.updateBalance(w.id, w.balance + delta);
  }

  /// Áp hệ quả của [t] lên số dư ví; [sign] = -1 để hoàn lại y hệt.
  ///
  /// Ví đích nằm trên chính entity (`walletTransfer`); [destinationWalletId]
  /// chỉ còn là đường cũ cho nơi gọi chưa điền cột đó. Khoản chuyển không có
  /// ví đích thì KHÔNG động vào ví nào — giữ hành vi cũ, đừng trừ một nửa.
  Future<void> _applyBalances(
    TransactionEntity t, {
    int sign = 1,
    String? destinationWalletId,
  }) async {
    final amount = t.amount * sign;
    switch (t.type) {
      case 'chi':
        await _adjust(t.walletId, -amount);
      case 'thu':
        await _adjust(t.walletId, amount);
      case 'transfer':
        final destination = t.walletTransfer ?? destinationWalletId;
        if (destination == null) return;
        await _adjust(t.walletId, -amount);
        await _adjust(destination, amount);
    }
  }
}
