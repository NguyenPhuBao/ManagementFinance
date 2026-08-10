part of 'wallet_cubit.dart';

/// Trạng thái của trang Wallet
sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

/// Trạng thái ban đầu — chưa load
class WalletInitial extends WalletState {
  const WalletInitial();
}

/// Đang tải dữ liệu
class WalletLoading extends WalletState {
  const WalletLoading();
}

/// Đã tải xong — hiển thị danh sách
class WalletLoaded extends WalletState {
  final List<WalletEntity> wallets;
  final double totalBalance;

  const WalletLoaded({
    required this.wallets,
    required this.totalBalance,
  });

  @override
  List<Object?> get props => [wallets, totalBalance];
}

/// Lỗi khi tải
class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Đang thực hiện thao tác (thêm/sửa/xoá) — dùng để show loading indicator
class WalletOperating extends WalletState {
  final List<WalletEntity> wallets; // giữ danh sách cũ để UI không bị trắng
  final double totalBalance;

  const WalletOperating({
    required this.wallets,
    required this.totalBalance,
  });

  @override
  List<Object?> get props => [wallets, totalBalance];
}

/// Thao tác thành công (thêm/sửa/xoá)
class WalletOperationSuccess extends WalletState {
  final List<WalletEntity> wallets;
  final double totalBalance;
  final String message;

  const WalletOperationSuccess({
    required this.wallets,
    required this.totalBalance,
    required this.message,
  });

  @override
  List<Object?> get props => [wallets, totalBalance, message];
}
