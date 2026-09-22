import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// "Cần thêm N ngày dữ liệu để gợi ý ngân sách" — thay chỗ thẻ "Chưa đặt ngân
/// sách" khi tài khoản còn trẻ hơn 14 ngày.
///
/// Ngoại lệ có chủ ý với luật "khối rỗng thì ẩn hẳn" (mục 3.34
/// `ANALYTICS_FEATURE.md`): "tôi chưa biết" khác "không có gì để nói", và im
/// lặng ở chỗ này chính là thứ đã che `suggestAmount` chết suốt hai tuần.
class TheChuaDuDuLieu extends StatelessWidget {
  final int soNgayConThieu;
  const TheChuaDuDuLieu({super.key, required this.soNgayConThieu});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('the-chua-du-du-lieu'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cần thêm $soNgayConThieu ngày dữ liệu để gợi ý ngân sách.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
