import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/luat_khoa_app.dart';

/// Sáu chấm PIN — Stitch `34c3cade…` (14 px, cách 16; đầy `#1A1A19`, viền 2 px `#767872`; lỗi viền đỏ).
/// Khoá mỗi chấm mang chỉ số (`cham-day-$i` / `cham-rong-$i`): sáu chấm là con của MỘT `Row`, khoá trùng là assert.
class ChamPin extends StatelessWidget {
  const ChamPin({super.key, required this.soDaNhap, this.loi = false});

  final int soDaNhap;
  final bool loi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đã nhập $soDaNhap trên $kDoDaiPin số',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kDoDaiPin; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Container(
              key: Key(i < soDaNhap ? 'cham-day-$i' : 'cham-rong-$i'),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < soDaNhap ? AppColors.primary : Colors.transparent,
                border: i < soDaNhap
                    ? null
                    : Border.all(color: loi ? AppColors.expense : AppColors.textSecondary, width: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
