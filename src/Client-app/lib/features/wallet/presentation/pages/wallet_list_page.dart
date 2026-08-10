import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/wallet_cubit.dart';
import '../../data/models/wallet_entity.dart';

/// WalletListPage — hiển thị danh sách ví thực từ DB local.
///
/// Sử dụng BlocProvider để inject WalletCubit, load data ngay khi mount.
class WalletListPage extends StatelessWidget {
  const WalletListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy idaccount từ AuthBloc
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final idaccount = int.tryParse(user?.id ?? '') ?? 0;

    return BlocProvider<WalletCubit>(
      create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
      child: _WalletListView(idaccount: idaccount, user: user),
    );
  }
}

class _WalletListView extends StatelessWidget {
  final int idaccount;
  final UserModel? user;

  const _WalletListView({required this.idaccount, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Danh sách ví',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.outlineVariant, height: 1.0),
        ),
      ),
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.income,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            WalletLoading() => const Center(child: CircularProgressIndicator()),
            WalletError(:final message) => _ErrorView(
                message: message,
                onRetry: () => context.read<WalletCubit>().loadWallets(idaccount),
              ),
            WalletLoaded(:final wallets, :final totalBalance) ||
            WalletOperating(:final wallets, :final totalBalance) ||
            WalletOperationSuccess(:final wallets, :final totalBalance) =>
              _buildContent(context, wallets, totalBalance, state is WalletOperating),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WalletEntity> wallets,
    double totalBalance,
    bool isOperating,
  ) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(totalBalance),
                const SizedBox(height: 32),
                _buildWalletList(context, wallets),
                const SizedBox(height: 32),
                _buildBankIntegration(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (isOperating)
          Container(
            color: Colors.black.withValues(alpha: 0.15),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildOverviewCard(double totalBalance) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG SỐ DƯ',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance),
            style: TextStyle(
              fontSize: 36,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w600,
              color: totalBalance >= 0 ? AppColors.primary : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletList(BuildContext context, List<WalletEntity> wallets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'DANH SÁCH VÍ',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Danh sách ví từ DB
        ...wallets.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _WalletItem(
            wallet: w,
            onTap: () async {
              final result = await context.push('/wallets/${w.id}/edit');
              // Reload nếu có thay đổi
              if (result == true && context.mounted) {
                context.read<WalletCubit>().loadWallets(idaccount);
              }
            },
            onDelete: () => _confirmDelete(context, w),
          ),
        )),
        // Nút thêm ví
        InkWell(
          onTap: () async {
            final result = await context.push('/wallets/add');
            if (result == true && context.mounted) {
              context.read<WalletCubit>().loadWallets(idaccount);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'Thêm ví mới',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WalletEntity wallet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ví?'),
        content: Text('Bạn có chắc muốn xóa ví "${wallet.name}"?\n'
            'Các giao dịch sẽ vẫn được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<WalletCubit>().deleteWallet(
        walletId:   wallet.id,
        walletName: wallet.name,
        idaccount:  idaccount,
      );
    }
  }

  Widget _buildBankIntegration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'LIÊN KẾT NGÂN HÀNG',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/wallets/bank-link'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Liên kết ngân hàng',
                  style: TextStyle(fontSize: 16, color: AppColors.primary),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Wallet item card ──────────────────────────────────────────────────────────

class _WalletItem extends StatelessWidget {
  final WalletEntity wallet;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _WalletItem({
    required this.wallet,
    this.onTap,
    this.onDelete,
  });

  Color get _iconColor => _hexToColor(wallet.colour);
  Color get _iconBg    => _hexToColor(wallet.colour).withValues(alpha: 0.15);

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    return AppColors.primary;
  }

  IconData get _iconData => switch (wallet.type) {
    'bank'       => Icons.account_balance,
    'ewallet'    => Icons.account_balance_wallet,
    'investment' => Icons.trending_up,
    'debt'       => Icons.credit_card,
    _            => Icons.payments,
  };

  @override
  Widget build(BuildContext context) {
    final isNegative = wallet.balance < 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
              child: Icon(_iconData, color: _iconColor),
            ),
            const SizedBox(width: 16),
            // Name + Balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      if (wallet.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA4F1B2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'MẶC ĐỊNH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF24703E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(wallet.balance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isNegative ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                if (value == 'edit') onTap?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit',   child: Text('Chỉnh sửa')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa ví', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
