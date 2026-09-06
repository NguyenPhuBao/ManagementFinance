import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/presentation/widgets/transaction_row_content.dart';
import '../../data/models/budget_entity.dart';
import '../../domain/budget_history.dart';
import '../bloc/budget_detail_cubit.dart';
import '../widgets/budget_pace_text.dart';
import '../widgets/budget_visuals.dart';
import 'budget_tabs_view.dart' show BudgetProgressBar, cardDecoration;

/// Phần hiển thị của trang chi tiết ngân sách: đầu trang, nhịp chi, lịch sử
/// sáu kỳ, và các khoản chi của kỳ hiện tại.
///
/// Cố ý **không** đọc cubit: mọi thao tác đi ra qua callback, để bố cục 411dp
/// kiểm được bằng widget test thuần. Thay cho bottom sheet cũ từ 2026-09-06:
/// bốn khối này không vừa một sheet, và người dùng cần cuộn danh sách.
class BudgetDetailView extends StatelessWidget {
  final BudgetDetailLoaded state;

  /// `null` = không cho sửa (ngân sách đã hết hạn).
  final VoidCallback? onEdit;
  final void Function(TransactionEntity) onTapTransaction;

  const BudgetDetailView({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final b = state.view.budget;
    final mau = state.expired
        ? (b.isOverBudget ? AppColors.expense : AppColors.income)
        : budgetHealthColour(budgetHealthOf(b));
    final paceLine = state.expired ? null : budgetPaceLine(state.pace);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text(
          state.view.displayName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        actions: [
          if (onEdit != null)
            IconButton(
              key: const ValueKey('budget-detail-edit'),
              tooltip: 'Chỉnh ngân sách',
              icon: const Icon(Icons.tune, color: AppColors.primary),
              onPressed: onEdit,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _HeaderCard(state: state, colour: mau),
            if (paceLine != null) ...[
              const SizedBox(height: 16),
              _PaceCard(state: state, line: paceLine),
            ],
            const SizedBox(height: 16),
            _HistoryCard(
              history: state.history,
              timeRecurrence: b.timeRecurrence,
            ),
            const SizedBox(height: 24),
            _SectionLabel('TRONG KỲ NÀY (${state.transactions.length})'),
            const SizedBox(height: 8),
            if (state.transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: cardDecoration,
                child: const Text(
                  'Chưa có khoản chi nào trong kỳ này.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              )
            else
              Container(
                decoration: cardDecoration,
                child: Column(
                  children: [
                    for (var i = 0; i < state.transactions.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1, color: AppColors.surfaceContainer),
                      _TransactionRow(
                        tx: state.transactions[i],
                        state: state,
                        onTap: () => onTapTransaction(state.transactions[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Đầu trang ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final BudgetDetailLoaded state;
  final Color colour;
  const _HeaderCard({required this.state, required this.colour});

  @override
  Widget build(BuildContext context) {
    final b = state.view.budget;
    // Ngân sách hết hạn thì `currentPeriod` tự chốt ở kỳ cuối.
    final ky = b.currentPeriod();
    final vuot = b.isOverBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  budgetIconFor(state.view.categoryIcon),
                  color: budgetColorFrom(state.view.categoryColour),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.expired
                          ? 'ĐÃ HẾT HẠN'
                          : (vuot ? 'ĐÃ TIÊU VƯỢT' : 'CÒN LẠI TRONG KỲ'),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${BudgetRecurrence.label(b.timeRecurrence)} · '
                      '${_ngay(ky.from)} – ${_ngay(ky.to)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(vuot ? b.overAmount : b.remaining),
              style: TextStyle(
                fontSize: 36,
                height: 1.2,
                letterSpacing: -1,
                fontWeight: FontWeight.bold,
                color: vuot ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${CurrencyFormatter.format(b.spent)} / '
            '${CurrencyFormatter.format(b.amount)} đã dùng',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          BudgetProgressBar(percent: b.percentSpent, color: colour),
          if (b.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              b.note,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Nhịp chi ────────────────────────────────────────────────────────────────

class _PaceCard extends StatelessWidget {
  final BudgetDetailLoaded state;
  final String line;
  const _PaceCard({required this.state, required this.line});

  @override
  Widget build(BuildContext context) {
    final pace = state.pace;
    final mauNhip = budgetPaceStatusColour(pace.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('NHỊP CHI'),
          const SizedBox(height: 8),
          Text(
            line,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mauNhip.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  budgetPaceStatusLabel(pace.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mauNhip,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Theo thời gian đã trôi: '
                  '${CurrencyFormatter.format(pace.expectedSpent)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Lịch sử ─────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final List<BudgetPeriodSummary> history;
  final String? timeRecurrence;
  const _HistoryCard({required this.history, required this.timeRecurrence});

  static const double _chartHeight = 120;
  static const double _maxBarWidth = 64;

  @override
  Widget build(BuildContext context) {
    // Thang chung cho mọi cột: cột cao nhất là hạn mức hoặc kỳ vượt nhiều
    // nhất — để vạch hạn mức luôn nằm trong khung.
    var max = 0.0;
    for (final k in history) {
      if (k.amount > max) max = k.amount;
      if (k.spent > max) max = k.spent;
    }
    if (max <= 0) max = 1;
    final amount = history.isEmpty ? 0.0 : history.last.amount;
    final limitBottom = _chartHeight * (amount / max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('LỊCH SỬ ${history.length} KỲ'),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Text(
              'Chưa có kỳ nào.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            SizedBox(
              height: _chartHeight + 28,
              child: Stack(
                children: [
                  // Vạch hạn mức — cùng một mức cho mọi kỳ vì không có nơi lưu
                  // hạn mức cũ (xem `BudgetPeriodSummary.amount`).
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 28 + limitBottom - 1,
                    child: Container(height: 1, color: AppColors.outline),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < history.length; i++)
                        Expanded(
                          // Trần bề rộng: ngân sách mới chỉ có một kỳ, để
                          // `Expanded` tự do thì cột phình ra cả thẻ và nhìn
                          // như lỗi vẽ. 64dp ≈ cỡ cột khi đủ sáu kỳ ở 411dp.
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: _maxBarWidth),
                              child: _HistoryBar(
                                index: i,
                                summary: history[i],
                                heightFactor: history[i].spent / max,
                                isCurrent: i == history.length - 1,
                                label: _periodLabel(history[i].from),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _periodLabel(DateTime from) => switch (timeRecurrence) {
        BudgetRecurrence.month => 'T${from.month}',
        BudgetRecurrence.quarter => 'Q${(from.month - 1) ~/ 3 + 1}',
        BudgetRecurrence.year => '${from.year}',
        _ => '${from.day}/${from.month}',
      };
}

class _HistoryBar extends StatelessWidget {
  final int index;
  final BudgetPeriodSummary summary;
  final double heightFactor;
  final bool isCurrent;
  final String label;

  const _HistoryBar({
    required this.index,
    required this.summary,
    required this.heightFactor,
    required this.isCurrent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colour = summary.isOverBudget
        ? AppColors.error
        : (isCurrent ? AppColors.primary : AppColors.income);
    // Cột 0 vẫn có một vệt 2px để người dùng thấy kỳ ấy tồn tại.
    final height = (_HistoryCard._chartHeight * heightFactor).clamp(2.0, 120.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: ValueKey('budget-history-bar-$index'),
            height: height,
            decoration: BoxDecoration(
              color: colour,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Giao dịch ───────────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final TransactionEntity tx;
  final BudgetDetailLoaded state;
  final VoidCallback onTap;
  const _TransactionRow({
    required this.tx,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = buildTransactionRowContent(tx, state.lookup);
    return InkWell(
      key: ValueKey('budget-tx-${tx.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: content.colour.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(content.icon, color: content.colour, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${content.subtitle} • ${_ngay(tx.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              content.amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: content.amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mảnh nhỏ ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

String _ngay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
