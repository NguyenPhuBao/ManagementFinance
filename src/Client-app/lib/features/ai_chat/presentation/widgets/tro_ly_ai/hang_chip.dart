/// Hàng chip gợi ý của màn Trợ lý AI (dời nguyên văn khỏi `ai_chat_page.dart`).
/// Trạng thái ở lại trang: widget nhận danh sách nhãn, cờ bật và callback chọn.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

class HangChip extends StatelessWidget {
  const HangChip({
    super.key,
    required this.nhan,
    required this.bat,
    required this.onChon,
  });

  final List<String> nhan;
  final bool bat;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.background.withValues(alpha: 0.95),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final c in nhan) ...[
              _chip(c),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String nhan) {
    return Material(
      color: bat
          ? AppColors.secondaryContainer
          : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        // ⚠️ `null` khi chưa có mô hình: ô nhập đã khoá mà chip vẫn hỏi được
        // thì có một đường vòng quanh chính cái khoá ấy.
        onTap: bat ? () => onChon(nhan) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            nhan,
            style: TextStyle(
              color: bat ? AppColors.onSurfaceVariant : AppColors.outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
