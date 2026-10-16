/// Hộp nhận định (dự báo hoàn thành, nhịp tích lũy) của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn
/// khỏi `_buildInsightBox` (đợt tách bốn trang lớn, spec 2026-10-13 mục 5.2).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/goal_entity.dart';
import '../../../domain/goal_forecast.dart';

class KhoiNhanDinhMucTieu extends StatelessWidget {
  const KhoiNhanDinhMucTieu({super.key, required this.goal});

  final GoalEntity goal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final duBao = duBaoHoanThanh(goal, now);
    final thucTe = tocDoThucTe(goal, now);
    final keHoach = tocDoKeHoach(goal, now: now);
    // Dòng đầu: dự báo THẬT thay cho câu lặp lại hạn chót.
    //
    // `targetDate` được tính một lần lúc tạo từ chu kỳ người dùng nhập, rồi
    // đóng băng. Không có bộ lập lịch nào trích tiền, nên nhịp thật do chính
    // các lần nạp tay quyết định — và đó mới là thứ đáng hiển thị.
    final String tieuDe;
    if (goal.isCompleted || goal.remainingAmount <= 0) {
      tieuDe = 'ĐÃ ĐẠT MỤC TIÊU';
    } else if (duBao == null) {
      tieuDe = 'CHƯA ĐỦ DỮ LIỆU ĐỂ DỰ BÁO';
    } else {
      tieuDe =
          'DỰ BÁO HOÀN THÀNH: THÁNG ${DateFormat('MM/yyyy').format(duBao)}';
    }

    final nhipLabel = switch (goal.cycleTakeMoney) {
      'Day' => 'mỗi ngày',
      'Week' => 'mỗi tuần',
      'Quarter' => 'mỗi quý',
      'Year' => 'mỗi năm',
      _ => 'mỗi tháng',
    };

    final String mota;
    if (goal.isCompleted || goal.remainingAmount <= 0) {
      mota = 'Không cần tích thêm đồng nào.';
    } else if (thucTe == null) {
      // Lý do là CHƯA ĐỦ THỜI GIAN, không phải chưa đủ số lần nạp — xem
      // `_duCuaSo` ở `goal_forecast.dart`. Câu cũ ("gửi thêm vài lần") sai
      // hướng: người dùng nạp thêm mười lần trong cùng ngày vẫn không mở được
      // hộp này, và họ sẽ tưởng tính năng hỏng.
      mota = 'Cần theo dõi thêm ít lâu để app ước lượng được nhịp tích lũy. '
          'Nhịp $nhipLabel chỉ có nghĩa khi đã qua ít nhất nửa chu kỳ.';
    } else if (duBao == null) {
      mota = 'Chưa tích được đồng nào $nhipLabel, nên chưa ước lượng được '
          'ngày đạt mục tiêu.';
    } else {
      final canThem = keHoach == null
          ? ''
          : ' · cần ${CurrencyFormatter.format(keHoach)} để kịp hạn '
              '${DateFormat('MM/yyyy').format(goal.targetDate)}';
      mota =
          'Đang tích ${CurrencyFormatter.format(thucTe)} $nhipLabel$canThem.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC3EBBB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Color(0xFF2E6B27),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mota,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
