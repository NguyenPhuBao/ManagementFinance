import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Tấm xác nhận "Quên mã PIN?" vẽ TRONG màn khoá (lớp khoá ngoài `Navigator` — `showDialog` sẽ nằm dưới nó). Stitch
/// *"Màn khoá - Xác nhận quên mã PIN"*.
class TamXacNhanQuenPin extends StatelessWidget {
  const TamXacNhanQuenPin({super.key, required this.khiDangXuat, required this.khiHuy});

  final VoidCallback khiDangXuat;
  final VoidCallback khiHuy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: khiHuy, child: ColoredBox(color: Colors.black.withValues(alpha: 0.4))),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: const Color(0xFFE2E2DC), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                      child: const Icon(Icons.logout, color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Đăng xuất để đặt lại mã PIN?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập lại bằng mật khẩu tài khoản. Nếu đăng nhập đúng tài khoản này, dữ liệu trên máy được '
                    'giữ nguyên. Cần có mạng.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF454743)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: khiDangXuat,
                      child: const Text('Đăng xuất'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFFE2E2DC)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: khiHuy,
                      child: const Text('Huỷ'),
                    ),
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
