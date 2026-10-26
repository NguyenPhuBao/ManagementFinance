/// Hàng tiêu đề khối *Giao dịch gần đây* của Trang chủ (chữ + nút *Xem tất cả*) — tách từ `home_page.dart` ngày
/// 2026-10-26 (phiên 9) để dựng được ở khổ hẹp + cỡ chữ lớn mà không cần router (lối đi truyền vào).
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class TieuDeGiaoDichGanDay extends StatelessWidget {
  const TieuDeGiaoDichGanDay({super.key, required this.onXemTatCa});

  final VoidCallback onXemTatCa;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // `Flexible`: cỡ chữ lớn ở khổ hẹp thì tiêu đề xuống dòng, nút giữ trọn — Realme 320 dp × cỡ chữ 1,6 (2026-10-26)
        // từng đẩy *Xem tất cả* ra quá mép phải (tràn 72 px).
        const Flexible(
          child: Text(
            'GIAO DỊCH GẦN ĐÂY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onXemTatCa,
          child: const Text('Xem tất cả',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
