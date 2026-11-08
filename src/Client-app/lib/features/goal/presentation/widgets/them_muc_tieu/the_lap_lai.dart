/// Thẻ "Lặp lại sau khi hoàn thành" của biểu mẫu Thêm / Sửa mục tiêu (`goal_add_page.dart`) — dời từ khối `// Thẻ LẶP LẠI`
/// của `build` (G88 gạch 2). Chỉ còn công tắc: thanh chọn chu kỳ tuần / tháng / năm bỏ 2026-11-04 (người dùng chốt) —
/// vòng mới dài đúng số ngày của vòng trước (`hanVongMoi`).
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

class TheLapLai extends StatelessWidget {
  const TheLapLai({
    super.key,
    required this.lapLai,
    required this.onDoiLapLai,
  });

  final bool lapLai;
  final ValueChanged<bool> onDoiLapLai;

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
                      'đầu vòng mới — cùng số tiền, dài đúng số '
                      'ngày như vòng này. Tiền đã tích vẫn ở '
                      'nguyên trong ví.',
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
        ],
      ),
    );
  }
}
