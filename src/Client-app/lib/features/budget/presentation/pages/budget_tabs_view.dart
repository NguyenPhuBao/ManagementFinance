import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';
import '../bloc/budget_state.dart';
import '../widgets/budget_visuals.dart';

/// Phần hiển thị của trang ngân sách: hai tab, thẻ tổng quan, danh sách.
///
/// Cố ý **không** đọc `BudgetCubit`: mọi thao tác đi ra ngoài qua callback. Nhờ
/// vậy ràng buộc quan trọng nhất của trang — tab "Đã hết hạn" không sửa, không
/// xoá — kiểm được bằng widget test thuần, không phải dựng cả DI và router.
class BudgetTabsView extends StatelessWidget {
  final BudgetLoaded state;
  final VoidCallback onCreate;
  final void Function(BudgetView) onEdit;

  /// Trả về true nếu người dùng xác nhận xoá.
  final Future<bool> Function(BudgetView) onDelete;
  final void Function(BudgetView) onShowDetail;

  /// Link "CHI TIẾT" trong bản dựng hình trỏ sang trang Phân tích. Bỏ trống thì
  /// link không hiện — thà thiếu còn hơn có một link không đi đâu cả.
  final VoidCallback? onOpenAnalytics;

  const BudgetTabsView({
    super.key,
    required this.state,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onShowDetail,
    this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Ngân sách',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Đang hoạt động (${state.active.length})'),
              Tab(text: 'Đã hết hạn (${state.expired.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _ActiveTab(
                state: state,
                onCreate: onCreate,
                onEdit: onEdit,
                onDelete: onDelete,
                onShowDetail: onShowDetail,
                onOpenAnalytics: onOpenAnalytics,
              ),
              _ExpiredTab(
                budgets: state.expired,
                onShowDetail: onShowDetail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab đang hoạt động ──────────────────────────────────────────────────────

class _ActiveTab extends StatelessWidget {
  final BudgetLoaded state;
  final VoidCallback onCreate;
  final void Function(BudgetView) onEdit;
  final Future<bool> Function(BudgetView) onDelete;
  final void Function(BudgetView) onShowDetail;
  final VoidCallback? onOpenAnalytics;

  const _ActiveTab({
    required this.state,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onShowDetail,
    this.onOpenAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewCard(state: state),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh mục chi tiêu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (onOpenAnalytics != null)
                TextButton(
                  onPressed: onOpenAnalytics,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'CHI TIẾT',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.active.isEmpty)
            const _InlineEmpty(
              message: 'Chưa có ngân sách nào đang chạy. Đặt hạn mức cho một '
                  'danh mục để biết mình còn tiêu được bao nhiêu.',
            )
          else
            ...state.active.map((v) => _BudgetCard(
                  view: v,
                  onEdit: () => onEdit(v),
                  onDelete: () => onDelete(v),
                  onTap: () => onShowDetail(v),
                )),
          const SizedBox(height: 24),
          _CreateButton(onPressed: onCreate),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Tab đã hết hạn ──────────────────────────────────────────────────────────

class _ExpiredTab extends StatelessWidget {
  final List<BudgetView> budgets;
  final void Function(BudgetView) onShowDetail;

  const _ExpiredTab({required this.budgets, required this.onShowDetail});

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: _InlineEmpty(
          message: 'Chưa có ngân sách nào hết hạn. Ngân sách chỉ vào đây khi '
              'bạn tắt lặp lại hoặc đặt ngày kết thúc cho nó.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReadOnlyNotice(),
          const SizedBox(height: 16),
          // Không Dismissible, không nút chỉnh: hai thao tác này bị khoá ở đây
          // và widget test canh đúng chuyện đó.
          ...budgets.map((v) => _BudgetCard(
                view: v,
                onTap: () => onShowDetail(v),
                expired: true,
              )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ngân sách đã hết hạn chỉ xem được, không sửa hay xoá.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thẻ tổng quan ───────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final BudgetLoaded state;
  const _OverviewCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final vuot = state.totalRemaining < 0;
    final mau = vuot ? AppColors.error : AppColors.income;
    // Bản dựng hình ghi "% ngân sách CÒN LẠI", không phải "đã dùng".
    final conLai = ((1 - state.percentSpent) * 100).round().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vuot ? 'ĐÃ TIÊU VƯỢT THÁNG NÀY' : 'CÒN LẠI THÁNG NÀY',
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(state.totalRemaining.abs()),
                        style: TextStyle(
                          fontSize: 36,
                          height: 1.2,
                          letterSpacing: -1,
                          fontWeight: FontWeight.bold,
                          color: vuot ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_balance_wallet, color: mau, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$conLai% ngân sách còn lại',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  '${CurrencyFormatter.format(state.totalSpent)} / '
                  '${CurrencyFormatter.format(state.totalAmount)} đã dùng',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BudgetProgressBar(percent: state.percentSpent, color: mau),
        ],
      ),
    );
  }
}

// ─── Thẻ một ngân sách ───────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetView view;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final Future<bool> Function()? onDelete;
  final bool expired;

  const _BudgetCard({
    required this.view,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.expired = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = _body(context);
    final remove = onDelete;
    if (expired || remove == null) return card;

    return Dismissible(
      key: ValueKey('budget-dismiss-${view.budget.id}'),
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
      confirmDismiss: (_) => remove(),
      child: card,
    );
  }

  Widget _body(BuildContext context) {
    final b = view.budget;
    // Tab hết hạn đã chốt sổ nên chỉ còn hai kết cục — dư (xanh lá) hoặc vượt
    // (đỏ tươi). Thang bốn màu là để cảnh báo trong lúc còn tiêu được.
    final mau = expired
        ? (b.isOverBudget ? AppColors.expense : AppColors.income)
        : budgetHealthColour(budgetHealthOf(b));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
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
                        style: TextStyle(fontSize: 14, color: mau),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: IconButton(
                          key: ValueKey('budget-edit-${b.id}'),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          tooltip: 'Chỉnh ngân sách',
                          icon: const Icon(Icons.tune,
                              color: AppColors.textSecondary),
                          onPressed: onEdit,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(b.spent),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mau,
                      ),
                    ),
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
            BudgetProgressBar(percent: b.percentSpent, color: mau),
          ],
        ),
      ),
    );
  }

  String _subtitle(BudgetEntity b) {
    if (expired) {
      return b.isOverBudget
          ? 'Vượt ${CurrencyFormatter.format(b.overAmount)}'
          : 'Còn dư ${CurrencyFormatter.format(b.remaining)}';
    }
    if (b.isOverBudget) {
      return 'Vượt ${CurrencyFormatter.format(b.overAmount)}';
    }
    if (b.isNearLimit) {
      return 'Sắp hết — còn ${CurrencyFormatter.format(b.remaining)}';
    }
    return 'Còn ${CurrencyFormatter.format(b.remaining)}';
  }
}

// ─── Mảnh dùng chung ─────────────────────────────────────────────────────────

class BudgetProgressBar extends StatelessWidget {
  final double percent;
  final Color color;

  const BudgetProgressBar({
    super.key,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
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

class _InlineEmpty extends StatelessWidget {
  final String message;
  const _InlineEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.savings_outlined, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
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

final BoxDecoration cardDecoration = BoxDecoration(
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
