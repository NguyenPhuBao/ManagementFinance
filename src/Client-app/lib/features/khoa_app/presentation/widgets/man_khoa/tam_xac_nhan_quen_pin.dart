import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../mau_khoa_app.dart';

/// Tấm xác nhận "Quên mã PIN?" vẽ TRONG màn khoá (lớp khoá ngoài `Navigator` — `showDialog` sẽ nằm dưới nó). Stitch
/// *"Màn khoá - Xác nhận quên mã PIN"*.
class TamXacNhanQuenPin extends StatefulWidget {
  const TamXacNhanQuenPin({super.key, required this.khiDangXuat, required this.khiHuy});

  final VoidCallback khiDangXuat;
  final VoidCallback khiHuy;

  @override
  State<TamXacNhanQuenPin> createState() => _TamXacNhanQuenPinState();
}

class _TamXacNhanQuenPinState extends State<TamXacNhanQuenPin> {
  /// Đã chạm *Đăng xuất*: khoá cả hai nút + lớp mờ — chạm đôi là hai `LogoutRequested`, còn *Huỷ* lúc ấy không huỷ được gì.
  bool _daDangXuat = false;

  void _dangXuat() {
    if (_daDangXuat) return;
    setState(() => _daDangXuat = true);
    widget.khiDangXuat();
  }

  void _huy() {
    if (_daDangXuat) return;
    widget.khiHuy();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: _huy, child: ColoredBox(color: Colors.black.withValues(alpha: 0.4))),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            // Màn khoá đặt tấm ngoài SafeArea (lớp mờ phủ cả thanh trạng thái): mặt tấm chạm mép dưới, nội dung tránh thanh
            // điều hướng.
            child: SafeArea(
              top: false,
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
                      style: TextStyle(fontSize: 14, color: kXamChuKhoaApp),
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
                        onPressed: _daDangXuat ? null : _dangXuat,
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
                        onPressed: _daDangXuat ? null : _huy,
                        child: const Text('Huỷ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
