/// Thẻ "Lặp lại sau khi hoàn thành" của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`): công tắc và thanh chọn chu kỳ
/// lặp — dời nguyên văn từ khối `// Thẻ LẶP LẠI` của `build` (G88 gạch 2).
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../../shared/widgets/segmented_choice.dart';
import '../../../domain/chu_ky_muc_tieu.dart';
import 'o_nhap_muc_tieu.dart';

class TheLapLai extends StatelessWidget {
  const TheLapLai({
    super.key,
    required this.lapLai,
    required this.onDoiLapLai,
    required this.chuKyLap,
    required this.onDoiChuKy,
  });

  final bool lapLai;
  final ValueChanged<bool> onDoiLapLai;
  final String chuKyLap;
  final ValueChanged<String> onDoiChuKy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lặp lại sau khi hoàn thành',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    // Nói thẳng rằng app KHÔNG tự làm gì. Câu
                    // này là hợp đồng với người dùng: đặt lại
                    // mục tiêu là xoá tiến độ, nên nó phải là
                    // một cú bấm có ý thức.
                    Text(
                      'Khi đạt mục tiêu, app sẽ nhắc bạn bắt '
                      'đầu vòng mới. Tiền đã tích vẫn ở nguyên '
                      'trong ví.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: lapLai,
                onChanged: (val) => onDoiLapLai(val),
                activeThumbColor: AppColors.income,
              ),
            ],
          ),
          if (lapLai) ...[
            const SizedBox(height: 16),
            const NhanMucTieu('LẶP LẠI MỖI'),
            const SizedBox(height: 4),
            SegmentedChoice<String>(
              keyPrefix: 'goal-repeat-cycle',
              options: [
                for (final e in kChuKyLapLai.entries)
                  SegmentedOption(e.key, e.value),
              ],
              selected: chuKyLap,
              accent: AppColors.income,
              onChanged: (v) => onDoiChuKy(v),
            ),
          ],
        ],
      ),
    );
  }
}
