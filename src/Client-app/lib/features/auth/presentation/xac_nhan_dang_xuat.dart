import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Hộp thoại xác nhận đăng xuất — một định nghĩa cho cả nút ở tab Cá nhân lẫn
/// mục "Đăng xuất" ở drawer Trang chủ (thêm 2026-09-19 theo màn Stitch).
///
/// Trả `true` khi người dùng chọn "Đăng xuất", `false`/`null` khi huỷ.
Future<bool?> xacNhanDangXuat(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
          'Bạn có chắc muốn đăng xuất không?\nBạn vẫn có thể đăng nhập offline sau khi đăng xuất.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );
}
