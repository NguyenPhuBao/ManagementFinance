/// Thẻ *Tổng số dư ví* ở Trang chủ — tách từ `home_page.dart` ngày 2026-10-26 (phiên 9) để dựng được ở khổ hẹp + cỡ chữ
/// lớn. Con số là tổng đã lọc qua `viTinhVaoTong` — trang tính, thẻ chỉ vẽ.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';

class TheTongSoDu extends StatelessWidget {
  const TheTongSoDu({super.key, required this.tongSoDu});

  final double tongSoDu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Wrap` chứ không `Row`: đủ chỗ thì chip đứng bên phải tiêu đề (Stitch), chật (cỡ chữ lớn, 320 dp) thì xuống
          // dòng — `Row` đẩy chip tràn ra ngoài thẻ và mép màn (Realme 2026-10-26).
          SizedBox(
            // Bề rộng đủ thẻ — `Wrap` trong `Column` căn trái chỉ rộng bằng nội dung, `spaceBetween` sẽ không đẩy chip sang phải.
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Tổng số dư ví',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Số dư thực tế',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Một dòng, co khi không vừa — `Text` tự xuống dòng thì cắt GIỮA chữ số ("-3.256.0" / "00 đ", Realme cỡ chữ 1,6).
          // Cùng cách `SoTienLon` ở màn Thêm giao dịch.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(tongSoDu),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
