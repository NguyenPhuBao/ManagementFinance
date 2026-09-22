import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/goi_so.dart';

/// Thẻ số liệu đối soát (luật G3): hàng chip "nhãn chuỗi", mỗi chip là một
/// [SoLieu] của gói — đúng chuỗi mà bộ kiểm số cho phép, nên số trên thẻ
/// **bằng** số trong câu (điều kiện 12).
class TheSoLieu extends StatelessWidget {
  final List<SoLieu> ds;

  /// `true` khi đặt trên thẻ nền tối của Trang chủ.
  final bool nenToi;

  const TheSoLieu({super.key, required this.ds, this.nenToi = false});

  @override
  Widget build(BuildContext context) {
    final nen = nenToi
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.surfaceContainer;
    final chu = nenToi ? Colors.white : AppColors.textPrimary;
    final nhan = nenToi ? Colors.white70 : AppColors.textSecondary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in ds)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: nen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${s.nhan} ',
                  style: TextStyle(fontSize: 11, color: nhan),
                ),
                TextSpan(
                  text: s.chuoi,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: chu,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
