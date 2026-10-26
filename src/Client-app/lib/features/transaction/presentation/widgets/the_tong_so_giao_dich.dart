/// Thẻ tổng của Sổ giao dịch (Thu nhập · Chi tiêu · Thu net của kỳ đang xem) — tách từ `transaction_page.dart` ngày
/// 2026-10-26 (phiên 9) để dựng được ở khổ hẹp + cỡ chữ lớn. Hai con số đầu trang đã tính qua `summarizeTransactions`
/// (đi qua `khoanVaoThongKe`, G49) — thẻ chỉ vẽ.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/nhan_co_deu.dart';

class TheTongSoGiaoDich extends StatelessWidget {
  const TheTongSoGiaoDich({super.key, required this.totalIncome, required this.totalExpense});

  final double totalIncome;
  final double totalExpense;

  static const _nhan = ['Thu nhập', 'Chi tiêu', 'Thu net'];

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    // `formatCoDau` chứ không `formatIncome`/`formatExpense`: kỳ rỗng là
    // ca THƯỜNG từ khi trang xem được năm đơn vị, và số 0 không mang dấu
    // (cột "Thu net" ngay bên cạnh vốn đã theo luật ấy).
    final so = [
      CurrencyFormatter.formatCoDau(totalIncome, thu: true),
      CurrencyFormatter.formatCoDau(totalExpense, thu: false),
      CurrencyFormatter.formatCoDau(net, thu: net >= 0),
    ];
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
      // Ba cột CHIA ĐỀU, số trong mỗi cột một dòng tự co: `spaceAround` để mỗi cột rộng bằng chữ của nó, nên ở cỡ chữ lớn
      // hai số dính nhau và tràn khỏi thẻ ("-310.000 đ-310.00", Realme 320 dp × cỡ chữ 1,6, 2026-10-26).
      child: Row(
        children: [
          _cot(0, so, AppColors.income),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _cot(1, so, AppColors.error),
          Container(width: 1, height: 36, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          _cot(2, so, net >= 0 ? AppColors.income : AppColors.error),
        ],
      ),
    );
  }

  /// Cột [i]: nhãn + số. Ba cột bằng nhau nên ba nhãn (và ba số) co CÙNG hệ số qua `NhanCoDeu` — `FittedBox` riêng từng
  /// cột để số ngắn giữ cỡ còn số dài co, *"0 đ"* to hơn hẳn *"-310.000 đ"* bên cạnh (Realme 320 dp × cỡ chữ 1,6,
  /// 2026-10-26).
  Widget _cot(int i, List<String> so, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            NhanCoDeu(
              _nhan[i],
              nhom: _nhan,
              kieu: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            NhanCoDeu(
              so[i],
              nhom: so,
              kieu: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
