import '../../../../core/database/daos/wallet_dao.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../wallet/data/services/so_du_vi_service.dart';
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

  /// Nơi duy nhất ghi số dư. Xem `SoDuViService`.
  final SoDuViService soDuVi;

  TransactionRepositoryImpl({
    required this.localDataSource,
    required this.walletDao,
    required this.syncEngine,
    required this.soDuVi,
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
    // ⚠️ Ví đích phải được GHI VÀO HÀNG, không chỉ truyền qua tham số.
    //
    // Bản cũ cộng dồn số dư nên `destinationWalletId` truyền riêng là đủ: nó
    // trừ/cộng ngay rồi quên. Nay số dư **suy từ sổ**, nên thứ gì không nằm
    // trong hàng thì không tồn tại — một khoản chuyển thiếu `walletTransfer`
    // trở thành "chuyển đi đâu không rõ" và không ví nào đổi. Ghi vào hàng cũng
    // là điều đúng sẵn: đó là chỗ DUY NHẤT lưu tiền đã đi đâu, và máy khác chỉ
    // biết được qua nó.
    final banGhi = transaction.walletTransfer == null &&
            destinationWalletId != null &&
            transaction.type == 'transfer'
        ? transaction.copyWith(walletTransfer: destinationWalletId)
        : transaction;

    final vi = _viBiAnhHuong(banGhi, destinationWalletId: destinationWalletId);
    // ⚠️ Đặt neo TRƯỚC khi ghi sổ — xem `SoDuViService.datNeoNhieuVi`: neo được
    // tính bằng `balance − Σ sổ`, nên đặt sau là nó hấp thụ luôn giao dịch vừa
    // ghi và số dư đứng im.
    await soDuVi.datNeoNhieuVi(vi);
    await localDataSource.addTransaction(banGhi);
    await soDuVi.tinhLaiNhieuVi(vi);
    syncEngine.scheduleSync();
  }

  @override
  Future<void> deleteTransaction(
    TransactionEntity transaction, {
    String? destinationWalletId,
  }) async {
    final vi = _viBiAnhHuong(transaction, destinationWalletId: destinationWalletId);
    await soDuVi.datNeoNhieuVi(vi);
    await localDataSource.deleteTransaction(transaction.id);
    await soDuVi.tinhLaiNhieuVi(vi);
    syncEngine.scheduleSync();
  }

  @override
  Future<void> updateTransaction(
    TransactionEntity before,
    TransactionEntity after,
  ) async {
    // ⚠️ Ghi sổ TRƯỚC rồi mới tính lại số dư. Bản cũ áp hệ quả lên ví trước
    // rồi mới ghi hàng, vì khi ấy số dư là phép cộng dồn nên thứ tự không quan
    // trọng. Nay số dư **suy từ sổ**: tính lại khi hàng cũ còn nguyên là đọc
    // đúng trạng thái trước khi sửa, tức không có gì đổi cả.
    final vi = <String>{..._viBiAnhHuong(before), ..._viBiAnhHuong(after)};
    await soDuVi.datNeoNhieuVi(vi);
    await localDataSource.updateTransaction(after.copyWith(
      // Phía server so `update_at` (LWW): giữ mốc cũ là bản sửa bị bỏ qua.
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    ));
    // Hợp hai tập: đổi ví hay đổi ví đích thì ví CŨ cũng phải được tính lại,
    // nếu không nó giữ mãi phần tiền của một giao dịch không còn thuộc về nó.
    await soDuVi.tinhLaiNhieuVi(vi);
    syncEngine.scheduleSync();
  }

  /// Những ví mà [t] chạm tới — để biết **ví nào cần tính lại** sau khi sổ đổi.
  ///
  /// Đây là phần còn lại của `_applyBalances` cũ. Phép cộng trừ đã chuyển sang
  /// `TransactionDao.tongTheoVi`; ở đây chỉ còn câu hỏi *ví nào bị chạm*.
  ///
  /// Giữ **nguyên văn** ngoại lệ của bản cũ: khoản `transfer` không có ví đích
  /// thì **không** chạm ví nào — *"đừng trừ một nửa"*. Ví đích nằm trên chính
  /// entity (`walletTransfer`); [destinationWalletId] chỉ còn là đường cũ cho
  /// nơi gọi chưa điền cột đó.
  Set<String> _viBiAnhHuong(
    TransactionEntity t, {
    String? destinationWalletId,
  }) {
    switch (t.type) {
      case 'chi':
      case 'thu':
        return {t.walletId};
      case 'transfer':
        final destination = t.walletTransfer ?? destinationWalletId;
        if (destination == null) return const {};
        return {t.walletId, destination};
    }
    return const {};
  }
}
