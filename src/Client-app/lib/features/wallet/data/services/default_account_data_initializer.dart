import '../repositories/wallet_repository.dart';

/// Tạo dữ liệu ví tối thiểu cho một tài khoản chưa có đủ ví khởi tạo.
class DefaultAccountDataInitializer {
  final WalletRepository _walletRepository;

  DefaultAccountDataInitializer(this._walletRepository);

  Future<void> ensureForAccount(int idaccount) async {
    final wallets = await _walletRepository.getAll(idaccount);
    final hasSaving = wallets.any((wallet) => wallet.type == 'saving');
    final hasCash = wallets.any((wallet) => wallet.type == 'cash');
    if (!hasSaving) {
      await _walletRepository.addWallet(
        idaccount: idaccount,
        name: 'Tiết kiệm',
        type: 'saving',
        balance: 0,
        icon: 'savings',
        colour: '#4CAF50',
        isDefault: true,
      );
    }

    if (!hasCash) {
      await _walletRepository.addWallet(
        idaccount: idaccount,
        name: 'Tiền mặt',
        type: 'cash',
        balance: 0,
        icon: 'payments',
        colour: '#4CAF50',
      );
    }
  }
}
