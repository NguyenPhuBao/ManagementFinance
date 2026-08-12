import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import '../widgets/wallet_selection_bottom_sheet.dart';

class BillPage extends StatefulWidget {
  const BillPage({super.key});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  int _getAccountId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess && authState.user != null) {
      return int.tryParse(authState.user!.id) ?? 1;
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountId = _getAccountId(context);
      context.read<BillBloc>().add(LoadBillsEvent(idaccount: accountId));
    });
  }

  void _showPayModal(BuildContext context, Bill bill) async {
    final db = sl<AppDatabase>();
    final accountId = _getAccountId(context);
    var wallets = await db.walletDao.getAll(accountId);
    if (wallets.isEmpty) {
      wallets = await db.walletDao.getAllNonDeleted();
    }

    if (!context.mounted) return;

    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ít nhất 1 ví trước khi thanh toán.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletSelectionBottomSheet(
        wallets: wallets,
        onSelected: (wallet) {
          context.read<BillBloc>().add(
                PayBillEvent(
                  bill: bill,
                  walletId: wallet.id,
                  idaccount: accountId,
                ),
              );
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String billId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hóa đơn'),
        content: const Text('Bạn có chắc chắn muốn xóa hóa đơn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BillBloc>().add(DeleteBillEvent(id: billId));
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hóa đơn & Dịch vụ',
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
          child: Container(
            color: AppColors.outlineVariant,
            height: 1.0,
          ),
        ),
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state is BillOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is BillError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is BillLoading || state is BillInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BillLoaded) {
            final bills = state.bills;

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                  children: [
                    _buildSummaryCard(
                      totalAmountStr: currencyFormatter.format(state.totalUnpaidAmount),
                      unpaidCount: state.unpaidCount,
                    ),
                    const SizedBox(height: 16),
                    if (bills.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Chưa có hóa đơn nào được tạo.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...bills.map((bill) {
                        final isPaid = bill.isPaid == true;
                        final isOverdue = !isPaid && bill.dueDate.isBefore(DateTime.now());

                        String statusText = isPaid
                            ? 'ĐÃ THANH TOÁN'
                            : (isOverdue ? 'SẮP ĐẾN HẠN' : 'CHƯA THANH TOÁN');
                        Color statusColor = isPaid
                            ? const Color(0xFF217128)
                            : (isOverdue ? const Color(0xFF93000A) : AppColors.textSecondary);
                        Color statusBg = isPaid
                            ? const Color(0xFFA0F399)
                            : (isOverdue ? const Color(0xFFFFDAD6) : AppColors.surfaceContainerHigh);
                        Color accentColor = isPaid
                            ? AppColors.outlineVariant
                            : (isOverdue ? AppColors.income : AppColors.primary);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildBillItem(
                            context: context,
                            bill: bill,
                            title: bill.name,
                            subtitle: 'Hạn ${dateFormatter.format(bill.dueDate)}',
                            amount: currencyFormatter.format(bill.amount),
                            status: statusText,
                            statusColor: statusColor,
                            statusBg: statusBg,
                            accentColor: accentColor,
                            isPaid: isPaid,
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                    _buildDecorativeIllustration(),
                  ],
                ),
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: _buildAddButton(context),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String totalAmountStr,
    required int unpaidCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0DB)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.account_balance_wallet, size: 64, color: AppColors.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng tiền cần thanh toán',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalAmountStr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: unpaidCount > 0 ? 0.66 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$unpaidCount hóa đơn chưa thanh toán',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillItem({
    required BuildContext context,
    required Bill bill,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required Color accentColor,
    bool isPaid = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPaid ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPaid
            ? Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid)
            : Border.all(color: const Color(0xFFE0E0DB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isPaid ? AppColors.textSecondary : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (isPaid) ...[
                                Icon(Icons.check_circle, color: statusColor, size: 14),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          amount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => context.push('/bills/${bill.id}/edit', extra: bill),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: isPaid
                                ? AppColors.textSecondary.withValues(alpha: 0.5)
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _showDeleteConfirm(context, bill.id),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: isPaid
                                ? const Color(0xFFF1453B).withValues(alpha: 0.5)
                                : const Color(0xFFF1453B),
                          ),
                        ),
                        const Spacer(),
                        if (!isPaid)
                          ElevatedButton(
                            onPressed: () => _showPayModal(context, bill),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Thanh toán',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeIllustration() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: const Center(
            child: Icon(Icons.receipt_long, size: 64, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Mọi thứ đều trong tầm kiểm soát.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => context.push('/bills/add'),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Tạo hóa đơn lặp lại mới',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A19),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
}
