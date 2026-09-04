import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Hai nút hành động chính trên trang chủ: "Thêm giao dịch" và "Xem báo cáo".
///
/// Tách khỏi `home_page.dart` để test được ở nhiều bề rộng màn hình.
///
/// Dùng `FittedBox(scaleDown)` chứ không cắt chữ bằng `ellipsis`: hai nhãn này
/// ngắn và là hành động chính của trang chủ, "Thêm giao dị…" đọc như lỗi. Thu
/// nhỏ vài phần trăm ở màn hẹp thì không ai nhận ra, và trên màn đủ rộng
/// `FittedBox` không đổi gì cả.
class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({
    super.key,
    required this.onAdd,
    required this.onReport,
  });

  final VoidCallback onAdd;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              fixedSize: const Size.fromHeight(76),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Thêm giao dịch',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(
                  color: AppColors.outlineVariant, width: 1.5),
              fixedSize: const Size.fromHeight(76),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insights, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Xem báo cáo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
