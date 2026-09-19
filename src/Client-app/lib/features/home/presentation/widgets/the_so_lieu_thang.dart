import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';

/// Ba thẻ Thu nhập / Chi tiêu / Thu net của tháng ở Trang chủ.
///
/// Tách khỏi `HomePage` ngày 2026-09-19 để test được ở khổ 411dp.
class TheSoLieuThang extends StatelessWidget {
  const TheSoLieuThang({super.key, required this.thu, required this.chi});

  final double thu;
  final double chi;

  @override
  Widget build(BuildContext context) {
    final net = thu - chi;
    return Row(
      children: [
        Expanded(
            child: _The('Thu nhập', CurrencyFormatter.format(thu),
                thu > 0 ? 0.8 : 0.0, AppColors.income)),
        const SizedBox(width: 12),
        Expanded(
            child: _The('Chi tiêu', CurrencyFormatter.format(chi),
                chi > 0 ? 0.4 : 0.0, AppColors.error)),
        const SizedBox(width: 12),
        Expanded(
            child: _The(
                'Thu net',
                // Số 0 không mang dấu — định nghĩa duy nhất ở `formatCoDau`.
                CurrencyFormatter.formatCoDau(net, thu: net >= 0),
                net != 0 ? 0.6 : 0.0,
                const Color(0xFF3B82F6))),
      ],
    );
  }
}

class _The extends StatelessWidget {
  const _The(this.nhan, this.soTien, this.tienDo, this.mau);

  final String nhan;
  final String soTien;
  final double tienDo;
  final Color mau;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // `FittedBox` co chữ cho vừa ô thay vì cắt "…": thẻ rộng ~113dp ở
          // 411dp, và `ellipsis` từng cắt "14.635.000 đ" thành "14.635.0…" —
          // con số chính của Trang chủ không đọc được (UX 2026-09-19, B2).
          // `SizedBox(width: infinity)` cho FittedBox một bề rộng hữu hạn để
          // co theo; `Text` giữ `maxLines: 1` để không ngắt dòng im lặng.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                soTien,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: tienDo,
            backgroundColor: mau.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(mau),
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}
