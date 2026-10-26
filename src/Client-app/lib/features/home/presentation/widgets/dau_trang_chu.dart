/// Đầu Trang chủ: nút menu · chữ *FlowMoney* · chuông thông báo — tách từ `home_page.dart` ngày 2026-10-26 (phiên 9) để
/// dựng được ở khổ hẹp + cỡ chữ lớn mà không cần DI (chuông truyền vào).
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class DauTrangChu extends StatelessWidget {
  const DauTrangChu({super.key, required this.chuong});

  /// Chuông thông báo (đếm thật từ bảng thông báo cục bộ — trang dựng và truyền vào).
  final Widget chuong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Nhóm trái chiếm phần còn lại, chữ co khi chật (cỡ chữ lớn): chuông luôn nằm trọn trong lề — Realme 320 dp ×
        // cỡ chữ 1,6 (2026-10-26) từng đẩy chuông + "99+" ra quá mép phải.
        Expanded(
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Mở menu',
                  icon: const Icon(Icons.menu, color: AppColors.primary, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 16),
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FlowMoney',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // Chấm đỏ trước đây vẽ CỨNG ở đây — luôn sáng dù chẳng có thông báo
        // nào. Nay đếm thật từ bảng thông báo cục bộ.
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: chuong,
        ),
      ],
    );
  }
}
