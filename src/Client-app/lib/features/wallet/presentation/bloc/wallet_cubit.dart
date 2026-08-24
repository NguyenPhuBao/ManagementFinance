import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../data/repositories/wallet_repository.dart';

part 'wallet_state.dart';

/// WalletCubit — quản lý state cho tất cả màn hình Wallet.
///
/// Pattern: UI → WalletCubit → WalletRepository → WalletLocalDataSource → Drift
///
/// Sử dụng:
/// ```dart
/// context.read<WalletCubit>().loadWallets(idaccount);
/// BlocBuilder<WalletCubit, WalletState>(
///   builder: (ctx, state) => switch (state) {
///     WalletLoaded(:final wallets) => WalletListView(wallets: wallets),
///     WalletError(:final message)  => ErrorView(message),
///     _ => const LoadingSpinner(),
///   },
/// )
/// ```
class WalletCubit extends Cubit<WalletState> {
  final WalletRepository _repository;

  WalletCubit({required WalletRepository repository})
      : _repository = repository,
        super(const WalletInitial());

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Tải danh sách ví — gọi khi vào trang WalletList
  Future<void> loadWallets(int idaccount) async {
    emit(const WalletLoading());
    try {
      final wallets = await _repository.getAll(idaccount);
      final total   = await _repository.getTotalBalance(idaccount);
      emit(WalletLoaded(wallets: wallets, totalBalance: total));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  /// Thêm ví mới — ghi local ngay, trigger sync nền
  Future<void> addWallet({
    required int idaccount,
    required String name,
    required String type,
    required double balance,
    String icon   = 'wallet',
    String colour = '#4CAF50',
    bool isDefault = false,
    bool includeInTotal = true,
  }) async {
    final currentState = state;
    final currentWallets = switch (currentState) {
      WalletLoaded(:final wallets)   => wallets,
      WalletOperating(:final wallets) => wallets,
      _ => <WalletEntity>[],
    };
    final currentTotal = switch (currentState) {
      WalletLoaded(:final totalBalance)    => totalBalance,
      WalletOperating(:final totalBalance) => totalBalance,
      _ => 0.0,
    };

    emit(WalletOperating(wallets: currentWallets, totalBalance: currentTotal));

    try {
      final wallet = await _repository.addWallet(
        idaccount: idaccount,
        name:      name,
        type:      type,
        balance:   balance,
        icon:      icon,
        colour:    colour,
        isDefault: isDefault,
        includeInTotal: includeInTotal,
      );

      final updated = [...currentWallets, wallet];
      final newTotal = updated.fold(0.0, (s, w) => s + w.balance);

      emit(WalletOperationSuccess(
        wallets:      updated,
        totalBalance: newTotal,
        message:      'Đã thêm ví "$name" thành công!',
      ));

      // Reload để chắc chắn sắp xếp đúng
      await loadWallets(idaccount);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Cập nhật ví
  Future<void> updateWallet({
    required WalletEntity wallet,
    required int idaccount,
  }) async {
    final currentState = state;
    final currentWallets = switch (currentState) {
      WalletLoaded(:final wallets) => wallets,
      _                            => <WalletEntity>[],
    };
    final currentTotal = switch (currentState) {
      WalletLoaded(:final totalBalance) => totalBalance,
      _                                 => 0.0,
    };

    emit(WalletOperating(wallets: currentWallets, totalBalance: currentTotal));

    try {
      await _repository.updateWallet(wallet);
      emit(WalletOperationSuccess(
        wallets:      currentWallets,
        totalBalance: currentTotal,
        message:      'Đã cập nhật ví "${wallet.name}"!',
      ));
      await loadWallets(idaccount);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Xoá mềm ví
  Future<void> deleteWallet({
    required String walletId,
    required String walletName,
    required int idaccount,
  }) async {
    final currentState = state;
    final currentWallets = switch (currentState) {
      WalletLoaded(:final wallets) => wallets,
      _                            => <WalletEntity>[],
    };
    final currentTotal = switch (currentState) {
      WalletLoaded(:final totalBalance) => totalBalance,
      _                                 => 0.0,
    };

    emit(WalletOperating(wallets: currentWallets, totalBalance: currentTotal));

    try {
      await _repository.deleteWallet(walletId);
      emit(WalletOperationSuccess(
        wallets:      currentWallets.where((w) => w.id != walletId).toList(),
        totalBalance: currentTotal,
        message:      'Đã xóa ví "$walletName".',
      ));
      await loadWallets(idaccount);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }
}
