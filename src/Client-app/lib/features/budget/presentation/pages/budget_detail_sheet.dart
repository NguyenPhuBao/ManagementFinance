import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/budget_entity.dart';

/// Bảng chi tiết **chỉ đọc** của một ngân sách.
///
/// Dùng cho cả hai tab: ngân sách hết hạn chỉ xem được đúng bảng này, còn
/// ngân sách đang chạy thì chạm vào thẻ cũng mở nó ra.
///
/// Nội dung **phải cuộn được**. Chiều cao của một bottom sheet do màn hình
/// quyết định chứ không do nội dung; ngân sách có ghi chú dài hoặc có ngày kết
/// thúc sẽ vượt chỗ trống, và một `Column` thẳng khi đó ném lỗi layout rồi cắt
/// mất phần cuối — đúng lỗi "RenderFlex overflowed by 5.9 pixels" gặp ngày
/// 2026-09-04.
class BudgetDetailSheet extends StatelessWidget {
  final BudgetView view;

  const BudgetDetailSheet({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final b = view.budget;
    final ky = b.currentPeriod();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              view.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow('Hạn mức', CurrencyFormatter.format(b.amount)),
            _DetailRow('Đã chi', CurrencyFormatter.format(b.spent)),
            _DetailRow(
              b.isOverBudget ? 'Vượt' : 'Còn dư',
              CurrencyFormatter.format(
                  b.isOverBudget ? b.overAmount : b.remaining),
              colour: b.isOverBudget ? AppColors.expense : AppColors.income,
            ),
            const Divider(height: 32),
            _DetailRow('Kỳ hiện tại', '${_day(ky.from)} – ${_day(ky.to)}'),
            _DetailRow(
              'Chu kỳ',
              b.recurrence
                  ? '${BudgetRecurrence.label(b.timeRecurrence)} (lặp lại)'
                  : '${BudgetRecurrence.label(b.timeRecurrence)} (một lần)',
            ),
            _DetailRow('Bắt đầu', _day(b.startDate)),
            if (b.endDate != null) _DetailRow('Kết thúc', _day(b.endDate!)),
            if (b.note.isNotEmpty) _DetailRow('Ghi chú', b.note),
          ],
        ),
      ),
    );
  }

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? colour;

  const _DetailRow(this.label, this.value, {this.colour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colour ?? AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
