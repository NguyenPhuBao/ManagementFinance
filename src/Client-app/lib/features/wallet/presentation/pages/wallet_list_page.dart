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

/// WalletListPage — hiển thị danh sách ví thực từ DB local chuẩn thiết kế Stitch UI.
class WalletListPage extends StatelessWidget {
  const WalletListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final idaccount = int.tryParse(user?.id ?? '') ?? 0;

    return BlocProvider<WalletCubit>(
      create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
      child: _WalletListView(idaccount: idaccount, user: user),
    );
  }
}

class _WalletListView extends StatefulWidget {
  final int idaccount;
  final UserModel? user;

  const _WalletListView({required this.idaccount, required this.user});

  @override
  State<_WalletListView> createState() => _WalletListViewState();
}

class _WalletListViewState extends State<_WalletListView> {
  final Map<String, bool> _walletSwitches = {};

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
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
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
                onRetry: () => context.read<WalletCubit>().loadWallets(widget.idaccount),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(totalBalance),
                const SizedBox(height: 24),
                _buildWalletListHeader(context),
                const SizedBox(height: 12),
                _buildWalletList(context, wallets),
                const SizedBox(height: 24),
                _buildBankIntegrationSection(context),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG TÀI SẢN',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletListHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'DANH SÁCH VÍ',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () {
            // Action sắp xếp ví
          },
          child: const Text(
            'SẮP XẾP',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletList(BuildContext context, List<WalletEntity> wallets) {
    return Column(
      children: [
        ...wallets.map((w) {
          final isSwitched = _walletSwitches[w.id] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WalletItem(
              wallet: w,
              isSwitched: isSwitched,
              onToggleSwitch: (val) {
                setState(() {
                  _walletSwitches[w.id] = val;
                });
              },
              onTap: () async {
                final result = await context.push('/wallets/${w.id}/edit');
                if (result == true && context.mounted) {
                  context.read<WalletCubit>().loadWallets(widget.idaccount);
                }
              },
              onDelete: () => _confirmDelete(context, w),
            ),
          );
        }),
        _buildAddWalletButton(context),
      ],
    );
  }

  Widget _buildAddWalletButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await context.push('/wallets/add');
        if (result == true && context.mounted) {
          context.read<WalletCubit>().loadWallets(widget.idaccount);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Thêm ví mới',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
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
        walletId: wallet.id,
        walletName: wallet.name,
        idaccount: widget.idaccount,
      );
    }
  }

  Widget _buildBankIntegrationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIÊN KẾT NGÂN HÀNG',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/wallets/bank-link'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Liên kết tài khoản ngân hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletItem extends StatelessWidget {
  final WalletEntity wallet;
  final bool isSwitched;
  final ValueChanged<bool>? onToggleSwitch;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _WalletItem({
    required this.wallet,
    required this.isSwitched,
    this.onToggleSwitch,
    this.onTap,
    this.onDelete,
  });

  Color get _iconColor {
    if (wallet.type == 'debt' || wallet.balance < 0) {
      return const Color(0xFFD32F2F);
    }
    if (wallet.isDefault || wallet.type == 'cash') {
      return const Color(0xFF2E7D32);
    }
    return AppColors.primary;
  }

  Color get _iconBg {
    if (wallet.type == 'debt' || wallet.balance < 0) {
      return const Color(0xFFFFEBEE);
    }
    if (wallet.isDefault || wallet.type == 'cash') {
      return const Color(0xFFC8E6C9);
    }
    return AppColors.surfaceContainerHigh;
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
    final bool useSwitch = wallet.type == 'bank';

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
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Title + Badge + Balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (wallet.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8E6C9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'MẶC ĐỊNH',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isNegative ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Trailing action
            if (useSwitch)
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isSwitched,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.secondary,
                  onChanged: onToggleSwitch,
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                onSelected: (value) {
                  if (value == 'edit') onTap?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
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
