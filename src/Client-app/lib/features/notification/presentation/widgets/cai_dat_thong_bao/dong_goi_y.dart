/// Dòng gợi ý B5b dưới một hàng của trang Cài đặt thông báo (`notification_settings_page.dart`), dời nguyên văn khỏi trang.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Dòng gợi ý B5b — màn Stitch `065eccd8…`: chữ phụ xám 12 px thẳng lề với
/// chữ của hàng bên trên (20 + biểu tượng 24 + 16), rồi nút viền *áp dụng* và
/// nút chữ xám *bỏ qua*. Không hộp màu, không biểu tượng — không tranh với hàng
/// cài đặt. `Wrap` để nút dài (*Đổi sang chủ nhật 21:30*) xuống dòng ở 360 dp.
class DongGoiY extends StatelessWidget {
  const DongGoiY({
    super.key,
    required this.cau,
    required this.nhanApDung,
    required this.nhanBoQua,
    required this.apDung,
    required this.boQua,
  });

  final String cau;
  final String nhanApDung;
  final String nhanBoQua;
  final VoidCallback apDung;
  final VoidCallback boQua;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cau,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: apDung,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(nhanApDung, style: const TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: boQua,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(nhanBoQua, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
