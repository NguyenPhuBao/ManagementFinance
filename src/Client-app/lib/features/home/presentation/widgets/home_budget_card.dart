import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/domain/budget_pace.dart';
import '../../../budget/presentation/widgets/budget_pace_text.dart';
import '../../../budget/presentation/widgets/budget_visuals.dart';

/// Ngân sách đáng chú ý nhất để đưa lên trang chủ: ngân sách **đang chạy** có
/// tỉ lệ đã chi cao nhất. So theo tỉ lệ chứ không theo số tiền — 150% của
/// 100k căng hơn 95% của 1 triệu. `null` khi không có ngân sách nào đang chạy.
///
/// Thuần Dart, tách khỏi widget để test bằng `expect` thường.
BudgetView? pickHomeBudget(List<BudgetView> views, DateTime now) {
  BudgetView? best;
  var bestRatio = -1.0;
  for (final v in views) {
    if (v.budget.isExpired(now)) continue;
    final ratio = v.budget.rawPercentSpent;
    if (ratio > bestRatio) {
      best = v;
      bestRatio = ratio;
    }
  }
  return best;
}

/// Thẻ "Ngân sách" trên trang chủ — theo Stitch màn Home: một ngân sách, "Đã
/// dùng X / Y", phần trăm, thanh tiến trình. Thay cho placeholder cứng
/// ("Ăn uống · Chưa thiết lập · 0%") tồn tại tới 2026-09-06.
class HomeBudgetCard extends StatelessWidget {
  final List<BudgetView> budgets;

  /// `null` = đồng hồ máy; test truyền mốc cố định.
  final DateTime? now;
  final VoidCallback? onTap;

  const HomeBudgetCard({
    super.key,
    required this.budgets,
    this.now,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moment = now ?? DateTime.now();
    final picked = pickHomeBudget(budgets, moment);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ngân sách',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: picked == null
                ? const _EmptyBody()
                : _BudgetBody(view: picked, now: moment),
          ),
        ),
      ],
    );
  }
}

class _BudgetBody extends StatelessWidget {
  final BudgetView view;
  final DateTime now;
  const _BudgetBody({required this.view, required this.now});

  @override
  Widget build(BuildContext context) {
    final b = view.budget;
    final mau = budgetHealthColour(budgetHealthOf(b));
    final percent = (b.rawPercentSpent * 100).round();
    final paceLine = budgetPaceLine(budgetPaceOf(b, now));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: budgetColorFrom(view.categoryColour, fallback: mau)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                budgetIconFor(view.categoryIcon),
                color: budgetColorFrom(view.categoryColour, fallback: mau),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đã dùng ${CurrencyFormatter.format(b.spent)} / '
                    '${CurrencyFormatter.format(b.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: b.percentSpent,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(mau),
            minHeight: 12,
          ),
        ),
        if (paceLine != null) ...[
          const SizedBox(height: 8),
          Text(
            paceLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.savings_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chưa thiết lập',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const LinearProgressIndicator(
            value: 0.0,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vào trang Ngân sách để lập kế hoạch chi tiêu',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
