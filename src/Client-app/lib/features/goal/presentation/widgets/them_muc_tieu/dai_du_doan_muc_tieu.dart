/// Dải "AI Dự đoán" ở cuối biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`): ngày dự kiến đạt mục tiêu theo mức trích
/// hiện tại — dời nguyên văn từ khối `// AI Prediction Insight Banner` của `build`, kèm getter nhãn chu kỳ (G88 gạch 2).
library;

import 'package:flutter/material.dart';
import '../../../../../core/utils/date_formatter.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/chu_ky_muc_tieu.dart';

class DaiDuDoanMucTieu extends StatelessWidget {
  const DaiDuDoanMucTieu({
    super.key,
    required this.estimatedCompletionDate,
    required this.depositAmountController,
    required this.frequency,
  });

  final DateTime estimatedCompletionDate;
  final TextEditingController depositAmountController;
  final DepositFrequency frequency;

  String get _frequencyLabel {
    switch (frequency) {
      case DepositFrequency.daily:
        return 'ngày';
      case DepositFrequency.weekly:
        return 'tuần';
      case DepositFrequency.monthly:
        return 'tháng';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDEE1F8).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE1F8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFC2C5DB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424658),
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
                children: [
                  const TextSpan(
                      text: 'AI Dự đoán: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: 'Dự kiến bạn sẽ đạt mục tiêu vào ngày '),
                  TextSpan(
                      text: DateFormatter.formatDate(estimatedCompletionDate),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income)),
                  TextSpan(
                      text:
                          ' với mức trích ${CurrencyFormatter.format(CurrencyFormatter.parse(depositAmountController.text) ?? 0)} / $_frequencyLabel.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
