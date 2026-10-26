/// Thẻ tổng của Sổ giao dịch (Thu nhập · Chi tiêu · Thu net của kỳ đang xem) — tách từ `transaction_page.dart` ngày
/// 2026-10-26 (phiên 9) để dựng được ở khổ hẹp + cỡ chữ lớn. Hai con số đầu trang đã tính qua `summarizeTransactions`
/// (đi qua `khoanVaoThongKe`, G49) — thẻ chỉ vẽ.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';

class TheTongSoGiaoDich extends StatelessWidget {
  const TheTongSoGiaoDich({super.key, required this.totalIncome, required this.totalExpense});

  final double totalIncome;
  final double totalExpense;

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // `formatCoDau` chứ không `formatIncome`/`formatExpense`: kỳ rỗng là
          // ca THƯỜNG từ khi trang xem được năm đơn vị, và số 0 không mang dấu
          // (cột "Thu net" ngay bên cạnh vốn đã theo luật ấy).
          _cot('Thu nhập', CurrencyFormatter.formatCoDau(totalIncome, thu: true), AppColors.income),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _cot('Chi tiêu', CurrencyFormatter.formatCoDau(totalExpense, thu: false), AppColors.error),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _cot(
            'Thu net',
            CurrencyFormatter.formatCoDau(net, thu: net >= 0),
            net >= 0 ? AppColors.income : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _cot(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
