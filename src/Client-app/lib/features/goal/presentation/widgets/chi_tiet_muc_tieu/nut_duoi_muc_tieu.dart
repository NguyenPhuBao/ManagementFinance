/// Hàng nút cuối trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn khỏi `_buildBottomButtons` (đợt tách bốn
/// trang lớn, spec 2026-10-13 mục 5.2): Bắt đầu vòng mới, Gửi thêm tiết kiệm, Rút khỏi mục tiêu, Chỉnh sửa. Việc mỗi nút
/// làm (xác nhận, mở phiếu, mở trang sửa rồi nạp lại) là callback của trang.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/goal_entity.dart';

class NutDuoiMucTieu extends StatelessWidget {
  const NutDuoiMucTieu({
    super.key,
    required this.goal,
    required this.onVongMoi,
    required this.onNap,
    required this.onRut,
    required this.onSua,
  });

  final GoalEntity goal;
  final VoidCallback onVongMoi, onNap, onRut, onSua;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút vòng mới chỉ hiện khi mục tiêu ĐÃ XONG và CÓ bật lặp lại — và
          // nó đứng đầu, trên cả "Gửi thêm tiết kiệm": với một mục tiêu đã
          // hoàn thành thì nạp thêm không còn là việc muốn làm nhất.
          //
          // Ẩn nút không phải là phép chặn. `batDauVongMoi` kiểm lại cả hai
          // điều kiện ở tầng repository, vì đặt lại một mục tiêu đang dở là
          // xoá tiến độ và không có gì hoàn tác.
          if (goal.daHoanThanh && goal.recurrence) ...[
            ElevatedButton.icon(
              onPressed: onVongMoi,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.income,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text(
                'Bắt đầu vòng mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: onNap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Gửi thêm tiết kiệm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Chỉ hiện khi có gì để rút. Nút mờ suốt đời với mục tiêu chưa nạp
          // đồng nào chỉ làm rối chỗ.
          if (goal.currentAmount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: .8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Rút khỏi mục tiêu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            // Trang này không nghe dòng dữ liệu (bẫy 4.5) nên phải tự nạp lại
            // sau khi trang sửa đóng, nếu không tên và số tiền vừa đổi vẫn là
            // số cũ trên màn hình.
            onPressed: onSua,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: .8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Chỉnh sửa mục tiêu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
