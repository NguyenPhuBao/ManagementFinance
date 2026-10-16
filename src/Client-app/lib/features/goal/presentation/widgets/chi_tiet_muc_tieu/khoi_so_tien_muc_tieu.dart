/// Khối số tiền của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn khỏi `_buildAmountInfo` (đợt tách
/// bốn trang lớn, spec 2026-10-13 mục 5.2): số đã tích / mục tiêu và dòng "Còn lại … để đạt mục tiêu".
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/goal_entity.dart';

class KhoiSoTienMucTieu extends StatelessWidget {
  const KhoiSoTienMucTieu(
      {super.key, required this.goal, required this.remaining});

  final GoalEntity goal;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              CurrencyFormatter.format(goal.currentAmount),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -1,
              ),
            ),
            Text(
              ' / ${CurrencyFormatter.format(goal.targetAmount)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            children: [
              const TextSpan(text: 'Còn lại '),
              TextSpan(
                text: CurrencyFormatter.format(remaining),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' để đạt mục tiêu'),
            ],
          ),
        ),
      ],
    );
  }
}
