import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../goal/data/models/goal_entity.dart';
import '../../../goal/domain/goal_grouping.dart';
import '../../../goal/presentation/widgets/goal_appearance.dart';
import '../../../goal/presentation/widgets/goal_progress.dart';

/// Mục tiêu đáng đưa lên trang chủ: cái **ưu tiên nhất** trong số đang theo
/// đuổi. `null` khi không còn mục tiêu nào đang chạy.
///
/// ## Vì sao gọi `chiaMucTieu` thay vì tự lọc và tự sắp
///
/// Thứ tự mục tiêu có **đúng một** định nghĩa, và nó nằm ở `chiaMucTieu`: ưu
/// tiên trước, hạn định làm quy tắc phụ, `NULL` xếp cuối. Viết lại ở đây là
/// tạo bản sao thứ hai — thứ sẽ lệch đi ở lần sửa sau. Dự án đã học bài này
/// hai lần: tỉ lệ tiến độ (mục 3.6) và định nghĩa "đã xong" (mục 3.18)
/// `GOAL_FEATURE.md`.
///
/// Phép lọc "đã xong" cũng đi kèm miễn phí: `chiaMucTieu` dùng
/// `GoalEntity.daHoanThanh`, nên mục tiêu 0 đồng (`progress` trả thẳng `1.0`)
/// tự rơi sang tab kia thay vì hiện trên trang chủ dưới dạng một thẻ 100%.
///
/// Thuần Dart, tách khỏi widget để test bằng `expect` thường — cùng lối với
/// `pickHomeBudget`.
GoalEntity? chonMucTieuTrangChu(List<GoalEntity> goals) {
  final nhom = chiaMucTieu(goals);
  return nhom.dangTheoDuoi.isEmpty ? null : nhom.dangTheoDuoi.first;
}

/// Thẻ "Mục tiêu tiết kiệm" trên trang chủ.
///
/// Trước 2026-09-08 mục tiêu chỉ vào được qua **một dòng trong drawer**, trong
/// khi ngân sách đã có hẳn một khối ở đây. Cột `priority` (schema v19) là thứ
/// làm khối này có nghĩa: nó trả lời được câu *hiện mục tiêu nào* mà trước đó
/// không có cách nào trả lời đúng.
///
/// ⚠️ Khối này **đi lệch thiết kế Stitch** màn Home, nơi không có phần mục tiêu
/// nào — theo yêu cầu của người dùng ngày 2026-09-08, cùng lượt với việc gỡ
/// khối thông báo khỏi trang chủ.
class HomeGoalCard extends StatelessWidget {
  final List<GoalEntity> goals;
  final VoidCallback? onTap;

  const HomeGoalCard({super.key, required this.goals, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chon = chonMucTieuTrangChu(goals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mục tiêu tiết kiệm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: chon == null ? const _KhungRong() : _ThanThe(goal: chon),
          ),
        ),
      ],
    );
  }
}

class _ThanThe extends StatelessWidget {
  final GoalEntity goal;
  const _ThanThe({required this.goal});

  @override
  Widget build(BuildContext context) {
    final mau = mauMucTieu(goal.colour);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mau.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(bieuTuongMucTieu(goal.icon), color: mau, size: 20),
            ),
            const SizedBox(width: 12),
            // `Expanded` chứ không để `Text` trần: tên mục tiêu là dữ liệu
            // người dùng nhập và dài bao nhiêu cũng được, còn khổ thật là
            // 411dp — hàng này tràn là cả trang chủ đầy sọc vàng.
            Expanded(
              child: Text(
                goal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Nhận thẳng `GoalEntity`, không nhận `double`: `goalPercentLabel`
            // là nơi duy nhất biến tiến độ thành chữ, nên nơi gọi không còn
            // chỗ nào để tính ra một con số khác (mục 3.6).
            Text(
              goalPercentLabel(goal),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: mau,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GoalProgressBar(goal: goal),
        const SizedBox(height: 12),
        Text(
          'Đã tích ${CurrencyFormatter.format(goal.currentAmount)} / '
          '${CurrencyFormatter.format(goal.targetAmount)}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Chưa có mục tiêu nào đang chạy.
///
/// Cố ý **không vẽ thanh tiến độ 0%**: một thanh rỗng trông y hệt một mục tiêu
/// thật chưa tích được đồng nào, và người dùng sẽ đi tìm xem nó là cái gì.
class _KhungRong extends StatelessWidget {
  const _KhungRong();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.savings_outlined,
              color: AppColors.textSecondary, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Chưa có mục tiêu tiết kiệm nào đang chạy. Đặt một mục tiêu để '
            'theo dõi tiến độ.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
