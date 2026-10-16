/// Hai dòng chữ phụ của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn khỏi `_buildGhiChu` (ghi chú của
/// người dùng) và `_buildCanhBaoVi` (câu nhắc khi ví tích lũy không đủ tiền), đợt tách bốn trang lớn, spec 2026-10-13
/// mục 5.2.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Ghi chú của người dùng — cái **lý do** đằng sau mục tiêu.
///
/// Đặt ngay dưới con số, trước hộp dự báo: khi mở mục tiêu ra để cân nhắc có
/// nên tiêu vào tiền tích luỹ hay không, câu tự mình viết ra là thứ đáng đọc
/// trước cả tốc độ tiết kiệm.
///
/// Không có khung viền, không có nhãn "GHI CHÚ": nó là chữ của người dùng
/// chứ không phải một trường dữ liệu cần gắn mác.
class GhiChuMucTieu extends StatelessWidget {
  const GhiChuMucTieu(this.noiDung, {super.key});

  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.format_quote_rounded,
            size: 18, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            noiDung,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class CanhBaoViMucTieu extends StatelessWidget {
  const CanhBaoViMucTieu(this.noiDung, {super.key});

  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              noiDung,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
