// Cách vẽ tiến độ mục tiêu cho giao diện — chỗ duy nhất.
//
// ## Vì sao gom vào đây
//
// Trước đây trang danh sách và trang chi tiết mỗi nơi tự tính lại tỉ lệ bằng
// `targetAmount > 0 ? currentAmount / targetAmount : 0.0`, trong khi bộ luật
// thông báo dùng `GoalEntity.progress`. Hai công thức lệch nhau đúng ở mục tiêu
// 0 đồng: entity trả `1.0` (không cần thêm đồng nào thì coi như đã đạt) còn hai
// trang trả `0.0`. Kết quả là thông báo chúc mừng "đã hoàn thành" trong khi màn
// hình hiện 0%.
//
// Chú thích ngay trên `GoalEntity.progress` đã cảnh báo đúng kịch bản này. Để
// nó không tái diễn, các widget dưới đây nhận `GoalEntity` chứ không nhận
// `double`: nơi gọi không còn chỗ nào để tính ra một con số khác.

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/goal_entity.dart';

/// Tỉ lệ dùng để vẽ. Đọc từ [GoalEntity.progress] — đừng tính lại ở nơi gọi.
double _tyLe(GoalEntity goal) => goal.progress;

/// Nhãn phần trăm hiển thị, ví dụ `'37.5%'`.
String goalPercentLabel(GoalEntity goal) =>
    '${(_tyLe(goal) * 100).toStringAsFixed(1)}%';

/// Thanh tiến độ ngang trên thẻ mục tiêu ở trang danh sách.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.goal});

  final GoalEntity goal;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _tyLe(goal),
      backgroundColor: AppColors.surfaceContainerHigh,
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.income),
      minHeight: 12,
      borderRadius: BorderRadius.circular(6),
    );
  }
}

/// Vòng tiến độ lớn ở đầu trang chi tiết mục tiêu.
class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({super.key, required this.goal});

  final GoalEntity goal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: _tyLe(goal),
              strokeWidth: 16,
              color: const Color(0xFF2E6B27),
              backgroundColor: Colors.transparent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                goalPercentLabel(goal),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ĐÃ HOÀN THÀNH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
