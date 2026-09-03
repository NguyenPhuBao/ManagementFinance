import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';
import '../bloc/budget_cubit.dart';
import '../widgets/budget_visuals.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `null` khi chưa có phiên đăng nhập dùng được. Cubit sẽ báo lỗi thay vì
    // đoán một mã tài khoản — xem `core/auth/current_account.dart`.
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<BudgetCubit>(
      create: (_) => sl<BudgetCubit>()..watchBudgets(idaccount),
      child: const _BudgetPageContent(),
    );
  }
}

class _BudgetPageContent extends StatelessWidget {
  const _BudgetPageContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<BudgetCubit, BudgetState>(
          // Sau khi tạo/sửa/xoá, cubit phát `BudgetSaved` rồi stream tự đẩy
          // danh sách mới về — chỉ cần hiện lời nhắn, không cần nạp lại tay.
          listenWhen: (_, s) => s is BudgetSaved || s is BudgetError,
          listener: (context, state) {
            final message = switch (state) {
              BudgetSaved(:final message) => message,
              BudgetError(:final message) => message,
              _ => null,
            };
            if (message == null) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(message),
                backgroundColor:
                    state is BudgetError ? AppColors.error : AppColors.primary,
              ));
          },
          buildWhen: (_, s) =>
              s is BudgetLoaded || s is BudgetLoading || s is BudgetError,
          builder: (context, state) => switch (state) {
            BudgetLoaded(isEmpty: true) => const _EmptyView(),
            BudgetLoaded() => _LoadedView(state: state),
            BudgetError(:final message) => _ErrorView(message: message),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

// ─── Các trạng thái ──────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings_outlined,
                size: 64, color: AppColors.outline),
            const SizedBox(height: 16),
            const Text(
              'Chưa có ngân sách nào',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đặt hạn mức cho một danh mục để biết mình còn tiêu được bao '
              'nhiêu trong tháng.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _CreateButton(onPressed: () => _openEditor(context)),
          ],
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final BudgetLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewCard(state: state),
          const SizedBox(height: 24),
          const Text(
            'Danh mục chi tiêu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...state.budgets.map((v) => _BudgetItem(view: v)),
          const SizedBox(height: 24),
          _CreateButton(onPressed: () => _openEditor(context)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Các mảnh giao diện ──────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final BudgetLoaded state;
  const _OverviewCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final vuot = state.totalRemaining < 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vuot ? 'ĐÃ TIÊU VƯỢT' : 'CÒN LẠI',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(state.totalRemaining.abs()),
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.bold,
                      color: vuot ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (vuot ? AppColors.error : AppColors.income)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: vuot ? AppColors.error : AppColors.income,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(state.percentSpent * 100).round()}% ngân sách đã dùng',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  '${CurrencyFormatter.format(state.totalSpent)} / '
                  '${CurrencyFormatter.format(state.totalAmount)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(
            percent: state.percentSpent,
            color: vuot ? AppColors.error : AppColors.income,
          ),
        ],
      ),
    );
  }
}

class _BudgetItem extends StatelessWidget {
  final BudgetView view;
  const _BudgetItem({required this.view});

  @override
  Widget build(BuildContext context) {
    final b = view.budget;
    final canhBao = b.isOverBudget || b.isNearLimit;
    final mauCanhBao = b.isOverBudget ? AppColors.error : AppColors.expense;

    return Dismissible(
      key: ValueKey(b.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, view),
      onDismissed: (_) => context.read<BudgetCubit>().deleteBudget(b.id),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEditor(context, id: b.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            budgetIconFor(view.categoryIcon),
                            color: budgetColorFrom(view.categoryColour),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _subtitle(b),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: canhBao
                                      ? mauCanhBao
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(b.spent),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              canhBao ? mauCanhBao : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '/ ${CurrencyFormatter.format(b.amount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressBar(
                percent: b.percentSpent,
                color: canhBao ? mauCanhBao : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(BudgetEntity b) {
    if (b.isOverBudget) {
      return 'Vượt ${CurrencyFormatter.format(b.overAmount)}';
    }
    if (b.isNearLimit) {
      return 'Sắp hết — còn ${CurrencyFormatter.format(b.remaining)}';
    }
    return 'Còn ${CurrencyFormatter.format(b.remaining)}';
  }
}

class _ProgressBar extends StatelessWidget {
  final double percent;
  final Color color;
  const _ProgressBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        // `percentSpent` đã cắt trần ở 1.0 phía entity — thanh không tràn khung.
        widthFactor: percent.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CreateButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 24),
          SizedBox(width: 8),
          Text(
            'Tạo ngân sách mới',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Dùng chung ──────────────────────────────────────────────────────────────

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

void _openEditor(BuildContext context, {String? id}) {
  context.push(id == null ? '/budget/rules' : '/budget/rules?id=$id');
}

Future<bool> _confirmDelete(BuildContext context, BudgetView view) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xoá ngân sách?'),
      content: Text(
        'Hạn mức cho "${view.displayName}" sẽ không còn được theo dõi. '
        'Các giao dịch đã ghi không bị ảnh hưởng.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
